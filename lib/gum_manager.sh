#!/usr/bin/env bash

set -euo pipefail



readonly GUM_AUTO_INSTALLED_FLAG="$HOME/.kavow/.gum_auto_installed"

is_gum_available() {
    command -v gum >/dev/null 2>&1
}

auto_install_gum() {
    if is_gum_available; then
        return 0
    fi

    # Check if Homebrew is available
    if ! command -v brew >/dev/null 2>&1; then
        return 1
    fi

    show_info_native "Auto-installing gum for enhanced UI..."

    if brew install gum >/dev/null 2>&1; then
        # Mark that we auto-installed gum
        touch "$GUM_AUTO_INSTALLED_FLAG"
        show_success_native "Enhanced UI available"
        return 0
    else
        show_warning_native "Failed to auto-install gum, using native UI"
        return 1
    fi
}

was_gum_auto_installed() {
    [[ -f "$GUM_AUTO_INSTALLED_FLAG" ]]
}

auto_uninstall_gum() {
    if ! was_gum_auto_installed; then
        return 0
    fi

    if ! is_gum_available; then
        # Already uninstalled, just clean up flag
        rm -f "$GUM_AUTO_INSTALLED_FLAG"
        return 0
    fi

    echo ""
    if confirm_action_native "Uninstall auto-installed gum? (keeps a cleaner system)" "y"; then
        show_info_native "Uninstalling auto-installed gum..."

        if brew uninstall gum >/dev/null 2>&1; then
            rm -f "$GUM_AUTO_INSTALLED_FLAG"
            show_success_native "gum uninstalled successfully"
        else
            show_warning_native "Failed to uninstall gum, you can remove it manually with: brew uninstall gum"
        fi
    else
        show_info_native "Keeping gum installed for future use"
        rm -f "$GUM_AUTO_INSTALLED_FLAG"  # Remove flag so we don't ask again
    fi
}

ensure_gum_for_enhanced_ui() {
    # Only try to auto-install gum if Homebrew is available
    # This will be called again after Homebrew is installed
    if command -v brew >/dev/null 2>&1; then
        auto_install_gum
    fi
}

enhance_ui_after_homebrew() {
    # Called after Homebrew is installed to enhance UI experience
    if command -v brew >/dev/null 2>&1 && ! is_gum_available; then
        show_info_native "Enhancing UI experience..."
        auto_install_gum
    fi
}