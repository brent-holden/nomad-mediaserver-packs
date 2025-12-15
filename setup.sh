#!/bin/bash
#
# Setup script for Nomad Media Server Packs
#
# This script creates all necessary volumes and deploys the media server.
# It can be used standalone without the nomad-mediaserver-infra Ansible playbooks.
#
# Prerequisites:
#   - Nomad cluster running with CSI plugin (plugin_id: cifs)
#   - Nomad CLI and nomad-pack installed
#   - NOMAD_ADDR environment variable set
#
# Usage:
#   ./setup.sh                    # Deploy Plex (default)
#   ./setup.sh jellyfin           # Deploy Jellyfin
#   ./setup.sh plex --no-gpu      # Deploy without GPU transcoding
#   ./setup.sh --help             # Show help
#

set -e

# Default configuration
MEDIA_SERVER="${1:-plex}"
REGISTRY_NAME="mediaserver"
REGISTRY_URL="github.com/brent-holden/nomad-mediaserver-packs"

# Volume configuration (customize these)
FILESERVER_IP="${FILESERVER_IP:-10.100.0.1}"
FILESERVER_MEDIA_SHARE="${FILESERVER_MEDIA_SHARE:-media}"
FILESERVER_BACKUP_SHARE="${FILESERVER_BACKUP_SHARE:-backups}"
FILESERVER_USERNAME="${FILESERVER_USERNAME:-plex}"
FILESERVER_PASSWORD="${FILESERVER_PASSWORD:-}"

# User/Group IDs for volume ownership
USER_UID="${USER_UID:-1002}"
GROUP_GID="${GROUP_GID:-1001}"

# CSI Plugin ID
CSI_PLUGIN_ID="${CSI_PLUGIN_ID:-cifs}"

# Pack variables
GPU_TRANSCODING="${GPU_TRANSCODING:-true}"
ENABLE_BACKUP="${ENABLE_BACKUP:-true}"
ENABLE_UPDATE="${ENABLE_UPDATE:-true}"
ENABLE_RESTORE="${ENABLE_RESTORE:-true}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        plex|jellyfin)
            MEDIA_SERVER="$1"
            shift
            ;;
        --no-gpu)
            GPU_TRANSCODING="false"
            shift
            ;;
        --no-backup)
            ENABLE_BACKUP="false"
            shift
            ;;
        --no-update)
            ENABLE_UPDATE="false"
            shift
            ;;
        --no-restore)
            ENABLE_RESTORE="false"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [plex|jellyfin] [options]"
            echo ""
            echo "Options:"
            echo "  --no-gpu       Disable GPU transcoding"
            echo "  --no-backup    Disable backup job"
            echo "  --no-update    Disable update job"
            echo "  --no-restore   Disable restore job"
            echo "  --help, -h     Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  NOMAD_ADDR              Nomad server address (required)"
            echo "  FILESERVER_IP           NAS/fileserver IP (default: 10.100.0.1)"
            echo "  FILESERVER_MEDIA_SHARE  Media share name (default: media)"
            echo "  FILESERVER_BACKUP_SHARE Backup share name (default: backups)"
            echo "  FILESERVER_USERNAME     SMB username (default: plex)"
            echo "  FILESERVER_PASSWORD     SMB password (required)"
            echo "  USER_UID                UID for volume ownership (default: 1002)"
            echo "  GROUP_GID               GID for volume ownership (default: 1001)"
            echo "  CSI_PLUGIN_ID           CSI plugin ID (default: cifs)"
            echo ""
            echo "Example:"
            echo "  NOMAD_ADDR=http://192.168.0.10:4646 FILESERVER_PASSWORD=secret ./setup.sh plex"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check NOMAD_ADDR
    if [[ -z "$NOMAD_ADDR" ]]; then
        log_error "NOMAD_ADDR environment variable is not set"
        echo "Example: export NOMAD_ADDR=http://192.168.0.10:4646"
        exit 1
    fi
    log_success "NOMAD_ADDR: $NOMAD_ADDR"

    # Check nomad CLI
    if ! command -v nomad &> /dev/null; then
        log_error "nomad CLI not found. Install from https://developer.hashicorp.com/nomad/install"
        exit 1
    fi
    log_success "nomad CLI: $(nomad version | head -1)"

    # Check nomad-pack
    if ! command -v nomad-pack &> /dev/null; then
        log_error "nomad-pack not found. Install from https://developer.hashicorp.com/nomad/docs/tools/nomad-pack"
        exit 1
    fi
    log_success "nomad-pack: $(nomad-pack version 2>&1 | head -1)"

    # Check Nomad connectivity
    if ! nomad status &> /dev/null; then
        log_error "Cannot connect to Nomad at $NOMAD_ADDR"
        exit 1
    fi
    log_success "Connected to Nomad cluster"

    # Check CSI plugin
    if ! nomad plugin status "$CSI_PLUGIN_ID" &> /dev/null; then
        log_error "CSI plugin '$CSI_PLUGIN_ID' not found"
        echo "Deploy the CSI plugin first. See nomad-mediaserver-infra for setup."
        exit 1
    fi
    log_success "CSI plugin '$CSI_PLUGIN_ID' is available"

    # Check fileserver password
    if [[ -z "$FILESERVER_PASSWORD" ]]; then
        log_error "FILESERVER_PASSWORD environment variable is not set"
        echo "Example: export FILESERVER_PASSWORD=your-password"
        exit 1
    fi

    # Validate media server choice
    if [[ "$MEDIA_SERVER" != "plex" && "$MEDIA_SERVER" != "jellyfin" ]]; then
        log_error "Invalid media server: $MEDIA_SERVER (must be 'plex' or 'jellyfin')"
        exit 1
    fi
    log_success "Media server: $MEDIA_SERVER"

    echo ""
}

# Create CSI volume
create_csi_volume() {
    local volume_name=$1
    local share_name=$2
    local extra_mount_flags=${3:-""}

    log_info "Creating CSI volume: $volume_name"

    # Check if volume already exists
    if nomad volume status "$volume_name" &> /dev/null; then
        log_warn "Volume '$volume_name' already exists, skipping"
        return 0
    fi

    # Build mount flags
    local mount_flags="uid=$USER_UID,gid=$GROUP_GID,file_mode=0644,dir_mode=0755,vers=3.0"
    if [[ -n "$extra_mount_flags" ]]; then
        mount_flags="$mount_flags,$extra_mount_flags"
    fi

    # Create volume configuration
    local volume_config=$(cat <<EOF
id        = "$volume_name"
name      = "$volume_name"
type      = "csi"
plugin_id = "$CSI_PLUGIN_ID"

capability {
  access_mode     = "multi-node-multi-writer"
  attachment_mode = "file-system"
}

mount_options {
  fs_type     = "cifs"
  mount_flags = ["$mount_flags"]
}

secrets {
  username = "$FILESERVER_USERNAME"
  password = "$FILESERVER_PASSWORD"
}

context {
  source = "//$FILESERVER_IP/$share_name"
}
EOF
)

    # Register volume
    if echo "$volume_config" | nomad volume register -; then
        log_success "Created CSI volume: $volume_name"
    else
        log_error "Failed to create CSI volume: $volume_name"
        return 1
    fi
}

# Create dynamic host volume
create_host_volume() {
    local volume_name=$1

    log_info "Creating host volume: $volume_name"

    # Check if volume already exists
    if nomad volume status -type host "$volume_name" &> /dev/null; then
        log_warn "Host volume '$volume_name' already exists, skipping"
        return 0
    fi

    # Create volume configuration
    local volume_config=$(cat <<EOF
name      = "$volume_name"
type      = "host"
plugin_id = "mkdir"

capability {
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}

parameters {
  mode = "0755"
  uid  = "$USER_UID"
  gid  = "$GROUP_GID"
}
EOF
)

    # Create volume
    if echo "$volume_config" | nomad volume create -; then
        log_success "Created host volume: $volume_name"
    else
        log_error "Failed to create host volume: $volume_name"
        return 1
    fi
}

# Add nomad-pack registry
setup_registry() {
    log_info "Setting up nomad-pack registry..."

    # Check if registry exists
    if nomad-pack registry list 2>/dev/null | grep -q "$REGISTRY_NAME"; then
        log_info "Updating existing registry..."
        nomad-pack registry delete "$REGISTRY_NAME" 2>/dev/null || true
    fi

    # Add registry
    if nomad-pack registry add "$REGISTRY_NAME" "$REGISTRY_URL" > /dev/null; then
        log_success "Registry '$REGISTRY_NAME' added"
    else
        log_error "Failed to add registry"
        return 1
    fi
}

# Deploy media server
deploy_media_server() {
    log_info "Deploying $MEDIA_SERVER..."

    local pack_vars="-var gpu_transcoding=$GPU_TRANSCODING"
    pack_vars="$pack_vars -var enable_backup=$ENABLE_BACKUP"
    pack_vars="$pack_vars -var enable_update=$ENABLE_UPDATE"
    pack_vars="$pack_vars -var enable_restore=$ENABLE_RESTORE"

    if nomad-pack run "$MEDIA_SERVER" --registry="$REGISTRY_NAME" $pack_vars; then
        log_success "$MEDIA_SERVER deployed successfully"
    else
        log_error "Failed to deploy $MEDIA_SERVER"
        return 1
    fi
}

# Wait for job to be running
wait_for_job() {
    local job_name=$1
    local max_attempts=30
    local attempt=0

    log_info "Waiting for $job_name to be running..."

    while [[ $attempt -lt $max_attempts ]]; do
        if nomad job status "$job_name" 2>/dev/null | grep -q "running"; then
            log_success "$job_name is running"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 5
    done

    log_error "$job_name did not start within expected time"
    return 1
}

# Main execution
main() {
    echo "=========================================="
    echo "  Nomad Media Server Setup"
    echo "=========================================="
    echo ""

    check_prerequisites

    echo "=========================================="
    echo "  Creating Volumes"
    echo "=========================================="
    echo ""

    # Create CSI volumes
    create_csi_volume "media-drive" "$FILESERVER_MEDIA_SHARE"

    if [[ "$ENABLE_BACKUP" == "true" ]]; then
        # Backup volume needs cache=none and nobrl for rsync compatibility
        create_csi_volume "backup-drive" "$FILESERVER_BACKUP_SHARE" "cache=none,nobrl"
    fi

    # Create host volume for config
    create_host_volume "${MEDIA_SERVER}-config"

    echo ""
    echo "=========================================="
    echo "  Setting Up Registry"
    echo "=========================================="
    echo ""

    setup_registry

    echo ""
    echo "=========================================="
    echo "  Deploying Media Server"
    echo "=========================================="
    echo ""

    deploy_media_server

    echo ""
    echo "=========================================="
    echo "  Verifying Deployment"
    echo "=========================================="
    echo ""

    wait_for_job "$MEDIA_SERVER"

    echo ""
    echo "=========================================="
    echo "  Setup Complete!"
    echo "=========================================="
    echo ""

    local port
    if [[ "$MEDIA_SERVER" == "plex" ]]; then
        port="32400"
    else
        port="8096"
    fi

    # Extract server IP from NOMAD_ADDR
    local server_ip=$(echo "$NOMAD_ADDR" | sed -E 's|https?://([^:]+):.*|\1|')

    echo -e "Access $MEDIA_SERVER at: ${GREEN}http://$server_ip:$port${NC}"
    echo ""
    echo "Jobs deployed:"
    nomad job status | grep -E "^(${MEDIA_SERVER}|backup-${MEDIA_SERVER}|update-${MEDIA_SERVER}|restore-${MEDIA_SERVER})" || true
    echo ""
    echo "Volumes created:"
    nomad volume status 2>/dev/null | head -20 || true
    echo ""
}

main
