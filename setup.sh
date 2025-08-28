#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${KAVOW_LIBS_LOADED:-}" ]]; then
    source "${SCRIPT_DIR}/lib/utils.sh"
    source "${SCRIPT_DIR}/lib/state.sh"
    source "${SCRIPT_DIR}/lib/ui_hybrid.sh"
    source "${SCRIPT_DIR}/lib/gum_manager.sh"
    source "${SCRIPT_DIR}/preflight/guard.sh"
    source "${SCRIPT_DIR}/lib/brew.sh"
    source "${SCRIPT_DIR}/lib/installer.sh"
    source "${SCRIPT_DIR}/modules/git/setup.sh"
    source "${SCRIPT_DIR}/modules/mise/setup.sh"
    source "${SCRIPT_DIR}/modules/ssh/keygen.sh"
    source "${SCRIPT_DIR}/modules/github/auth.sh"
    readonly KAVOW_LIBS_LOADED=1
fi

readonly PROGRAM_NAME="kavow"
readonly PROGRAM_VERSION="1.0.0"

show_kavow_banner() {
    echo ""
    echo -e "\033[1;36m"
    cat << 'EOF'
██   ██  █████  ██    ██  ██████  ██     ██ 
██  ██  ██   ██ ██    ██ ██    ██ ██     ██ 
█████   ███████ ██    ██ ██    ██ ██  █  ██ 
██  ██  ██   ██  ██  ██  ██    ██ ██ ███ ██ 
██   ██ ██   ██   ████    ██████   ███ ███  
                                           
EOF
    echo -e "\033[0m"
    echo ""
}

show_welcome() {
    clear_screen

    ensure_gum_for_enhanced_ui

    show_kavow_banner

    show_header "Welcome to kavow" "v$PROGRAM_VERSION - Transform your Mac into a development powerhouse"

    echo ""
    if is_gum_available; then
        gum style \
            --foreground "$UI_THEME_SECONDARY" \
            --align center \
            "This script will guide you through installing and configuring:"
    else
        echo -e "${UI_THEME_SECONDARY}This script will guide you through installing and configuring:${NC}"
        echo ""
    fi

    echo ""
    echo "  🍺 Homebrew package manager"
    echo "  📱 Applications organized by category"
    echo "  🔧 Git version control system"
    echo "  🔑 SSH key generation and GitHub setup"
    echo "  🎯 Complete development environment"
    echo ""

    if is_gum_available; then
        gum style \
            --foreground "$UI_THEME_WARNING" \
            --align center \
            "⚠️  This script will make system modifications"
    else
        echo -e "${UI_THEME_WARNING}⚠️  This script will make system modifications${NC}"
        echo ""
    fi

    echo ""

    if ! confirm_action "Continue with the setup?"; then
        show_info "Setup cancelled by user"
        exit 0
    fi
}

check_prerequisites() {
    run_preflight_checks
}

setup_homebrew_stage() {
    set_stage "homebrew_check"

    show_header "Homebrew Setup" "Installing and configuring the Homebrew package manager"

    if is_homebrew_installed; then
        show_success "Homebrew is already installed"

        if verify_homebrew_installation; then
            setup_homebrew_environment
            update_homebrew
            update_state "homebrew_installed" "true"
        else
            show_warning "Homebrew installation appears corrupted"
            if confirm_action "Reinstall Homebrew?"; then
                install_homebrew_fresh
            else
                die "Valid Homebrew installation required"
            fi
        fi
    else
        show_info "Homebrew is not installed"
        show_info "Homebrew is required to install applications and tools"
        echo ""

        show_info "Installation command:"
        gum style \
            --border single \
            --border-foreground "$UI_THEME_SECONDARY" \
            --padding "1" \
            "$(get_homebrew_install_command)"

        echo ""
        if confirm_action "Install Homebrew now?"; then
            install_homebrew_fresh
        else
            die "Homebrew is required to continue"
        fi
    fi

    install_essential_packages

    enhance_ui_after_homebrew

    show_step_complete "Homebrew Setup"
}

install_homebrew_fresh() {
    show_warning "This will install Homebrew which may take several minutes"
    echo ""

    info "Downloading and installing Homebrew..."

    if eval "$(get_homebrew_install_command)"; then
        show_success "Homebrew installed successfully"

        setup_homebrew_environment
        update_state "homebrew_installed" "true"

        info "Updating Homebrew to latest version..."
        update_homebrew
    else
        die "Failed to install Homebrew"
    fi
}

application_selection_stage() {
    set_stage "app_selection"

    ensure_gum_for_enhanced_ui

    select_applications_by_category
    show_step_complete "Application Selection"
}

language_selection_stage() {
    set_stage "language_selection"

    if ! select_programming_languages; then
        show_error "Language selection cancelled"
        return 1
    fi

    show_step_complete "Programming Language Selection"
}

application_installation_stage() {
    set_stage "app_installation"

    install_selected_applications
    show_step_complete "Application Installation"
}

mise_setup_stage() {
    set_stage "mise_setup"

    setup_mise
}

git_configuration_stage() {
    set_stage "git_setup"

    check_git_installation
    configure_git
}

github_setup_stage() {
    set_stage "github_setup"

    setup_github_cli
    authenticate_github
    setup_ssh_key
    setup_ssh_key_github

    show_step_complete "GitHub Setup"
}

final_stage() {
    set_stage "complete"

    update_state "setup_complete" "true"

    show_final_summary_screen
    cleanup_installations

    auto_uninstall_gum

    show_info "Setup completed successfully!"
    show_info "State files saved in: ~/.kavow/"
}

show_final_summary_screen() {
    clear
    show_kavow_banner
    show_header "🎉 Setup Complete!" "Your development environment is ready"

    echo ""

    local installed_apps=()
    local installed_string
    installed_string=$(get_array_values "installed_apps")

    while IFS= read -r app; do
        if [[ -n "$app" ]]; then
            installed_apps+=("$app")
        fi
    done <<< "$installed_string"

    if [[ ${#installed_apps[@]} -gt 0 ]]; then
        gum style \
            --foreground "$UI_THEME_PRIMARY" \
            --bold \
            "Successfully installed applications:"

        for app_key in "${installed_apps[@]}"; do
            local display_name
            display_name=$(get_app_info "$app_key" 2)
            echo "  ✓ $display_name"
        done
        echo ""
    fi

    local installed_languages=()
    local languages_string
    languages_string=$(get_array_values "installed_languages")

    while IFS= read -r language; do
        if [[ -n "$language" ]]; then
            installed_languages+=("$language")
        fi
    done <<< "$languages_string"

    if [[ ${#installed_languages[@]} -gt 0 ]]; then
        echo ""
        gum style \
            --foreground "$UI_THEME_SECONDARY" \
            --bold \
            "Successfully installed programming languages:"

        for language_key in "${installed_languages[@]}"; do
            local display_name
            display_name=$(get_language_info "$language_key" 2)
            echo "  ✓ $display_name"
        done
        echo ""
    fi

    gum style \
        --foreground "$UI_THEME_SUCCESS" \
        --bold \
        "Configuration completed:"

    local configs=()

    if [[ "$(get_state_value 'homebrew_installed')" == "true" ]]; then
        configs+=("✓ Homebrew package manager")
    fi

    if [[ "$(get_state_value 'git_configured')" == "true" ]]; then
        configs+=("✓ Git version control")
    fi

    if [[ "$(get_state_value 'mise_configured')" == "true" ]]; then
        configs+=("✓ Mise version manager (Python, Node.js)")
    fi

    if [[ "$(get_state_value 'ssh_key_generated')" == "true" ]]; then
        configs+=("✓ SSH key for secure connections")
    fi

    if [[ "$(get_state_value 'github_authenticated')" == "true" ]]; then
        configs+=("✓ GitHub CLI authentication")
    fi

    for config in "${configs[@]}"; do
        echo "  $config"
    done

    echo ""

    gum style \
        --foreground "$UI_THEME_SECONDARY" \
        --align center \
        --border double \
        --border-foreground "$UI_THEME_SUCCESS" \
        --padding "1 2" \
        "Your Mac is now ready for development! 🚀"

    echo ""

    show_info "Next steps:"
    echo "  • Restart your terminal to ensure all changes take effect"
    echo "  • Open your preferred applications from the installed list"
    echo "  • Start coding with your newly configured environment"

    if [[ ${#installed_apps[@]} -gt 0 ]]; then
        echo "  • Applications can be found in /Applications or via Spotlight"
    fi

    echo ""

    gum style \
        --foreground "$UI_THEME_SECONDARY" \
        --align center \
        "Thank you for using kavow!"

    echo ""
}

recovery_mode() {
    show_header "Recovery Mode" "Resuming from previous setup attempt"

    if ! validate_state; then
        show_error "State file is corrupted or invalid"

        if confirm_action "Start fresh setup? (This will lose previous progress)"; then
            cleanup_state
            return 1
        else
            die "Cannot continue with invalid state"
        fi
    fi

    show_state_summary

    local current_stage
    current_stage=$(get_current_stage)

    show_info "Resuming from stage: $current_stage"

    if ! confirm_action "Continue from this point?"; then
        show_info "Recovery cancelled"
        exit 0
    fi

    case "$current_stage" in
        "init"|"homebrew_check")
            return 1
            ;;
        "app_selection")
            application_selection_stage
            language_selection_stage
            application_installation_stage
            mise_setup_stage
            git_configuration_stage
            github_setup_stage
            final_stage
            ;;
        "language_selection")
            language_selection_stage
            application_installation_stage
            mise_setup_stage
            git_configuration_stage
            github_setup_stage
            final_stage
            ;;
        "app_installation")
            application_installation_stage
            mise_setup_stage
            git_configuration_stage
            github_setup_stage
            final_stage
            ;;
        "mise_setup")
            mise_setup_stage
            git_configuration_stage
            github_setup_stage
            final_stage
            ;;
        "git_setup")
            git_configuration_stage
            github_setup_stage
            final_stage
            ;;
        "github_setup")
            github_setup_stage
            final_stage
            ;;
        "complete")
            show_success "Setup was already completed successfully"
            show_state_summary
            ;;
        *)
            show_error "Unknown stage: $current_stage"
            return 1
            ;;
    esac
}

cleanup_on_exit() {
    local exit_code=$?

    if [[ $exit_code -ne 0 ]] && [[ $exit_code -ne 130 ]]; then
        echo ""
        show_error "Setup failed with exit code: $exit_code"

        local recovery_point
        recovery_point=$(get_recovery_point)

        if [[ -n "$recovery_point" ]] && [[ "$recovery_point" != "init" ]]; then
            echo ""
            show_info "You can resume the setup from where it left off:"
            gum style \
                --border single \
                --border-foreground "$UI_THEME_SECONDARY" \
                --padding "1" \
                "./setup.sh --recover"
            echo ""
        fi

        show_info "For support, check the logs or run with DEBUG=1 for more details"
    fi

    cleanup_ui
}

show_usage() {
    cat << EOF
$PROGRAM_NAME v$PROGRAM_VERSION

Usage: $0 [OPTIONS]

OPTIONS:
    --recover       Resume setup from the last successful checkpoint
    --status        Show current setup status and exit
    --clean         Clean up all setup state and start fresh
    --help          Show this help message
    --version       Show version information

EXAMPLES:
    $0              Start fresh setup
    $0 --recover    Resume interrupted setup
    $0 --status     Check current setup status
    $0 --clean      Clean state and start over

ENVIRONMENT VARIABLES:
    LOG_LEVEL       Set logging level (1=ERROR, 2=WARN, 3=INFO, 4=DEBUG)
    DEBUG           Set to 1 for debug output (equivalent to LOG_LEVEL=4)

For more information, visit: https://github.com/your-username/kavow
EOF
}

main() {
    local should_recover=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --recover)
                should_recover=true
                shift
                ;;
            --status)
                init_state_system
                show_state_summary
                show_git_status
                show_ssh_status
                show_github_status
                exit 0
                ;;
            --clean)
                if confirm_action "This will delete all setup state. Continue?"; then
                    cleanup_state
                    show_success "Setup state cleaned"
                else
                    show_info "Clean cancelled"
                fi
                exit 0
                ;;
            --help)
                show_usage
                exit 0
                ;;
            --version)
                echo "$PROGRAM_NAME v$PROGRAM_VERSION"
                exit 0
                ;;
            *)
                show_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    if [[ -n "${DEBUG:-}" ]] && [[ "${DEBUG}" == "1" ]]; then
        export LOG_LEVEL=$LOG_LEVEL_DEBUG
    fi

    trap cleanup_on_exit EXIT
    setup_signal_handlers cleanup_on_exit

    if [[ "$should_recover" == "true" ]]; then
        init_state_system
        if recovery_mode; then
            exit 0
        fi
    else
                    if [[ -d "$HOME/.kavow" ]]; then
            cleanup_state
        fi
        init_state_system
    fi

    show_welcome
    check_prerequisites

        setup_homebrew_stage
    application_selection_stage
    language_selection_stage
    application_installation_stage
    mise_setup_stage
    git_configuration_stage
    github_setup_stage
    final_stage

    exit 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi