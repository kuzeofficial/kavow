#!/usr/bin/env bash

set -euo pipefail



guard_macos() {
    if ! [[ "$(uname)" == "Darwin" ]]; then
        abort "This script is designed for macOS only. Current OS: $(uname)"
    fi
}

guard_not_root() {
    if [[ $EUID -eq 0 ]]; then
        abort "This script should not be run as root. Please run as a regular user."
    fi
}

guard_architecture() {
    local arch
    arch=$(uname -m)

    if [[ "$arch" != "x86_64" ]] && [[ "$arch" != "arm64" ]]; then
        abort "Unsupported architecture: $arch. This script supports x86_64 and arm64 only."
    fi
}

guard_macos_version() {
    local version
    version=$(sw_vers -productVersion)
    local major_version
    major_version=$(echo "$version" | cut -d. -f1)

    if [[ $major_version -lt 10 ]]; then
        abort "macOS 10.15 (Catalina) or later is required. You have $version"
    fi

    if [[ $major_version -eq 10 ]]; then
        local minor_version
        minor_version=$(echo "$version" | cut -d. -f2)
        if [[ $minor_version -lt 15 ]]; then
            abort "macOS 10.15 (Catalina) or later is required. You have $version"
        fi
    fi
}

guard_xcode_tools() {
    if ! xcode-select -p >/dev/null 2>&1; then
        show_warning "Xcode Command Line Tools not found"
        show_info "Installing Xcode Command Line Tools..."

        if xcode-select --install 2>/dev/null; then
            show_info "Please complete the Xcode Command Line Tools installation and re-run this script"
            exit 0
        else
            abort "Failed to start Xcode Command Line Tools installation"
        fi
    fi
}

guard_internet_connection() {
    local test_urls=("https://github.com" "https://raw.githubusercontent.com" "https://formulae.brew.sh")

    for url in "${test_urls[@]}"; do
        if ! curl -s --max-time 10 --head "$url" >/dev/null; then
            abort "Cannot reach $url. Please check your internet connection."
        fi
    done
}

guard_homebrew_conflicts() {
    # Check for potential Homebrew conflicts
    local homebrew_locations=("/usr/local/bin/brew" "/opt/homebrew/bin/brew" "/home/linuxbrew/.linuxbrew/bin/brew")
    local found_installations=()

    for location in "${homebrew_locations[@]}"; do
        if [[ -f "$location" ]]; then
            found_installations+=("$location")
        fi
    done

    if [[ ${#found_installations[@]} -gt 1 ]]; then
        show_warning "Multiple Homebrew installations detected:"
        for installation in "${found_installations[@]}"; do
            echo "  - $installation"
        done

        if ! confirm_action "Continue with multiple Homebrew installations?" "No"; then
            abort "Please resolve Homebrew installation conflicts before continuing"
        fi
    fi
}

guard_disk_space() {
    local required_space_gb=5
    local available_space
    available_space=$(df -h . | tail -1 | awk '{print $4}' | sed 's/G.*//')

    if [[ "$available_space" =~ ^[0-9]+$ ]] && [[ $available_space -lt $required_space_gb ]]; then
        abort "Insufficient disk space. Required: ${required_space_gb}GB, Available: ${available_space}GB"
    fi
}

run_preflight_checks() {
    show_header "Preflight Checks" "Verifying system requirements"

    show_info "Checking macOS compatibility..."
    guard_macos
    guard_macos_version

    show_info "Checking user permissions..."
    guard_not_root

    show_info "Checking system architecture..."
    guard_architecture

    show_info "Checking Xcode Command Line Tools..."
    guard_xcode_tools

    show_info "Checking internet connectivity..."
    guard_internet_connection

    show_info "Checking Homebrew installations..."
    guard_homebrew_conflicts

    show_info "Checking disk space..."
    guard_disk_space

    show_success "All preflight checks passed"
    show_step_complete "Preflight Checks"
}