#!/bin/bash
# Harbor Image Synchronization Script
# Mirrors external container images to Harbor registry based on configuration

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/harbor-replication-config.yaml"
HARBOR_URL="${HARBOR_URL:-http://192.168.1.210}"
HARBOR_USER="${HARBOR_USER:-admin}"
HARBOR_PASSWORD="${HARBOR_PASSWORD:-Harbor12345}"
LOG_FILE="/tmp/harbor-sync-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check for required tools
    for tool in docker yq curl jq; do
        if ! command -v "$tool" &> /dev/null; then
            error "$tool is required but not installed"
            exit 1
        fi
    done
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running"
        exit 1
    fi
    
    # Check config file
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    log "Prerequisites check passed"
}

# Login to registries
login_registries() {
    log "Logging into Harbor..."
    echo "$HARBOR_PASSWORD" | docker login "$HARBOR_URL" -u "$HARBOR_USER" --password-stdin
    
    # Login to source registries if needed
    if [[ -n "${DOCKER_HUB_TOKEN:-}" ]]; then
        log "Logging into Docker Hub..."
        echo "$DOCKER_HUB_TOKEN" | docker login docker.io -u "${DOCKER_HUB_USER}" --password-stdin
    fi
}

# Create Harbor projects if they don't exist
create_harbor_projects() {
    log "Ensuring Harbor projects exist..."
    
    local projects=$(yq eval '.projects[] | @json' "$CONFIG_FILE")
    
    while IFS= read -r project_json; do
        local name=$(echo "$project_json" | jq -r '.name')
        local public=$(echo "$project_json" | jq -r '.public')
        local description=$(echo "$project_json" | jq -r '.description')
        
        # Check if project exists
        if curl -s -u "$HARBOR_USER:$HARBOR_PASSWORD" \
            "$HARBOR_URL/api/v2.0/projects?name=$name" | jq -e '.[] | select(.name=="'$name'")' > /dev/null; then
            log "Project '$name' already exists"
        else
            log "Creating project '$name'..."
            curl -X POST -u "$HARBOR_USER:$HARBOR_PASSWORD" \
                -H "Content-Type: application/json" \
                -d "{\"project_name\": \"$name\", \"public\": $public, \"metadata\": {\"description\": \"$description\"}}" \
                "$HARBOR_URL/api/v2.0/projects"
        fi
    done <<< "$projects"
}

# Sync a single image
sync_image() {
    local source_image="$1"
    local tag="$2"
    local target_project="${3:-library}"
    
    # Extract image name without registry
    local image_name="${source_image#*/}"
    image_name="${image_name#*/}"  # Handle nested namespaces
    
    local source_full="${source_image}:${tag}"
    local target_full="${HARBOR_URL#http://}/${target_project}/${image_name}:${tag}"
    
    log "Syncing ${source_full} -> ${target_full}"
    
    # Pull from source
    if docker pull "$source_full"; then
        # Tag for Harbor
        docker tag "$source_full" "$target_full"
        
        # Push to Harbor
        if docker push "$target_full"; then
            log "Successfully synced ${source_full}"
            # Clean up local images to save space
            docker rmi "$source_full" "$target_full" 2>/dev/null || true
            return 0
        else
            error "Failed to push ${target_full}"
            return 1
        fi
    else
        error "Failed to pull ${source_full}"
        return 1
    fi
}

# Process images by tier
process_tier() {
    local tier="$1"
    local sync_now="${2:-false}"
    
    log "Processing tier: $tier"
    
    # Get schedule for this tier
    local schedule=$(yq eval ".${tier}.schedule" "$CONFIG_FILE")
    
    # Check if we should sync based on schedule (simplified for demo)
    if [[ "$sync_now" != "true" ]]; then
        log "Skipping $tier (not scheduled). Use --now to force sync."
        return
    fi
    
    # Get images for this tier
    local images=$(yq eval ".${tier}.images[].source" "$CONFIG_FILE")
    
    local success_count=0
    local fail_count=0
    
    while IFS= read -r source; do
        # Get tags for this image
        local tags=$(yq eval ".${tier}.images[] | select(.source == \"$source\") | .tags[]" "$CONFIG_FILE")
        
        while IFS= read -r tag; do
            if sync_image "$source" "$tag"; then
                ((success_count++))
            else
                ((fail_count++))
            fi
        done <<< "$tags"
    done <<< "$images"
    
    log "Tier $tier complete: $success_count succeeded, $fail_count failed"
}

# Generate sync report
generate_report() {
    log "Generating sync report..."
    
    # Get Harbor statistics
    local project_count=$(curl -s -u "$HARBOR_USER:$HARBOR_PASSWORD" \
        "$HARBOR_URL/api/v2.0/projects" | jq '. | length')
    
    local repo_count=$(curl -s -u "$HARBOR_USER:$HARBOR_PASSWORD" \
        "$HARBOR_URL/api/v2.0/repositories?page_size=100" | jq '. | length')
    
    cat > /tmp/harbor-sync-report.txt <<EOF
Harbor Sync Report - $(date)
================================
Harbor URL: $HARBOR_URL
Projects: $project_count
Repositories: $repo_count
Log file: $LOG_FILE

Sync Configuration:
$(yq eval '. | to_entries | .[] | select(.key | startswith("tier")) | .key + ": " + (.value.images | length | tostring) + " images"' "$CONFIG_FILE")

Next Steps:
1. Review the log file for any errors
2. Check Harbor UI for synced images
3. Update deployment configurations to use Harbor registry
EOF
    
    log "Report saved to: /tmp/harbor-sync-report.txt"
    cat /tmp/harbor-sync-report.txt
}

# Main function
main() {
    log "Starting Harbor image synchronization..."
    
    # Parse arguments
    local sync_now=false
    local specific_tier=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --now)
                sync_now=true
                shift
                ;;
            --tier)
                specific_tier="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $0 [--now] [--tier <tier1|tier2|tier3>]"
                echo "  --now   Force sync regardless of schedule"
                echo "  --tier  Sync only specific tier"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Run checks
    check_prerequisites
    login_registries
    create_harbor_projects
    
    # Process tiers
    if [[ -n "$specific_tier" ]]; then
        process_tier "$specific_tier" "$sync_now"
    else
        for tier in tier1 tier2 tier3; do
            process_tier "$tier" "$sync_now"
        done
    fi
    
    # Generate report
    generate_report
    
    log "Harbor synchronization completed!"
}

# Run main function
main "$@"