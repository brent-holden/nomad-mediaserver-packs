[[- if var "enable_health" . ]]
job "[[ var "job_name" . ]]-health" {
  region      = "[[ var "region" . ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  namespace   = "[[ var "namespace" . ]]"
  type        = "batch"

  periodic {
    crons            = ["[[ var "health_cron_schedule" . ]]"]
    time_zone        = "[[ var "timezone" . ]]"
    prohibit_overlap = true
  }

  group "health" {
    count = 1

    restart {
      attempts = 2
      interval = "5m"
      delay    = "30s"
      mode     = "fail"
    }

    reschedule {
      attempts  = 0
      unlimited = false
    }

    task "health" {
      driver = "podman"

      config {
        image = "docker.io/python:3.12-alpine"
        args  = ["python3", "/local/health-check.py"]
      }

      template {
        data = <<EOF
import datetime
import json
import os
import sqlite3
import sys
import urllib.request

NOMAD_ADDR = os.environ.get("NOMAD_ADDR", "http://127.0.0.1:4646")
JOB = os.environ["FF_JOB_NAME"]
TASK = "fileflows"
EXPECTED_LIBS = [l.strip() for l in os.environ.get("FF_EXPECTED_LIBRARIES", "").split(",") if l.strip()]
STALE_HOURS = float(os.environ.get("FF_STALE_HOURS", "48"))
DB = "/fileflows-config/Data/FileFlows.sqlite"
WEBHOOK = os.environ.get("FF_WEBHOOK_URL", "").strip()

failures = []


def api(path):
    with urllib.request.urlopen(NOMAD_ADDR.rstrip("/") + path, timeout=60) as r:
        return r.read()


# --- Check 1: scan the running allocation's logs for the failure mode where
# a DockerMod that failed to install blocks ALL file processing. FileFlows
# rejects every dispatch with "DockerMod 'X' not installed" while the Nomad
# job itself stays green, so this is invisible without reading logs.
# A short rejection burst right after startup is NORMAL (the queue starts
# dispatching before the second DockerMod install pass finishes), so we only
# flag a breakage when rejections are the most recent activity: no successful
# dispatch has happened after the last rejection, and the rejection is close
# to the end of the log. A real breakage produces rejections continuously,
# so these conditions always hold while it lasts.
try:
    allocs = json.loads(api("/v1/job/%s/allocations" % JOB))
    running = [a for a in allocs if a.get("ClientStatus") == "running"]
    if not running:
        failures.append("no running allocation for job '%s'" % JOB)
    else:
        alloc = max(running, key=lambda a: a.get("CreateIndex", 0))
        log = api(
            "/v1/client/fs/logs/%s?task=%s&type=stdout&plain=true&origin=end&offset=2000000"
            % (alloc["ID"], TASK)
        ).decode(errors="replace")
        lines = log.splitlines()
        n = len(lines)
        last_rej = max(
            (i for i, l in enumerate(lines) if "DockerMod '" in l and "not installed" in l),
            default=None,
        )
        last_ok = max(
            (
                i for i, l in enumerate(lines)
                if "Process file result: CanProcess" in l or "Starting runner" in l
            ),
            default=None,
        )
        if last_rej is not None:
            n_mod = sum(1 for l in lines if "DockerMod '" in l and "not installed" in l)
            rej_is_last_word = (last_ok is None or last_rej > last_ok) and last_rej >= n - 50
            if rej_is_last_word:
                failures.append(
                    "%d DockerMod-not-installed rejections and no successful "
                    "dispatch after the last one - file processing is BLOCKED "
                    "(remove or fix the failing mod)" % n_mod
                )
        # DockerMod install failures: flag if one appears in the recent tail
        # (old ones are historical; a failing mod blocks processing and will
        # keep showing up)
        tail = lines[-200:]
        n_fail = sum(1 for l in tail if "Docker Mod Failed" in l)
        if n_fail > 0:
            failures.append("%d DockerMod install failures in recent logs" % n_fail)
        n_mismatch = sum(1 for l in tail if "status: 'ConfigurationMismatch'" in l)
        if n_mismatch > 10:
            failures.append("agent stuck in ConfigurationMismatch state (%d recent status lines)" % n_mismatch)
except Exception as e:
    failures.append("log check error: %s" % e)

# --- Check 2: FileFlows auto-disables libraries after repeated processing
# failures. A disabled library means nothing in it will ever process.
# Note: the volume is mounted read-write because SQLite cannot open a live
# WAL-mode database on a read-only mount (it needs the -shm/-wal files).
# The script only ever issues SELECTs.
try:
    con = None
    for _ in range(3):
        try:
            con = sqlite3.connect(DB, timeout=15)
            con.execute("SELECT 1")
            break
        except sqlite3.Error:
            if con:
                con.close()
            con = None
    if con is None:
        raise sqlite3.Error("could not open database after retries")
    cur = con.cursor()
    for lib in EXPECTED_LIBS:
        cur.execute(
            "SELECT json_extract(Data,'$.Enabled') FROM DbObject "
            "WHERE Type LIKE '%Library' AND Name=?",
            (lib,),
        )
        row = cur.fetchone()
        if row is None:
            failures.append("expected library '%s' missing from FileFlows DB" % lib)
        elif not row[0]:
            failures.append(
                "library '%s' is DISABLED - FileFlows auto-disables libraries "
                "after processing failures" % lib
            )

    # --- Check 3: stale queue. Backlog present, nothing processing, and no
    # database activity for a long time means processing is silently dead.
    cur.execute("SELECT Count(*) FROM LibraryFile WHERE Status=0")
    backlog = cur.fetchone()[0]
    cur.execute("SELECT Count(*) FROM LibraryFile WHERE Status=2")
    active = cur.fetchone()[0]
    cur.execute("SELECT max(DateModified) FROM LibraryFile")
    last_mod = cur.fetchone()[0]
    con.close()

    if backlog > 0 and active == 0 and last_mod:
        lm = datetime.datetime.strptime(str(last_mod)[:19], "%Y-%m-%d %H:%M:%S")
        age_h = (datetime.datetime.utcnow() - lm).total_seconds() / 3600.0
        if age_h > STALE_HOURS:
            failures.append(
                "queue stale: %d unprocessed files, none processing, no "
                "activity for %.0fh (limit %dh)" % (backlog, age_h, STALE_HOURS)
            )
except Exception as e:
    failures.append("database check error: %s" % e)

if failures:
    print("FILEFLOWS HEALTH CHECK FAILED:")
    for f in failures:
        print(" - %s" % f)
    if WEBHOOK:
        try:
            body = json.dumps(
                {"title": "FileFlows health check FAILED", "message": "\n".join(failures)}
            ).encode()
            req = urllib.request.Request(WEBHOOK, data=body, headers={"Content-Type": "application/json"})
            urllib.request.urlopen(req, timeout=10)
        except Exception as e:
            print("webhook notify failed: %s" % e)
    sys.exit(1)

print(
    "FileFlows healthy: agent registered, no DockerMod failures, "
    "libraries enabled, %d backlog / %d active" % (backlog, active)
)
EOF
        destination = "local/health-check.py"
        perms       = "0755"
      }

      env {
        NOMAD_ADDR             = "http://${attr.unique.network.ip-address}:4646"
        FF_JOB_NAME            = "[[ var "job_name" . ]]"
        FF_EXPECTED_LIBRARIES  = "[[ join "," (var "health_expected_libraries" .) ]]"
        FF_STALE_HOURS         = "[[ var "health_stale_hours" . ]]"
        FF_WEBHOOK_URL         = "[[ var "health_webhook_url" . ]]"
      }

      volume_mount {
        volume      = "config"
        destination = "/fileflows-config"
        read_only   = false
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    volume "config" {
      type            = "host"
      source          = "[[ var "config_volume_name" . ]]"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-multi-writer"
    }
  }
}
[[- end ]]
