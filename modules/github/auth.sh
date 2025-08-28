#!/usr/bin/env bash

set -euo pipefail



setup_github_cli() {
    show_header "GitHub CLI Setup" "Installing and configuring GitHub CLI"

    if ! command -v gh >/dev/null 2>&1; then
        info "Installing GitHub CLI via Homebrew..."

        if ! command -v brew >/dev/null 2>&1; then
            die "Homebrew is required to install GitHub CLI"
        fi

        if brew install gh; then
            show_success "GitHub CLI installed successfully"
        else
            die "Failed to install GitHub CLI"
        fi
    else
        show_info "GitHub CLI is already installed"
    fi

    local gh_version
    gh_version=$(gh version | head -n1 | cut -d' ' -f3)
    info "GitHub CLI version $gh_version detected"
}

authenticate_github() {
    show_header "GitHub Authentication" "Authenticating with your GitHub account"

    if is_github_authenticated; then
        local current_user
        current_user=$(gh auth status 2>&1 | grep "Logged in to github.com as" | cut -d' ' -f6 || echo "unknown")

        show_info "Already authenticated with GitHub as: $current_user"

        if confirm_action "Re-authenticate with GitHub?"; then
            gh auth logout 2>/dev/null || true
        else
            update_state "github_authenticated" "true"
            return 0
        fi
    fi

    show_info "Starting GitHub authentication process..."
    show_info "This will open your web browser for OAuth authentication"
    echo ""

    if confirm_action "Continue with GitHub authentication?"; then
        perform_github_auth
    else
        die "GitHub authentication is required to continue"
    fi
}

perform_github_auth() {
    local auth_scopes="repo,read:org,workflow,admin:public_key"

    info "Authenticating with GitHub..."
    show_info "Required scopes: $auth_scopes"
    echo ""

    if gh auth login --git-protocol https --scopes "$auth_scopes" --web; then
        show_success "GitHub authentication successful"

        local username
        username=$(gh api user --jq .login 2>/dev/null || echo "unknown")
        show_info "Authenticated as: $username"

        verify_github_permissions
        update_state "github_authenticated" "true"
    else
        die "GitHub authentication failed"
    fi
}

verify_github_permissions() {
    info "Verifying GitHub permissions..."

    local required_scopes=("repo" "read:org")
    local missing_scopes=()

    for scope in "${required_scopes[@]}"; do
        if ! gh auth status --show-token 2>/dev/null | grep -q "$scope"; then
            missing_scopes+=("$scope")
        fi
    done

    if [[ ${#missing_scopes[@]} -gt 0 ]]; then
        show_warning "Missing required scopes: ${missing_scopes[*]}"
        show_info "You may need to re-authenticate with additional permissions"
    else
        show_success "All required permissions verified"
    fi
}

setup_ssh_key_github() {
    show_header "GitHub SSH Key Setup" "Adding SSH key to your GitHub account"

    if [[ "$(get_state_value 'ssh_key_generated')" != "true" ]]; then
        die "SSH key must be generated before adding to GitHub"
    fi

    if ! command -v gh >/dev/null 2>&1 || ! is_github_authenticated; then
        die "GitHub CLI must be authenticated before adding SSH key"
    fi

    show_public_ssh_key

    local key_title
    key_title="kavow - $(date +%Y-%m-%d)"

    show_info "Adding SSH key to GitHub with title: $key_title"

    if confirm_action "Add this SSH key to your GitHub account?"; then
        add_ssh_key_to_github "$key_title"
    else
        show_warning "SSH key not added to GitHub"
        show_info "You can add it manually later with:"
        echo "  gh ssh-key add $SSH_PUB_KEY_PATH --title '$key_title'"
        return 1
    fi
}

verify_ssh_key_permissions() {
    info "Checking GitHub authentication scopes..."

    # Test if we can list SSH keys (requires admin:public_key scope)
    if ! gh api /user/keys --silent >/dev/null 2>&1; then
        show_warning "Missing required GitHub scope for SSH key management"
        show_info "The 'admin:public_key' scope is required to manage SSH keys"
        echo ""

        if confirm_action "Refresh GitHub authentication with required scopes?"; then
            show_info "Re-authenticating with GitHub..."
            if gh auth refresh -h github.com -s admin:public_key; then
                show_success "GitHub authentication updated with required scopes"
                return 0
            else
                show_error "Failed to refresh GitHub authentication"
                show_info "You can add the SSH key manually later with:"
                echo "  gh auth refresh -h github.com -s admin:public_key"
                echo "  gh ssh-key add $SSH_PUB_KEY_PATH --title 'kavow - $(date +%Y-%m-%d)'"
                return 1
            fi
        else
            show_info "You can add the SSH key manually later with:"
            echo "  gh auth refresh -h github.com -s admin:public_key"
            echo "  gh ssh-key add $SSH_PUB_KEY_PATH --title 'kavow - $(date +%Y-%m-%d)'"
            return 1
        fi
    fi

    return 0
}

add_ssh_key_to_github() {
    local key_title="$1"

    if ! [[ -f "$SSH_PUB_KEY_PATH" ]]; then
        die "SSH public key not found at $SSH_PUB_KEY_PATH"
    fi

    # Verify required scopes before attempting SSH key addition
    verify_ssh_key_permissions

    info "Adding SSH key to GitHub..."

    if gh ssh-key add "$SSH_PUB_KEY_PATH" --title "$key_title"; then
        show_success "SSH key added to GitHub successfully"

        echo ""
        show_info "Testing SSH connection to GitHub..."
        sleep 2

        if test_ssh_connection "github.com"; then
            show_success "SSH connection to GitHub verified"
            configure_git_for_ssh
        else
            show_warning "SSH connection test failed"
            show_info "The key was added but connection verification failed"
            show_info "This might resolve itself in a few minutes"
        fi
    else
        local exit_code=$?
        if [[ $exit_code -eq 1 ]]; then
            show_warning "SSH key may already exist on GitHub"
            if test_ssh_connection "github.com"; then
                show_success "SSH connection works despite add failure"
                configure_git_for_ssh
                return 0
            fi
        fi

        show_error "Failed to add SSH key to GitHub"

        # Provide helpful recovery instructions
        echo ""
        show_info "Troubleshooting steps:"
        echo "1. Make sure you have the 'admin:public_key' scope:"
        echo "   gh auth refresh -h github.com -s admin:public_key"
        echo "2. Or add the key manually:"
        echo "   gh ssh-key add $SSH_PUB_KEY_PATH --title '$key_title'"
        echo "3. Test the connection:"
        echo "   ssh -T git@github.com"

        return 1
    fi
}

configure_git_for_ssh() {
    info "Configuring Git to use SSH for GitHub..."

    if git config --global url."git@github.com:".insteadOf "https://github.com/"; then
        show_success "Git configured to use SSH for GitHub"
    else
        warn "Failed to configure Git SSH settings"
    fi
}

is_github_authenticated() {
    command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1
}

show_github_status() {
    echo ""
    show_info "=== GitHub Configuration Status ==="

    if command -v gh >/dev/null 2>&1; then
        local gh_version
        gh_version=$(gh version | head -n1 | cut -d' ' -f3)
        echo "GitHub CLI: $gh_version"

        if is_github_authenticated; then
            local username
            username=$(gh api user --jq .login 2>/dev/null || echo "unknown")
            echo "Authenticated: Yes (as $username)"

            local ssh_keys
            ssh_keys=$(gh ssh-key list --json title,key 2>/dev/null | jq length 2>/dev/null || echo "0")
            echo "SSH Keys: $ssh_keys registered"
        else
            echo "Authenticated: No"
        fi
    else
        echo "GitHub CLI: Not installed"
    fi

    echo ""
}

test_github_integration() {
    show_header "GitHub Integration Test" "Verifying complete GitHub setup"

    local tests=()

    if command -v gh >/dev/null 2>&1; then
        tests+=("✓ GitHub CLI installed")
    else
        tests+=("✗ GitHub CLI not installed")
        return 1
    fi

    if is_github_authenticated; then
        tests+=("✓ GitHub authenticated")
    else
        tests+=("✗ GitHub not authenticated")
        return 1
    fi

    if test_ssh_connection "github.com"; then
        tests+=("✓ SSH connection works")
    else
        tests+=("✗ SSH connection failed")
    fi

    if git config --global url."git@github.com:".insteadOf >/dev/null 2>&1; then
        tests+=("✓ Git SSH configuration set")
    else
        tests+=("⚠ Git SSH configuration missing")
    fi

    echo ""
    for test in "${tests[@]}"; do
        echo "  $test"
    done
    echo ""

    if [[ "${tests[*]}" =~ ✗ ]]; then
        show_warning "Some GitHub integration tests failed"
        return 1
    else
        show_success "GitHub integration is complete and working"
        return 0
    fi
}

cleanup_github_auth() {
    if confirm_action "Remove GitHub authentication?"; then
        gh auth logout 2>/dev/null || true
        show_info "GitHub authentication removed"
    fi
}