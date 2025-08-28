#!/usr/bin/env bash

set -euo pipefail



is_homebrew_installed() {
    command -v brew >/dev/null 2>&1
}

get_homebrew_install_command() {
    cat <<'EOF'
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
EOF
}

verify_homebrew_installation() {
    if ! is_homebrew_installed; then
        return 1
    fi

    if ! brew --version >/dev/null 2>&1; then
        return 1
    fi

    local brew_prefix
    brew_prefix=$(brew --prefix 2>/dev/null) || return 1

    if [[ ! -d "$brew_prefix" ]]; then
        return 1
    fi

    return 0
}

setup_homebrew_environment() {
    if ! is_homebrew_installed; then
        return 1
    fi

    local brew_prefix
    brew_prefix=$(brew --prefix)

    if [[ ":$PATH:" != *":$brew_prefix/bin:"* ]]; then
        export PATH="$brew_prefix/bin:$PATH"
        debug "Added Homebrew to PATH: $brew_prefix/bin"
    fi

    if [[ -f "$brew_prefix/bin/brew" ]]; then
        eval "$("$brew_prefix/bin/brew" shellenv)"
        debug "Loaded Homebrew shell environment"
    fi

    return 0
}

update_homebrew() {
    show_info "Updating Homebrew..."

    if ! retry_command 3 5 brew update >/dev/null 2>&1; then
        show_warning "Failed to update Homebrew, continuing with existing version"
        return 0
    fi

    show_success "Homebrew updated successfully"
    return 0
}

install_homebrew_package() {
    local install_command="$1"
    local package_name="$2"

    local start_time
    start_time=$(date +%s)

    local output
    local exit_code

    # Capture output and suppress verbose installer messages
    output=$(eval "$install_command" 2>&1)
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        show_success "$package_name installed successfully"
        return 0
    else
        # Check if it's already installed error
        if echo "$output" | grep -q "already an App at"; then
            show_warning "$package_name is already installed (found existing app)"
            return 0
        elif echo "$output" | grep -q "already installed"; then
            show_success "$package_name is already installed"
            return 0
        else
            show_error "Failed to install $package_name"
            debug "Error output: $output"
            return $exit_code
        fi
    fi
}

is_package_installed() {
    local package_name="$1"
    local package_type="${2:-formula}"

    case "$package_type" in
        "cask")
            brew list --cask "$package_name" >/dev/null 2>&1
            ;;
        "formula"|*)
            brew list "$package_name" >/dev/null 2>&1
            ;;
    esac
}

extract_package_info() {
    local brew_command="$1"

    local package_type="formula"
    local package_name

    if [[ "$brew_command" == *"--cask"* ]]; then
        package_type="cask"
        package_name=$(echo "$brew_command" | sed 's/.*--cask *//' | awk '{print $1}')
    else
        package_name=$(echo "$brew_command" | sed 's/brew install *//' | awk '{print $1}')
    fi

    echo "$package_type|$package_name"
}

verify_package_installation() {
    local package_name="$1"
    local package_type="${2:-formula}"

    if is_package_installed "$package_name" "$package_type"; then
        debug "$package_name is installed ($package_type)"
        return 0
    else
        debug "$package_name is not installed ($package_type)"
        return 1
    fi
}

get_installed_packages() {
    local package_type="${1:-all}"

    case "$package_type" in
        "cask")
            brew list --cask 2>/dev/null || true
            ;;
        "formula")
            brew list --formula 2>/dev/null || true
            ;;
        "all"|*)
            {
                brew list --formula 2>/dev/null || true
                brew list --cask 2>/dev/null || true
            }
            ;;
    esac
}

cleanup_homebrew_cache() {
    info "Cleaning up Homebrew cache..."

    if brew cleanup --prune=all 2>/dev/null; then
        info "Homebrew cache cleaned successfully"
    else
        warn "Failed to clean Homebrew cache, continuing"
    fi
}

check_homebrew_health() {
    info "Checking Homebrew installation health..."

    if ! brew doctor >/dev/null 2>&1; then
        warn "Homebrew doctor found issues, but continuing installation"
        debug "Run 'brew doctor' manually to see specific issues"
        return 0
    fi

    info "Homebrew installation is healthy"
    return 0
}

install_essential_packages() {
    # Following Omarchy pattern - install TUI tools as regular packages
    local essentials=("jq")

    show_info "Installing essential packages..."

    for package in "${essentials[@]}"; do
        if is_package_installed "$package"; then
            show_success "$package is already installed"
            continue
        fi

        if install_homebrew_package "brew install $package" "$package"; then
            # Success message is shown by install function
            true
        else
            show_warning "Failed to install $package, some features may not work optimally"
        fi
    done
}

get_package_info() {
    local package_name="$1"
    local package_type="${2:-formula}"

    case "$package_type" in
        "cask")
            brew info --cask "$package_name" 2>/dev/null || echo "Package not found"
            ;;
        "formula"|*)
            brew info "$package_name" 2>/dev/null || echo "Package not found"
            ;;
    esac
}

search_package() {
    local query="$1"

    brew search "$query" 2>/dev/null || true
}

list_outdated_packages() {
    brew outdated 2>/dev/null || true
}

upgrade_packages() {
    local packages=("$@")

    if [[ ${#packages[@]} -eq 0 ]]; then
        info "Upgrading all outdated packages..."
        brew upgrade 2>/dev/null || warn "Some packages failed to upgrade"
    else
        for package in "${packages[@]}"; do
            info "Upgrading $package..."
            brew upgrade "$package" 2>/dev/null || warn "Failed to upgrade $package"
        done
    fi
}