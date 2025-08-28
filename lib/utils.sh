#!/usr/bin/env bash

set -euo pipefail

[[ -z "${LOG_LEVEL_ERROR:-}" ]] && readonly LOG_LEVEL_ERROR=1
[[ -z "${LOG_LEVEL_WARN:-}" ]] && readonly LOG_LEVEL_WARN=2
[[ -z "${LOG_LEVEL_INFO:-}" ]] && readonly LOG_LEVEL_INFO=3
[[ -z "${LOG_LEVEL_DEBUG:-}" ]] && readonly LOG_LEVEL_DEBUG=4

LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ $level -le $LOG_LEVEL ]]; then
        case $level in
            $LOG_LEVEL_ERROR) echo "[$timestamp] ERROR: $message" >&2 ;;
            $LOG_LEVEL_WARN)  echo "[$timestamp] WARN:  $message" >&2 ;;
            $LOG_LEVEL_INFO)  echo "[$timestamp] INFO:  $message" ;;
            $LOG_LEVEL_DEBUG) echo "[$timestamp] DEBUG: $message" ;;
        esac
    fi
}

error() {
    log $LOG_LEVEL_ERROR "$1"
}

warn() {
    log $LOG_LEVEL_WARN "$1"
}

info() {
    log $LOG_LEVEL_INFO "$1"
}

debug() {
    log $LOG_LEVEL_DEBUG "$1"
}

die() {
    local message="$1"
    local exit_code="${2:-1}"
    error "$message"
    exit "$exit_code"
}

require_command() {
    local command="$1"
    local install_hint="${2:-}"
    
    if ! command -v "$command" >/dev/null 2>&1; then
        if [[ -n "$install_hint" ]]; then
            die "Required command '$command' not found. $install_hint"
        else
            die "Required command '$command' not found"
        fi
    fi
}

is_macos() {
    [[ "$(uname)" == "Darwin" ]]
}

get_macos_version() {
    if ! is_macos; then
        echo "unknown"
        return 1
    fi
    
    sw_vers -productVersion
}

check_macos_compatibility() {
    if ! is_macos; then
        die "This script is designed for macOS only"
    fi
    
    local version
    version=$(get_macos_version)
    local major_version
    major_version=$(echo "$version" | cut -d. -f1)
    
    if [[ $major_version -lt 10 ]]; then
        die "macOS 10.15 (Catalina) or later is required. You have $version"
    fi
    
    if [[ $major_version -eq 10 ]]; then
        local minor_version
        minor_version=$(echo "$version" | cut -d. -f2)
        if [[ $minor_version -lt 15 ]]; then
            die "macOS 10.15 (Catalina) or later is required. You have $version"
        fi
    fi
    
    info "macOS $version detected - compatible"
}

validate_file_path() {
    local path="$1"
    local description="${2:-file}"
    
    if [[ ! -f "$path" ]]; then
        die "$description not found at: $path"
    fi
    
    if [[ ! -r "$path" ]]; then
        die "$description is not readable: $path"
    fi
}

validate_directory_path() {
    local path="$1"
    local description="${2:-directory}"
    
    if [[ ! -d "$path" ]]; then
        die "$description not found at: $path"
    fi
    
    if [[ ! -r "$path" ]]; then
        die "$description is not readable: $path"
    fi
}

create_directory() {
    local path="$1"
    local permissions="${2:-755}"
    
    if [[ -d "$path" ]]; then
        debug "Directory already exists: $path"
        return 0
    fi
    
    if ! mkdir -p "$path"; then
        die "Failed to create directory: $path"
    fi
    
    if ! chmod "$permissions" "$path"; then
        warn "Failed to set permissions on directory: $path"
    fi
    
    info "Created directory: $path"
}

backup_file() {
    local file_path="$1"
    local backup_suffix="${2:-.backup.$(date +%s)}"
    
    if [[ ! -f "$file_path" ]]; then
        debug "File does not exist, no backup needed: $file_path"
        return 0
    fi
    
    local backup_path="${file_path}${backup_suffix}"
    
    if ! cp "$file_path" "$backup_path"; then
        die "Failed to create backup: $file_path -> $backup_path"
    fi
    
    info "Created backup: $backup_path"
    echo "$backup_path"
}

is_url_reachable() {
    local url="$1"
    local timeout="${2:-10}"
    
    if curl -s --max-time "$timeout" --head "$url" >/dev/null; then
        return 0
    else
        return 1
    fi
}

retry_command() {
    local max_attempts="$1"
    local delay="$2"
    shift 2
    local command=("$@")
    
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        debug "Attempt $attempt/$max_attempts: ${command[*]}"
        
        if "${command[@]}"; then
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            warn "Command failed, retrying in ${delay}s..."
            sleep "$delay"
        fi
        
        ((attempt++))
    done
    
    error "Command failed after $max_attempts attempts: ${command[*]}"
    return 1
}

parse_config_line() {
    local line="$1"
    local field_number="$2"
    local delimiter="${3:-|}"
    
    if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then
        return 1
    fi
    
    echo "$line" | cut -d"$delimiter" -f"$field_number"
}

get_config_value() {
    local config_file="$1"
    local key="$2"
    local delimiter="${3:-|}"
    
    validate_file_path "$config_file" "config file"
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then
            continue
        fi
        
        local line_key
        line_key=$(echo "$line" | cut -d"$delimiter" -f1)
        
        if [[ "$line_key" == "$key" ]]; then
            echo "$line"
            return 0
        fi
    done < "$config_file"
    
    return 1
}

cleanup_temp_files() {
    if [[ -n "${TEMP_FILES:-}" ]]; then
        for temp_file in "${TEMP_FILES[@]}"; do
            if [[ -f "$temp_file" ]]; then
                rm -f "$temp_file"
                debug "Cleaned up temp file: $temp_file"
            fi
        done
        unset TEMP_FILES
    fi
}

add_temp_file() {
    local temp_file="$1"
    TEMP_FILES+=("$temp_file")
}

trap cleanup_temp_files EXIT

setup_signal_handlers() {
    local cleanup_function="${1:-cleanup_temp_files}"
    
    trap "$cleanup_function; exit 130" INT
    trap "$cleanup_function; exit 143" TERM
}

format_duration() {
    local seconds="$1"
    
    if [[ $seconds -lt 60 ]]; then
        echo "${seconds}s"
    elif [[ $seconds -lt 3600 ]]; then
        local minutes=$((seconds / 60))
        local remaining_seconds=$((seconds % 60))
        echo "${minutes}m ${remaining_seconds}s"
    else
        local hours=$((seconds / 3600))
        local minutes=$(((seconds % 3600) / 60))
        echo "${hours}h ${minutes}m"
    fi
}