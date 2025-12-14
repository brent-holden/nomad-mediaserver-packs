# Update Jellyfin Pack

This pack deploys a periodic job that fetches the latest [Jellyfin](https://jellyfin.org/) version and stores it in a Nomad variable.

## How It Works

1. Fetches the latest Jellyfin version from the GitHub releases API
2. Updates the Nomad variable with the new version

The Jellyfin service job can then use this variable to pull the correct version.

## Usage

```bash
# Deploy with defaults (daily at 3am)
nomad-pack run update-jellyfin --registry=media

# Deploy with custom schedule
nomad-pack run update-jellyfin --registry=media -var cron_schedule="0 5 * * *"
```

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `job_name` | Name of the Nomad job | `update-jellyfin` |
| `datacenters` | Eligible datacenters | `["dc1"]` |
| `region` | Nomad region | `global` |
| `namespace` | Nomad namespace | `default` |
| `cron_schedule` | Update schedule (cron format) | `0 3 * * *` |
| `timezone` | Timezone for schedule | `America/New_York` |
| `image` | Container image | `docker.io/debian:bookworm-slim` |
| `nomad_variable_path` | Path for Nomad variable | `nomad/jobs/jellyfin` |
| `cpu` | CPU allocation (MHz) | `200` |
| `memory` | Memory allocation (MB) | `256` |

## Nomad Variable

The job stores/updates the following key at the configured variable path:

- `version` - The latest Jellyfin version string
