#!/usr/bin/env bash

set -euo pipefail

# Required libraries should be sourced before this file

setup_mise() {
    show_header "Mise Setup" "Installing mise version manager and programming languages"

    if ! command -v mise >/dev/null 2>&1; then
        info "Installing mise version manager..."
        curl https://mise.jdx.dev/install.sh | sh
        export PATH="$HOME/.local/bin:$PATH"
    else
        info "Mise is already installed"
        mise --version
    fi

    # Ensure mise is in PATH for current session
    if ! command -v mise >/dev/null 2>&1; then
        if [[ -f "$HOME/.local/bin/mise" ]]; then
            export PATH="$HOME/.local/bin:$PATH"
        elif [[ -f "$HOME/.mise/bin/mise" ]]; then
            export PATH="$HOME/.mise/bin:$PATH"
        fi
    fi

    if command -v mise >/dev/null 2>&1; then
        show_success "Mise installed successfully"

        # Configure mise to use the versions we want
        setup_mise_config

        # Install selected programming languages
        install_selected_languages

        update_state "mise_configured" "true"
        show_step_complete "Mise Setup"
    else
        die "Failed to install mise"
    fi
}

setup_mise_config() {
    info "Configuring mise..."

    # Create mise config directory if it doesn't exist
    mise_dir="$HOME/.config/mise"
    create_directory "$mise_dir"

    # Create a basic mise configuration
    cat > "$mise_dir/config.toml" << 'EOF'
[tools]
python = "3.13"
node = "latest"
EOF

    show_success "Mise configuration created"
}

install_programming_languages() {
    info "Installing programming languages via mise..."

    # Install Python 3.13
    if ! mise list python | grep -q "3.13"; then
        info "Installing Python 3.13..."
        mise install python@3.13
        mise use python@3.13
        show_success "Python 3.13 installed"
    else
        info "Python 3.13 already installed"
    fi

    # Install latest Node.js
    if ! mise list node | grep -q "latest\|lts"; then
        info "Installing Node.js..."
        mise install node@latest
        mise use node@latest
        show_success "Node.js installed"
    else
        info "Node.js already installed"
    fi

    # Verify installations
    verify_mise_installations
}

verify_mise_installations() {
    info "Verifying installations..."

    if command -v python3 >/dev/null 2>&1; then
        python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
        show_success "Python available: $python_version"
    else
        warn "Python not found in PATH after mise installation"
    fi

    if command -v node >/dev/null 2>&1; then
        node_version=$(node --version 2>&1)
        show_success "Node.js available: $node_version"
    else
        warn "Node.js not found in PATH after mise installation"
    fi

    if command -v npm >/dev/null 2>&1; then
        npm_version=$(npm --version 2>&1)
        show_success "npm available: $npm_version"
    fi
}

show_mise_status() {
    echo ""
    show_info "=== Mise Configuration Status ==="

    if command -v mise >/dev/null 2>&1; then
        echo "Mise Version: $(mise --version)"

        echo ""
        echo "Installed Tools:"
        mise list || echo "No tools installed yet"

        echo ""
        echo "Active Tools:"
        mise current || echo "No active tools"
    else
        echo "Mise: Not installed"
    fi

    echo ""
}

# Export functions if script is sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f setup_mise
    export -f setup_mise_config
    export -f install_programming_languages
    export -f verify_mise_installations
    export -f show_mise_status
fi
