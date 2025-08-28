#!/usr/bin/env bash

set -euo pipefail



readonly STATE_DIR="$HOME/.kavow"
readonly STATE_FILE="$STATE_DIR/state.json"
readonly LOCK_FILE="$STATE_DIR/.lock"

init_state_system() {
    create_directory "$STATE_DIR" "700"

    if [[ ! -f "$STATE_FILE" ]]; then
        create_initial_state
    fi

    acquire_lock
}

create_initial_state() {
    local initial_state
    initial_state=$(cat <<'EOF'
{
  "version": "1.0.0",
  "current_stage": "init",
  "start_time": "",
  "last_updated": "",
  "homebrew_installed": false,
  "gum_installed": false,
  "selected_apps": [],
  "installed_apps": [],
  "failed_apps": [],
  "selected_languages": [],
  "installed_languages": [],
  "failed_languages": [],
  "git_configured": false,
  "mise_configured": false,
  "github_authenticated": false,
  "ssh_key_generated": false,
  "setup_complete": false,
  "recovery_point": ""
}
EOF
    )

    echo "$initial_state" > "$STATE_FILE"
    update_state "start_time" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    info "Initialized state file: $STATE_FILE"
}

acquire_lock() {
    local max_wait=30
    local wait_time=0

    while [[ -f "$LOCK_FILE" ]]; do
        if [[ $wait_time -ge $max_wait ]]; then
            die "Another setup process is running. Remove $LOCK_FILE if this is incorrect."
        fi

        warn "Waiting for other setup process to finish..."
        sleep 1
        ((wait_time++))
    done

    echo "$$" > "$LOCK_FILE"

    cleanup_lock() {
        rm -f "$LOCK_FILE"
    }

    trap cleanup_lock EXIT
}

read_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        die "State file not found: $STATE_FILE"
    fi

    cat "$STATE_FILE"
}

get_state_value() {
    local key="$1"
    local default="${2:-}"

    local value
    if command -v jq >/dev/null 2>&1; then
        value=$(read_state | jq -r ".$key // \"$default\"")
    else
        value=$(read_state | grep "\"$key\":" | cut -d'"' -f4)
        if [[ -z "$value" ]]; then
            value="$default"
        fi
    fi

    echo "$value"
}

update_state() {
    local key="$1"
    local value="$2"

    local temp_file
    temp_file=$(mktemp)
    add_temp_file "$temp_file"

    local current_time
    current_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    if command -v jq >/dev/null 2>&1; then
        read_state | jq \
            --arg key "$key" \
            --arg value "$value" \
            --arg timestamp "$current_time" \
            '.[$key] = $value | .last_updated = $timestamp' \
            > "$temp_file"
    else
        fallback_update_state "$key" "$value" "$current_time" > "$temp_file"
    fi

    if [[ -s "$temp_file" ]]; then
        mv "$temp_file" "$STATE_FILE"
        debug "Updated state: $key = $value"
    else
        die "Failed to update state file"
    fi
}

fallback_update_state() {
    local key="$1"
    local value="$2"
    local timestamp="$3"

    local state_content
    state_content=$(read_state)

    if echo "$state_content" | grep -q "\"$key\":"; then
        echo "$state_content" | sed "s/\"$key\":[^,}]*/\"$key\": \"$value\"/"
    else
        echo "$state_content" | sed "s/}/,  \"$key\": \"$value\"}/"
    fi | sed "s/\"last_updated\":[^,}]*/\"last_updated\": \"$timestamp\"/"
}

add_to_array() {
    local array_name="$1"
    local value="$2"

    local temp_file
    temp_file=$(mktemp)
    add_temp_file "$temp_file"

    local current_time
    current_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    if command -v jq >/dev/null 2>&1; then
        read_state | jq \
            --arg array "$array_name" \
            --arg value "$value" \
            --arg timestamp "$current_time" \
            '.[$array] += [$value] | .last_updated = $timestamp' \
            > "$temp_file"
    else
        fallback_add_to_array "$array_name" "$value" "$current_time" > "$temp_file"
    fi

    if [[ -s "$temp_file" ]]; then
        mv "$temp_file" "$STATE_FILE"
        debug "Added to $array_name: $value"
    else
        die "Failed to update state file"
    fi
}

fallback_add_to_array() {
    local array_name="$1"
    local value="$2"
    local timestamp="$3"

    local state_content
    state_content=$(read_state)

    if echo "$state_content" | grep -q "\"$array_name\": \[\]"; then
        echo "$state_content" | sed "s/\"$array_name\": \[\]/\"$array_name\": [\"$value\"]/"
    elif echo "$state_content" | grep -q "\"$array_name\": \["; then
        echo "$state_content" | sed "s/\"$array_name\": \[\([^]]*\)\]/\"$array_name\": [\1, \"$value\"]/"
    else
        echo "$state_content" | sed "s/}/,  \"$array_name\": [\"$value\"]}/"
    fi | sed "s/\"last_updated\":[^,}]*/\"last_updated\": \"$timestamp\"/"
}

get_array_values() {
    local array_name="$1"

    if command -v jq >/dev/null 2>&1; then
        read_state | jq -r ".$array_name[]?" 2>/dev/null || true
    else
        read_state | grep "\"$array_name\":" | sed 's/.*\[\(.*\)\].*/\1/' | tr ',' '\n' | sed 's/[" ]//g'
    fi
}

set_stage() {
    local stage="$1"
    local recovery_point="${2:-$stage}"

    update_state "current_stage" "$stage"
    update_state "recovery_point" "$recovery_point"

    info "Stage updated: $stage"
}

get_current_stage() {
    get_state_value "current_stage" "init"
}

get_recovery_point() {
    get_state_value "recovery_point" "init"
}

is_stage_complete() {
    local stage="$1"
    local current_stage
    current_stage=$(get_current_stage)

    case "$current_stage" in
        "init") [[ "$stage" == "init" ]] ;;
        "homebrew_check") [[ "$stage" =~ ^(init|homebrew_check)$ ]] ;;
        "app_selection") [[ "$stage" =~ ^(init|homebrew_check|app_selection)$ ]] ;;
        "language_selection") [[ "$stage" =~ ^(init|homebrew_check|app_selection|language_selection)$ ]] ;;
        "app_installation") [[ "$stage" =~ ^(init|homebrew_check|app_selection|language_selection|app_installation)$ ]] ;;
        "mise_setup") [[ "$stage" =~ ^(init|homebrew_check|app_selection|language_selection|app_installation|mise_setup)$ ]] ;;
        "git_setup") [[ "$stage" =~ ^(init|homebrew_check|app_selection|language_selection|app_installation|mise_setup|git_setup)$ ]] ;;
        "github_setup") [[ "$stage" =~ ^(init|homebrew_check|app_selection|language_selection|app_installation|mise_setup|git_setup|github_setup)$ ]] ;;
        "complete") true ;;
        *) false ;;
    esac
}

cleanup_state() {
    local keep_history="${1:-false}"

    if [[ "$keep_history" == "false" ]]; then
        rm -rf "$STATE_DIR"
        info "Cleaned up state directory"
    else
        local backup_dir="$STATE_DIR/history"
        create_directory "$backup_dir"

        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        cp "$STATE_FILE" "$backup_dir/state_$timestamp.json"

        create_initial_state
        info "Reset state, kept history in $backup_dir"
    fi
}

show_state_summary() {
    echo ""
    info "=== Setup State Summary ==="
    echo "Current Stage: $(get_current_stage)"
    echo "Homebrew Installed: $(get_state_value 'homebrew_installed')"
    echo "Gum Installed: $(get_state_value 'gum_installed')"
    echo "Git Configured: $(get_state_value 'git_configured')"
    echo "Mise Configured: $(get_state_value 'mise_configured')"
    echo "GitHub Authenticated: $(get_state_value 'github_authenticated')"
    echo "SSH Key Generated: $(get_state_value 'ssh_key_generated')"

    local selected_count
    selected_count=$(get_array_values "selected_apps" | wc -l | tr -d ' ')
    echo "Selected Apps: $selected_count"

    local installed_count
    installed_count=$(get_array_values "installed_apps" | wc -l | tr -d ' ')
    echo "Installed Apps: $installed_count"

    local failed_count
    failed_count=$(get_array_values "failed_apps" | wc -l | tr -d ' ')
    if [[ $failed_count -gt 0 ]]; then
        echo "Failed Apps: $failed_count"
    fi

    local selected_languages_count
    selected_languages_count=$(get_array_values "selected_languages" | wc -l | tr -d ' ')
    echo "Selected Languages: $selected_languages_count"

    local installed_languages_count
    installed_languages_count=$(get_array_values "installed_languages" | wc -l | tr -d ' ')
    echo "Installed Languages: $installed_languages_count"

    echo "Setup Complete: $(get_state_value 'setup_complete')"
    echo "Last Updated: $(get_state_value 'last_updated')"
    echo ""
}

validate_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        return 1
    fi

    if command -v jq >/dev/null 2>&1; then
        if ! jq empty "$STATE_FILE" 2>/dev/null; then
            return 1
        fi
    fi

    local required_fields=("version" "current_stage" "homebrew_installed")
    for field in "${required_fields[@]}"; do
        if ! grep -q "\"$field\":" "$STATE_FILE"; then
            return 1
        fi
    done

    return 0
}