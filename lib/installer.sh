#!/usr/bin/env bash

set -euo pipefail



readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -z "${NC:-}" ]] && readonly NC='\033[0m'
[[ -z "${BOLD:-}" ]] && readonly BOLD='\033[1m'
readonly APPS_CONFIG="$PROJECT_ROOT/data/apps.conf"
readonly CATEGORIES_CONFIG="$PROJECT_ROOT/data/categories.conf"
readonly LANGUAGES_CONFIG="$PROJECT_ROOT/data/languages.conf"

load_app_categories() {
    validate_file_path "$CATEGORIES_CONFIG" "categories configuration"

    # Read categories with their order and sort by order field
    while IFS= read -r line; do
        if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then
            continue
        fi

        local category_key
        category_key=$(parse_config_line "$line" 1)
        local order
        order=$(parse_config_line "$line" 4)

        if [[ -n "$category_key" ]] && [[ -n "$order" ]]; then
            echo "$order|$category_key"
        fi
    done < "$CATEGORIES_CONFIG" | sort -n -t'|' -k1,1 | cut -d'|' -f2
}

get_category_info() {
    local category_key="$1"
    local field="${2:-2}"

    get_config_value "$CATEGORIES_CONFIG" "$category_key" | cut -d'|' -f"$field"
}

get_apps_in_category() {
    local category="$1"

    validate_file_path "$APPS_CONFIG" "applications configuration"

    local apps=()

    while IFS= read -r line; do
        if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then
            continue
        fi

        local app_category
        app_category=$(parse_config_line "$line" 3)

        if [[ "$app_category" == "$category" ]]; then
            local app_key
            app_key=$(parse_config_line "$line" 1)
            apps+=("$app_key")
        fi
    done < "$APPS_CONFIG"

    printf '%s\n' "${apps[@]}"
}

get_app_info() {
    local app_key="$1"
    local field="${2:-2}"

    get_config_value "$APPS_CONFIG" "$app_key" | cut -d'|' -f"$field"
}

format_app_for_selection() {
    local app_key="$1"

    local display_name
    display_name=$(get_app_info "$app_key" 2)

    local description
    description=$(get_app_info "$app_key" 5)

    echo "$app_key|$display_name - $description"
}

select_applications_by_category() {
    local selected_apps=()

    show_header "Application Selection" "Choose applications to install from each category"

    local categories
    categories=$(load_app_categories)

    while IFS= read -r category; do
        if [[ -z "$category" ]]; then
            continue
        fi
        local category_display
        category_display=$(get_category_info "$category" 2)

        local category_description
        category_description=$(get_category_info "$category" 3)

        local apps_in_category
        apps_in_category=$(get_apps_in_category "$category")

        if [[ -z "$apps_in_category" ]]; then
            show_info "No applications available in $category_display"
            continue
        fi

        local formatted_options=()
        while IFS= read -r app; do
            if [[ -n "$app" ]]; then
                formatted_options+=("$(format_app_for_selection "$app")")
            fi
        done <<< "$apps_in_category"

        echo ""
        if is_gum_available; then
            gum style \
                --foreground "$UI_THEME_PRIMARY" \
                --bold \
                --margin "1 0 0 0" \
                "$category_display"

            gum style \
                --foreground "$UI_THEME_SECONDARY" \
                --margin "0 0 1 2" \
                "$category_description"
        else
            echo -e "${UI_THEME_PRIMARY}${BOLD}$category_display${NC}"
            echo -e "${UI_THEME_SECONDARY}$category_description${NC}"
            echo ""
        fi

        local selected_in_category
        selected_in_category=$(
            multi_select "Select applications (Space to select, Enter to continue):" "${formatted_options[@]}" || true
        )

        while IFS= read -r selection; do
            if [[ -n "$selection" ]]; then
                local app_key
                app_key=$(echo "$selection" | cut -d'|' -f1)
                selected_apps+=("$app_key")
            fi
        done <<< "$selected_in_category"
    done <<< "$categories"

    # Safe array length check
    local num_selected=0
    if [[ -n "${selected_apps[*]:-}" ]]; then
        num_selected=${#selected_apps[@]}
    fi

    if [[ $num_selected -eq 0 ]]; then
        show_warning "No applications selected for installation"
        if ! confirm_action "Continue without installing any applications?"; then
            return 1
        fi
    else
        echo ""
        show_info "Selected $num_selected applications:"
        for app in "${selected_apps[@]}"; do
            local display_name
            display_name=$(get_app_info "$app" 2)
            echo "  - $display_name"
        done
        echo ""

        if ! confirm_action "Install these applications?"; then
            return 1
        fi
    fi

    # Only add to state if we have selected apps
    if [[ $num_selected -gt 0 ]]; then
        for app in "${selected_apps[@]}"; do
            add_to_array "selected_apps" "$app"
        done
    fi

    return 0
}

install_selected_applications() {
    local selected_apps=()
    local apps_string
    apps_string=$(get_array_values "selected_apps")

    while IFS= read -r app; do
        if [[ -n "$app" ]]; then
            selected_apps+=("$app")
        fi
    done <<< "$apps_string"

    if [[ ${#selected_apps[@]} -eq 0 ]]; then
        show_info "No applications selected for installation"
        return 0
    fi

    show_header "Installing Applications" "Installing ${#selected_apps[@]} selected applications"

    local current=0
    local total=${#selected_apps[@]}
    local failed_apps=()

    for app_key in "${selected_apps[@]}"; do
        ((current++))

        local display_name
        display_name=$(get_app_info "$app_key" 2)

        local brew_command
        brew_command=$(get_app_info "$app_key" 4)

        echo ""
        echo -e "${UI_THEME_SECONDARY}[$current/$total]${NC} ${UI_THEME_PRIMARY}${BOLD}$display_name${NC}"

        local package_info
        package_info=$(extract_package_info "$brew_command")
        local package_type
        package_type=$(echo "$package_info" | cut -d'|' -f1)
        local package_name
        package_name=$(echo "$package_info" | cut -d'|' -f2)

        if verify_package_installation "$package_name" "$package_type"; then
            echo -e "  ${UI_THEME_SUCCESS}✓${NC} Already installed"
            add_to_array "installed_apps" "$app_key"
            continue
        fi

        # Show a clean installation progress
        echo -n "  Installing... "

        if install_homebrew_package "$brew_command" "$display_name" >/dev/null 2>&1; then
            echo -e "${UI_THEME_SUCCESS}✓ Done${NC}"
            add_to_array "installed_apps" "$app_key"

            if [[ "$app_key" == "claude-code" ]]; then
                handle_claude_code_post_install >/dev/null 2>&1
            fi
        else
            echo -e "${UI_THEME_WARNING}⚠ Issue detected${NC}"
            failed_apps+=("$app_key")
            add_to_array "failed_apps" "$app_key"
        fi

        echo ""
    done

    show_installation_summary "${selected_apps[@]}"

    if [[ ${#failed_apps[@]} -gt 0 ]]; then
        return 1
    fi

    return 0
}

handle_claude_code_post_install() {
    info "Configuring Claude Code..."

    if command -v claude >/dev/null 2>&1; then
        if claude config set -g autoUpdates false 2>/dev/null; then
            info "Disabled Claude Code auto-updates (conflicts with Homebrew)"
        else
            warn "Could not disable Claude Code auto-updates"
        fi
    else
        warn "Claude command not found in PATH after installation"
    fi
}

show_installation_summary() {
    local all_apps=("$@")

    local installed_apps=()
    local installed_string
    installed_string=$(get_array_values "installed_apps")

    while IFS= read -r app; do
        if [[ -n "$app" ]]; then
            installed_apps+=("$app")
        fi
    done <<< "$installed_string"

    local failed_apps=()
    local failed_string
    failed_string=$(get_array_values "failed_apps")

    while IFS= read -r app; do
        if [[ -n "$app" ]]; then
            failed_apps+=("$app")
        fi
    done <<< "$failed_string"

    echo ""
    show_header "Installation Complete"

    local total_selected=${#all_apps[@]}
    local total_installed=${#installed_apps[@]}
    local total_failed=${#failed_apps[@]}

    if [[ ${#installed_apps[@]} -gt 0 ]]; then
        show_success "Installed $total_installed of $total_selected applications"
        echo ""
    fi

    if [[ ${#failed_apps[@]} -gt 0 ]]; then
        show_warning "$total_failed applications had issues:"
        for app_key in "${failed_apps[@]}"; do
            local display_name
            display_name=$(get_app_info "$app_key" 2)
            echo "  • $display_name (may already be installed)"
        done
        echo ""

        show_info "These can be installed manually if needed:"
        echo "  Applications → Check installed apps or use Homebrew directly"
    fi

    if [[ ${#installed_apps[@]} -gt 0 ]]; then
        show_step_complete "Application Installation"
    fi
}

retry_failed_installations() {
    local failed_apps=()
    local failed_string
    failed_string=$(get_array_values "failed_apps")

    while IFS= read -r app; do
        if [[ -n "$app" ]]; then
            failed_apps+=("$app")
        fi
    done <<< "$failed_string"

    if [[ ${#failed_apps[@]} -eq 0 ]]; then
        show_info "No failed installations to retry"
        return 0
    fi

    show_header "Retry Failed Installations" "Attempting to install ${#failed_apps[@]} failed applications"

    if ! confirm_action "Retry installing failed applications?"; then
        return 0
    fi

    local retry_list=("${failed_apps[@]}")

    update_state "selected_apps" "[]"
    update_state "failed_apps" "[]"

    for app in "${retry_list[@]}"; do
        add_to_array "selected_apps" "$app"
    done

    install_selected_applications
}

cleanup_installations() {
    info "Cleaning up installation cache..."
    cleanup_homebrew_cache
}

load_available_languages() {
    validate_file_path "$LANGUAGES_CONFIG" "languages configuration"

    local languages=()

    while IFS= read -r line; do
        if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then
            continue
        fi

        local language_key
        language_key=$(parse_config_line "$line" 1)

        if [[ -n "$language_key" ]]; then
            languages+=("$language_key")
        fi
    done < "$LANGUAGES_CONFIG"

    printf '%s\n' "${languages[@]}"
}

get_language_info() {
    local language_key="$1"
    local field="${2:-2}"

    get_config_value "$LANGUAGES_CONFIG" "$language_key" | cut -d'|' -f"$field"
}

format_language_for_selection() {
    local language_key="$1"

    local display_name
    display_name=$(get_language_info "$language_key" 2)

    local description
    description=$(get_language_info "$language_key" 3)

    echo "$language_key|$display_name - $description"
}

select_programming_languages() {
    show_header "Programming Language Selection" "Choose programming languages to install via mise"

    local available_languages
    available_languages=$(load_available_languages)

    if [[ -z "$available_languages" ]]; then
        show_warning "No programming languages available for selection"
        return 0
    fi

    echo ""
    show_info "Available programming languages:"
    echo ""

    local formatted_options=()
    while IFS= read -r language; do
        if [[ -n "$language" ]]; then
            formatted_options+=("$(format_language_for_selection "$language")")
        fi
    done <<< "$available_languages"

    local selected_languages
    selected_languages=$(
        multi_select "Select programming languages (Space to select, Enter to continue):" "${formatted_options[@]}" || true
    )

    if [[ -z "$selected_languages" ]]; then
        show_warning "No programming languages selected"
        if ! confirm_action "Continue without installing any programming languages?"; then
            return 1
        fi
    else
        echo ""
        show_info "Selected programming languages:"
        while IFS= read -r selection; do
            if [[ -n "$selection" ]]; then
                local language_key
                language_key=$(echo "$selection" | cut -d'|' -f1)
                local display_name
                display_name=$(get_language_info "$language_key" 2)

                echo "  • $display_name"
                add_to_array "selected_languages" "$language_key"
            fi
        done <<< "$selected_languages"
        echo ""

        if ! confirm_action "Install these programming languages?"; then
            return 1
        fi
    fi

    return 0
}

show_language_installation_progress() {
    local language_name="$1"
    local current="$2"
    local total="$3"

    if is_gum_available; then
        echo ""
        gum style \
            --foreground "$UI_THEME_PRIMARY" \
            --bold \
            "Installing $language_name ($current/$total)"

        gum spin \
            --spinner dot \
            --title "Installing via mise..." &
    else
        echo ""
        echo -e "${UI_THEME_PRIMARY}${BOLD}Installing $language_name ($current/$total)${NC}"
        show_loading_native "Installing via mise..." 2
    fi
}

install_selected_languages() {
    local selected_languages=()
    local languages_string
    languages_string=$(get_array_values "selected_languages")

    while IFS= read -r language; do
        if [[ -n "$language" ]]; then
            selected_languages+=("$language")
        fi
    done <<< "$languages_string"

    if [[ ${#selected_languages[@]} -eq 0 ]]; then
        info "No programming languages selected for installation"
        return 0
    fi

    show_header "Installing Programming Languages" "Installing ${#selected_languages[@]} selected languages via mise"

    local current=0
    local total=${#selected_languages[@]}

    for language_key in "${selected_languages[@]}"; do
        ((current++))

        local display_name
        display_name=$(get_language_info "$language_key" 2)

        local mise_version
        mise_version=$(get_language_info "$language_key" 4)

        echo ""
        echo -e "${UI_THEME_SECONDARY}[$current/$total]${NC} ${UI_THEME_PRIMARY}${BOLD}$display_name${NC}"

        if [[ "$mise_version" == "latest" ]]; then
            mise_version=""
        fi

        if mise install "$language_key@$mise_version" 2>/dev/null; then
            mise use "$language_key@$mise_version" 2>/dev/null
            echo -e "  ${UI_THEME_SUCCESS}✓ Done${NC}"
            add_to_array "installed_languages" "$language_key"
        else
            echo -e "  ${UI_THEME_WARNING}⚠ Issue detected${NC}"
            add_to_array "failed_languages" "$language_key"
        fi

        echo ""
    done

    show_language_installation_summary "${selected_languages[@]}"

    if [[ $(get_array_values "failed_languages" | wc -l) -gt 0 ]]; then
        return 1
    fi

    return 0
}

show_language_installation_summary() {
    local all_languages=("$@")

    local installed_languages=()
    local installed_string
    installed_string=$(get_array_values "installed_languages")

    while IFS= read -r language; do
        if [[ -n "$language" ]]; then
            installed_languages+=("$language")
        fi
    done <<< "$installed_string"

    local failed_languages=()
    local failed_string
    failed_string=$(get_array_values "failed_languages")

    while IFS= read -r language; do
        if [[ -n "$language" ]]; then
            failed_languages+=("$language")
        fi
    done <<< "$failed_string"

    echo ""
    show_header "Language Installation Complete"

    local total_selected=${#all_languages[@]}
    local total_installed=${#installed_languages[@]}
    local total_failed=${#failed_languages[@]}

    if [[ ${#installed_languages[@]} -gt 0 ]]; then
        show_success "Installed $total_installed of $total_selected programming languages"
        echo ""
    fi

    if [[ ${#failed_languages[@]} -gt 0 ]]; then
        show_warning "$total_failed programming languages had issues:"
        for language_key in "${failed_languages[@]}"; do
            local display_name
            display_name=$(get_language_info "$language_key" 2)
            echo "  • $display_name (may need manual installation)"
        done
        echo ""

        show_info "These can be installed manually if needed:"
        echo "  Languages → Run 'mise install <language>' manually"
    fi

    if [[ ${#installed_languages[@]} -gt 0 ]]; then
        show_step_complete "Programming Language Installation"
    fi
}