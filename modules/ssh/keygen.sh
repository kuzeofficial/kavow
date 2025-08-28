#!/usr/bin/env bash

set -euo pipefail



readonly SSH_DIR="$HOME/.ssh"
readonly SSH_KEY_PATH="$SSH_DIR/id_ed25519"
readonly SSH_PUB_KEY_PATH="$SSH_KEY_PATH.pub"
readonly SSH_CONFIG_PATH="$SSH_DIR/config"

setup_ssh_key() {
    show_header "SSH Key Setup" "Generating SSH key for GitHub authentication"

    create_directory "$SSH_DIR" "700"

    if [[ -f "$SSH_KEY_PATH" ]]; then
        show_info "SSH key already exists at $SSH_KEY_PATH"

        if verify_ssh_key; then
            show_success "Existing SSH key is valid"

            if confirm_action "Use existing SSH key?"; then
                update_state "ssh_key_generated" "true"
                return 0
            fi
        else
            show_warning "Existing SSH key appears to be invalid"
        fi

        if confirm_action "Generate a new SSH key? (This will backup the existing key)"; then
            backup_existing_ssh_key
        else
            return 1
        fi
    fi

    generate_ssh_key
    configure_ssh_settings
    start_ssh_agent
    add_ssh_key_to_agent

    update_state "ssh_key_generated" "true"
    show_step_complete "SSH Key Setup"
}

verify_ssh_key() {
    if [[ ! -f "$SSH_KEY_PATH" ]] || [[ ! -f "$SSH_PUB_KEY_PATH" ]]; then
        return 1
    fi

    if ! ssh-keygen -y -f "$SSH_KEY_PATH" >/dev/null 2>&1; then
        return 1
    fi

    local key_type
    key_type=$(ssh-keygen -l -f "$SSH_KEY_PATH" 2>/dev/null | awk '{print $4}' | tr -d '()')

    if [[ "$key_type" == "ED25519" ]]; then
        return 0
    fi

    return 1
}

backup_existing_ssh_key() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$SSH_DIR/backup_$timestamp"

    create_directory "$backup_dir" "700"

    if [[ -f "$SSH_KEY_PATH" ]]; then
        cp "$SSH_KEY_PATH" "$backup_dir/"
        info "Backed up private key to $backup_dir/"
    fi

    if [[ -f "$SSH_PUB_KEY_PATH" ]]; then
        cp "$SSH_PUB_KEY_PATH" "$backup_dir/"
        info "Backed up public key to $backup_dir/"
    fi

    show_success "SSH keys backed up to $backup_dir"
}

generate_ssh_key() {
    local git_email
    git_email=$(git config --global user.email 2>/dev/null || echo "")

    if [[ -z "$git_email" ]]; then
        git_email=$(get_user_input "Email for SSH key:" "user@example.com")

        if [[ ! "$git_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            die "Invalid email address provided"
        fi
    fi

    show_info "Generating SSH key with email: $git_email"
    show_info "Key will be saved as: $SSH_KEY_PATH"
    echo ""

    show_warning "You can set a passphrase for additional security, or leave empty for no passphrase"

    if ssh-keygen -t ed25519 -C "$git_email" -f "$SSH_KEY_PATH"; then
        show_success "SSH key generated successfully"
    else
        die "Failed to generate SSH key"
    fi

    chmod 600 "$SSH_KEY_PATH"
    chmod 644 "$SSH_PUB_KEY_PATH"

    show_ssh_key_info
}

show_ssh_key_info() {
    echo ""
    show_info "SSH Key Information:"

    local key_fingerprint
    key_fingerprint=$(ssh-keygen -l -f "$SSH_KEY_PATH" 2>/dev/null | awk '{print $2}')
    echo "  Fingerprint: $key_fingerprint"
    echo "  Type: Ed25519"
    echo "  Location: $SSH_KEY_PATH"
    echo ""
}

configure_ssh_settings() {
    info "Configuring SSH settings..."

    local ssh_config
    ssh_config=$(cat <<'EOF'
Host github.com
    HostName github.com
    User git
    PreferredAuthentications publickey
    IdentityFile ~/.ssh/id_ed25519
    AddKeysToAgent yes
    UseKeychain yes

Host *
    AddKeysToAgent yes
    UseKeychain yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
    )

    if [[ -f "$SSH_CONFIG_PATH" ]]; then
        if grep -q "Host github.com" "$SSH_CONFIG_PATH"; then
            show_info "GitHub SSH configuration already exists"
            return 0
        fi

        backup_file "$SSH_CONFIG_PATH"
    fi

    echo "$ssh_config" > "$SSH_CONFIG_PATH"
    chmod 600 "$SSH_CONFIG_PATH"

    show_success "SSH configuration updated"
}

start_ssh_agent() {
    if pgrep -x ssh-agent >/dev/null; then
        debug "SSH agent is already running"
        return 0
    fi

    info "Starting SSH agent..."

    eval "$(ssh-agent -s)" >/dev/null || {
        warn "Failed to start SSH agent"
        return 1
    }

    show_success "SSH agent started"
}

add_ssh_key_to_agent() {
    info "Adding SSH key to agent..."

    if ssh-add "$SSH_KEY_PATH" 2>/dev/null; then
        show_success "SSH key added to agent"
    else
        warn "Failed to add SSH key to agent"
        show_info "You may need to add it manually later with:"
        echo "  ssh-add $SSH_KEY_PATH"
        return 1
    fi
}

get_public_ssh_key() {
    if [[ ! -f "$SSH_PUB_KEY_PATH" ]]; then
        die "SSH public key not found at $SSH_PUB_KEY_PATH"
    fi

    cat "$SSH_PUB_KEY_PATH"
}

show_public_ssh_key() {
    echo ""
    show_info "Your SSH public key:"
    echo ""
    gum style \
        --border double \
        --border-foreground "$UI_THEME_SECONDARY" \
        --padding "1" \
        "$(get_public_ssh_key)"
    echo ""
}

test_ssh_connection() {
    local host="${1:-github.com}"

    info "Testing SSH connection to $host..."

    if ssh -T git@"$host" 2>&1 | grep -q "successfully authenticated"; then
        show_success "SSH connection to $host successful"
        return 0
    else
        show_warning "SSH connection to $host failed"
        show_info "This is normal if you haven't added the key to your GitHub account yet"
        return 1
    fi
}

show_ssh_status() {
    echo ""
    show_info "=== SSH Configuration Status ==="

    if [[ -f "$SSH_KEY_PATH" ]]; then
        echo "SSH Key: Present"

        local key_info
        key_info=$(ssh-keygen -l -f "$SSH_KEY_PATH" 2>/dev/null)
        echo "Key Type: $(echo "$key_info" | awk '{print $4}' | tr -d '()')"
        echo "Fingerprint: $(echo "$key_info" | awk '{print $2}')"

        if ssh-add -l 2>/dev/null | grep -q "$(ssh-keygen -l -f "$SSH_KEY_PATH" | awk '{print $2}')"; then
            echo "Agent: Key loaded"
        else
            echo "Agent: Key not loaded"
        fi
    else
        echo "SSH Key: Not found"
    fi

    if [[ -f "$SSH_CONFIG_PATH" ]]; then
        echo "SSH Config: Present"
    else
        echo "SSH Config: Not configured"
    fi

    echo ""
}