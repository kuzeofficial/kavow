#!/usr/bin/env bash

set -euo pipefail

readonly UI_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${UI_LIB_DIR}/ui_native.sh"

[[ -z "${UI_THEME_PRIMARY:-}" ]] && readonly UI_THEME_PRIMARY="#6366f1"
[[ -z "${UI_THEME_SECONDARY:-}" ]] && readonly UI_THEME_SECONDARY="#8b5cf6"
[[ -z "${UI_THEME_SUCCESS:-}" ]] && readonly UI_THEME_SUCCESS="#10b981"
[[ -z "${UI_THEME_WARNING:-}" ]] && readonly UI_THEME_WARNING="#f59e0b"
[[ -z "${UI_THEME_ERROR:-}" ]] && readonly UI_THEME_ERROR="#ef4444"

is_gum_available() {
    command -v gum >/dev/null 2>&1
}

clear_screen() {
    clear
}

show_header() {
    local title="$1"
    local subtitle="${2:-}"

    if is_gum_available; then
        gum style \
            --foreground "$UI_THEME_PRIMARY" \
            --border-foreground "$UI_THEME_PRIMARY" \
            --border double \
            --align center \
            --width 60 \
            --margin "1 0" \
            --padding "1 2" \
            "$title"

        if [[ -n "$subtitle" ]]; then
            gum style \
                --foreground "$UI_THEME_SECONDARY" \
                --align center \
                --width 60 \
                --margin "0 0 1 0" \
                "$subtitle"
        fi
    else
        show_header_native "$title" "$subtitle"
    fi
}

show_progress() {
    local current="$1"
    local total="$2"
    local message="$3"

    if is_gum_available; then
        local percentage=$((current * 100 / total))

        echo ""
        gum style --foreground "$UI_THEME_SECONDARY" "Step $current of $total ($percentage%)"
        gum style --foreground "$UI_THEME_PRIMARY" --bold "$message"
        echo ""
    else
        show_progress_native "$current" "$total" "$message"
    fi
}

confirm_action() {
    local message="$1"
    local default="${2:-Yes}"

    if is_gum_available; then
        if [[ "$default" == "Yes" ]]; then
            gum confirm --default=true "$message"
        else
            gum confirm --default=false "$message"
        fi
    else
        local native_default="y"
        if [[ "$default" != "Yes" ]]; then
            native_default="n"
        fi
        confirm_action_native "$message" "$native_default"
    fi
}

get_user_input() {
    local prompt="$1"
    local placeholder="${2:-}"
    local default="${3:-}"

    if is_gum_available; then
        if [[ -n "$placeholder" ]]; then
            if [[ -n "$default" ]]; then
                gum input --placeholder "$placeholder" --value "$default" --prompt "$prompt "
            else
                gum input --placeholder "$placeholder" --prompt "$prompt "
            fi
        else
            if [[ -n "$default" ]]; then
                gum input --value "$default" --prompt "$prompt "
            else
                gum input --prompt "$prompt "
            fi
        fi
    else
        get_user_input_native "$prompt" "$placeholder" "$default"
    fi
}

get_secure_input() {
    local prompt="$1"

    if is_gum_available; then
        gum input --password --prompt "$prompt "
    else
        get_secure_input_native "$prompt"
    fi
}

single_select() {
    local prompt="$1"
    shift
    local options=("$@")

    if is_gum_available; then
        gum choose --header "$prompt" "${options[@]}"
    else
        show_menu_native "$prompt" "${options[@]}"
    fi
}

multi_select() {
    local prompt="$1"
    shift
    local options=("$@")

    if is_gum_available; then
        gum choose --no-limit --header "$prompt" "${options[@]}"
    else
        show_multi_select_native "$prompt" "${options[@]}"
    fi
}

show_app_category() {
    local category_name="$1"
    local category_description="$2"
    shift 2
    local apps=("$@")

    if is_gum_available; then
        echo ""
        gum style \
            --foreground "$UI_THEME_PRIMARY" \
            --bold \
            --margin "1 0 0 0" \
            "$category_name"

        gum style \
            --foreground "$UI_THEME_SECONDARY" \
            --margin "0 0 1 2" \
            "$category_description"

        if [[ ${#apps[@]} -eq 0 ]]; then
            gum style \
                --foreground "$UI_THEME_WARNING" \
                --margin "0 0 0 4" \
                "No applications available in this category"
            return 0
        fi

        local formatted_apps=()
        for app in "${apps[@]}"; do
            formatted_apps+=("  $app")
        done

        gum choose \
            --no-limit \
            --header "Select applications to install (Space to select, Enter to continue):" \
            "${formatted_apps[@]}"
    else
        echo ""
        echo -e "${UI_THEME_PRIMARY}${BOLD}$category_name${NC}"
        echo -e "${UI_THEME_SECONDARY}$category_description${NC}"
        echo ""

        show_multi_select_native "Select applications to install:" "${apps[@]}"
    fi
}

show_loading() {
    local message="$1"
    local duration="${2:-3}"

    if is_gum_available; then
        gum spin \
            --spinner dot \
            --title "$message" \
            --show-output \
            -- sleep "$duration"
    else
        show_loading_native "$message" "$duration"
    fi
}

show_success() {
    local message="$1"

    if is_gum_available; then
        gum style \
            --foreground "$UI_THEME_SUCCESS" \
            --bold \
            "✓ $message"
    else
        show_success_native "$message"
    fi
}

show_warning() {
    local message="$1"

    if is_gum_available; then
        gum style \
            --foreground "$UI_THEME_WARNING" \
            --bold \
            "⚠ $message"
    else
        show_warning_native "$message"
    fi
}

show_error() {
    local message="$1"

    if is_gum_available; then
        gum style \
            --foreground "$UI_THEME_ERROR" \
            --bold \
            "✗ $message"
    else
        show_error_native "$message"
    fi
}

show_info() {
    local message="$1"

    if is_gum_available; then
        gum style \
            --foreground "$UI_THEME_SECONDARY" \
            "ℹ $message"
    else
        show_info_native "$message"
    fi
}

show_step_complete() {
    local step_name="$1"

    if is_gum_available; then
        echo ""
        show_success "$step_name completed successfully"
        echo ""

        gum style \
            --foreground "$UI_THEME_SECONDARY" \
            --align center \
            "Press Enter to continue..."

        read -r
    else
        show_step_complete_native "$step_name"
    fi
}

show_installation_progress() {
    local app_name="$1"
    local current="$2"
    local total="$3"

    if is_gum_available; then
        echo ""
        gum style \
            --foreground "$UI_THEME_PRIMARY" \
            --bold \
            "Installing $app_name ($current/$total)"

        gum spin \
            --spinner dot \
            --title "Installing via Homebrew..." &

        local spin_pid=$!
        return 0
    else
        show_installation_progress_native "$app_name" "$current" "$total"
    fi
}

stop_spinner() {
    if [[ -n "${spin_pid:-}" ]]; then
        kill "$spin_pid" 2>/dev/null || true
        unset spin_pid
    fi
}

cleanup_ui() {
    stop_spinner
    clear
}

trap cleanup_ui EXIT

show_final_summary() {
    local installed_apps=("$@")

    if is_gum_available; then
        echo ""
        gum style \
            --foreground "$UI_THEME_SUCCESS" \
            --border double \
            --border-foreground "$UI_THEME_SUCCESS" \
            --align center \
            --width 60 \
            --margin "1 0" \
            --padding "1 2" \
            "🎉 Setup Complete!"

        if [[ ${#installed_apps[@]} -gt 0 ]]; then
            echo ""
            gum style \
                --foreground "$UI_THEME_PRIMARY" \
                --bold \
                "Successfully installed applications:"

            for app in "${installed_apps[@]}"; do
                show_success "$app"
            done
        fi

        echo ""
        gum style \
            --foreground "$UI_THEME_SECONDARY" \
            --align center \
            "Your macOS development environment is ready!"
    else
        show_final_summary_native "${installed_apps[@]}"
    fi
}

abort() {
    local message="$1"

    if is_gum_available; then
        echo ""
        show_error "$message"
        echo ""

        if gum confirm --default=false "Proceed anyway on your own accord and without assistance?"; then
            show_warning "Continuing at your own risk..."
            echo ""
            return 0
        else
            echo ""
            show_info "Setup cancelled. You can restart anytime with: ./setup.sh"
            exit 1
        fi
    else
        abort_native "$message"
    fi
}