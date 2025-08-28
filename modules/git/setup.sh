#!/usr/bin/env bash

set -euo pipefail



configure_git() {
    show_header "Git Configuration" "Setting up Git with your identity"

    if is_git_configured; then
        local current_name
        current_name=$(git config --global user.name 2>/dev/null || echo "Not set")
        local current_email
        current_email=$(git config --global user.email 2>/dev/null || echo "Not set")

        show_info "Git is already configured:"
        echo "  Name: $current_name"
        echo "  Email: $current_email"
        echo ""

        if confirm_action "Reconfigure Git settings?"; then
            setup_git_identity
        else
            update_state "git_configured" "true"
            show_success "Using existing Git configuration"
            return 0
        fi
    else
        setup_git_identity
    fi

    configure_git_settings
    update_state "git_configured" "true"
    show_step_complete "Git Configuration"
}

is_git_configured() {
    git config --global user.name >/dev/null 2>&1 && \
    git config --global user.email >/dev/null 2>&1
}

setup_git_identity() {
    echo ""
    show_info "Please provide your Git identity information:"
    echo ""

    local git_name
    while true; do
        git_name=$(get_user_input "Full name:" "John Doe")
        if [[ -n "$git_name" ]]; then
            break
        fi
        show_error "Name cannot be empty"
    done

    local git_email
    while true; do
        git_email=$(get_user_input "Email address:" "user@example.com")
        if [[ "$git_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            break
        fi
        show_error "Please enter a valid email address"
    done

    show_info "Configuring Git with:"
    echo "  Name: $git_name"
    echo "  Email: $git_email"
    echo ""

    if confirm_action "Is this information correct?"; then
        git config --global user.name "$git_name" || die "Failed to set Git name"
        git config --global user.email "$git_email" || die "Failed to set Git email"

        show_success "Git identity configured successfully"
    else
        setup_git_identity
    fi
}

configure_git_settings() {
    info "Configuring additional Git settings..."

    local settings=(
        "init.defaultBranch main"
        "pull.rebase false"
        "core.autocrlf input"
        "core.editor vim"
        "push.default simple"
        "branch.autosetupmerge always"
        "branch.autosetuprebase always"
        "color.ui auto"
        "core.preloadindex true"
        "core.fscache true"
        "gc.auto 256"
    )

    for setting in "${settings[@]}"; do
        local key
        key=$(echo "$setting" | cut -d' ' -f1)
        local value
        value=$(echo "$setting" | cut -d' ' -f2-)

        if git config --global "$key" "$value" 2>/dev/null; then
            debug "Set $key = $value"
        else
            warn "Failed to set $key = $value"
        fi
    done

    setup_git_aliases
    show_success "Git settings configured"
}

setup_git_aliases() {
    local aliases=(
        "co checkout"
        "br branch"
        "ci commit"
        "st status"
        "unstage 'reset HEAD --'"
        "last 'log -1 HEAD'"
        "visual '!gitk'"
        "lg 'log --oneline --decorate --all --graph'"
        "amend 'commit --amend'"
        "pushf 'push --force-with-lease'"
        "undo 'reset --soft HEAD~1'"
    )

    for alias_def in "${aliases[@]}"; do
        local alias_name
        alias_name=$(echo "$alias_def" | cut -d' ' -f1)
        local alias_command
        alias_command=$(echo "$alias_def" | cut -d' ' -f2-)

        alias_command=${alias_command//\'/}

        if git config --global "alias.$alias_name" "$alias_command" 2>/dev/null; then
            debug "Set alias: $alias_name = $alias_command"
        else
            warn "Failed to set alias: $alias_name"
        fi
    done
}

check_git_installation() {
    if ! command -v git >/dev/null 2>&1; then
        error "Git is not installed"

        if confirm_action "Install Git via Homebrew?"; then
            if ! command -v brew >/dev/null 2>&1; then
                die "Homebrew is required to install Git"
            fi

            info "Installing Git..."
            if brew install git; then
                show_success "Git installed successfully"

                export PATH="/opt/homebrew/bin:$PATH"

                if ! command -v git >/dev/null 2>&1; then
                    show_warning "Git installed but not found in PATH"
                    show_info "You may need to restart your terminal or run:"
                    echo "  export PATH=\"/opt/homebrew/bin:\$PATH\""
                    return 1
                fi
            else
                die "Failed to install Git"
            fi
        else
            die "Git is required to continue"
        fi
    fi

    local git_version
    git_version=$(git --version | cut -d' ' -f3)
    info "Git version $git_version detected"

    return 0
}

show_git_status() {
    echo ""
    show_info "=== Git Configuration Status ==="

    if command -v git >/dev/null 2>&1; then
        echo "Git Version: $(git --version | cut -d' ' -f3)"

        if is_git_configured; then
            echo "Name: $(git config --global user.name)"
            echo "Email: $(git config --global user.email)"
            echo "Default Branch: $(git config --global init.defaultBranch || echo 'master')"
        else
            echo "Status: Not configured"
        fi
    else
        echo "Git: Not installed"
    fi

    echo ""
}

verify_git_configuration() {
    if ! command -v git >/dev/null 2>&1; then
        return 1
    fi

    if ! is_git_configured; then
        return 1
    fi

    local name
    name=$(git config --global user.name)
    local email
    email=$(git config --global user.email)

    if [[ -z "$name" ]] || [[ -z "$email" ]]; then
        return 1
    fi

    if [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        return 1
    fi

    return 0
}