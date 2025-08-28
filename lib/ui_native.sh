#!/usr/bin/env bash

set -euo pipefail


readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'


[[ -z "${UI_THEME_PRIMARY:-}" ]] && readonly UI_THEME_PRIMARY=$BLUE
[[ -z "${UI_THEME_SECONDARY:-}" ]] && readonly UI_THEME_SECONDARY=$PURPLE
[[ -z "${UI_THEME_SUCCESS:-}" ]] && readonly UI_THEME_SUCCESS=$GREEN
[[ -z "${UI_THEME_WARNING:-}" ]] && readonly UI_THEME_WARNING=$YELLOW
[[ -z "${UI_THEME_ERROR:-}" ]] && readonly UI_THEME_ERROR=$RED

clear_screen() {
    clear
}

print_centered() {
    local text="$1"
    local width="${2:-60}"
    local padding=$(( (width - ${#text}) / 2 ))

    printf "%*s%s%*s\n" $padding "" "$text" $padding ""
}

show_header_native() {
    local title="$1"
    local subtitle="${2:-}"

    echo ""
    echo -e "${UI_THEME_PRIMARY}${BOLD}"
    print_centered "╔════════════════════════════════════════════════════════╗"
    print_centered "║                                                        ║"
    print_centered "║  $title  ║"
    print_centered "║                                                        ║"
    print_centered "╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    if [[ -n "$subtitle" ]]; then
        echo ""
        echo -e "${UI_THEME_SECONDARY}"
        print_centered "$subtitle"
        echo -e "${NC}"
    fi

    echo ""
}

show_progress_native() {
    local current="$1"
    local total="$2"
    local message="$3"

    local percentage=$((current * 100 / total))

    echo ""
    echo -e "${UI_THEME_SECONDARY}Step $current of $total ($percentage%)${NC}"
    echo -e "${UI_THEME_PRIMARY}${BOLD}$message${NC}"
    echo ""
}

confirm_action_native() {
    local message="$1"
    local default="${2:-y}"

    while true; do
        if [[ "$default" == "y" ]]; then
            read -p "$(echo -e "${WHITE}$message [Y/n]: ${NC}")" -r response
            response=${response:-y}
        else
            read -p "$(echo -e "${WHITE}$message [y/N]: ${NC}")" -r response
            response=${response:-n}
        fi

        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo -e "${UI_THEME_ERROR}Please answer yes or no.${NC}" ;;
        esac
    done
}

get_user_input_native() {
    local prompt="$1"
    local placeholder="${2:-}"
    local default="${3:-}"

    local input_prompt="$prompt"

    if [[ -n "$placeholder" ]]; then
        input_prompt="$input_prompt ($placeholder)"
    fi

    if [[ -n "$default" ]]; then
        input_prompt="$input_prompt [$default]"
    fi

    input_prompt="$input_prompt: "

    read -p "$(echo -e "${WHITE}$input_prompt${NC}")" -r user_input

    if [[ -z "$user_input" && -n "$default" ]]; then
        user_input="$default"
    fi

    echo "$user_input"
}

get_secure_input_native() {
    local prompt="$1"

    read -s -p "$(echo -e "${WHITE}$prompt: ${NC}")" user_input
    echo ""
    echo "$user_input"
}

show_menu_native() {
    local title="$1"
    shift
    local options=("$@")

    echo ""
    echo -e "${UI_THEME_PRIMARY}${BOLD}$title${NC}"
    echo ""

    local i=1
    for option in "${options[@]}"; do
        echo -e "${WHITE}  $i) $option${NC}"
        ((i++))
    done

    echo ""
    while true; do
        read -p "$(echo -e "${WHITE}Select option [1-${#options[@]}]: ${NC}")" -r choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#options[@]} ]]; then
            echo "${options[$((choice-1))]}"
            return 0
        else
            echo -e "${UI_THEME_ERROR}Invalid choice. Please select 1-${#options[@]}.${NC}"
        fi
    done
}

show_multi_select_native() {
    local title="$1"
    shift
    local options=("$@")

    echo ""
    echo -e "${UI_THEME_PRIMARY}${BOLD}$title${NC}"
    echo -e "${UI_THEME_SECONDARY}Use space-separated numbers (e.g., 1 3 5) or 'all' for all options:${NC}"
    echo ""

    local i=1
    for option in "${options[@]}"; do
        echo -e "${WHITE}  $i) $option${NC}"
        ((i++))
    done

    echo ""
    local selected_indices=()

    while true; do
        read -p "$(echo -e "${WHITE}Select options: ${NC}")" -r input

        if [[ "$input" == "all" ]]; then
            for ((i=0; i<${#options[@]}; i++)); do
                selected_indices+=($i)
            done
            break
        elif [[ "$input" =~ ^[0-9[:space:]]+$ ]]; then
            selected_indices=()
            local valid=true

            for choice in $input; do
                if [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#options[@]} ]]; then
                    selected_indices+=($((choice-1)))
                else
                    echo -e "${UI_THEME_ERROR}Invalid choice: $choice${NC}"
                    valid=false
                    break
                fi
            done

            if [[ "$valid" == true ]]; then
                break
            fi
        else
            echo -e "${UI_THEME_ERROR}Invalid input. Use space-separated numbers or 'all'.${NC}"
        fi
    done

    for idx in "${selected_indices[@]}"; do
        echo "${options[$idx]}"
    done
}

show_success_native() {
    local message="$1"
    echo -e "${UI_THEME_SUCCESS}✓ $message${NC}"
}

show_warning_native() {
    local message="$1"
    echo -e "${UI_THEME_WARNING}⚠ $message${NC}"
}

show_error_native() {
    local message="$1"
    echo -e "${UI_THEME_ERROR}✗ $message${NC}"
}

show_info_native() {
    local message="$1"
    echo -e "${UI_THEME_SECONDARY}ℹ $message${NC}"
}

show_step_complete_native() {
    local step_name="$1"

    echo ""
    show_success_native "$step_name completed successfully"
    echo ""

    read -p "$(echo -e "${UI_THEME_SECONDARY}Press Enter to continue...${NC}")" -r
}

show_loading_native() {
    local message="$1"
    local duration="${2:-3}"

    echo -n -e "${UI_THEME_SECONDARY}$message"

    for ((i=0; i<duration; i++)); do
        for char in '|' '/' '-' '\'; do
            echo -n -e "\b$char"
            sleep 0.1
        done
    done

    echo -e "\b ✓${NC}"
}

show_installation_progress_native() {
    local app_name="$1"
    local current="$2"
    local total="$3"

    echo ""
    echo -e "${UI_THEME_PRIMARY}${BOLD}Installing $app_name ($current/$total)${NC}"
    show_loading_native "Installing via Homebrew..." 2
}

show_final_summary_native() {
    local installed_apps=("$@")

    clear_screen

    echo ""
    echo -e "${UI_THEME_SUCCESS}${BOLD}"
    print_centered "╔════════════════════════════════════════════════════════╗"
    print_centered "║                                                        ║"
    print_centered "║              🎉 Setup Complete! 🎉                     ║"
    print_centered "║                                                        ║"
    print_centered "╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    if [[ ${#installed_apps[@]} -gt 0 ]]; then
        echo ""
        echo -e "${UI_THEME_PRIMARY}${BOLD}Successfully installed applications:${NC}"
        for app in "${installed_apps[@]}"; do
            show_success_native "$app"
        done
    fi

    echo ""
    echo -e "${UI_THEME_SECONDARY}Your macOS development environment is ready!${NC}"
}

abort_native() {
    local message="$1"

    echo ""
    show_error_native "$message"
    echo ""

    if confirm_action_native "Proceed anyway on your own accord and without assistance?" "n"; then
        show_warning_native "Continuing at your own risk..."
        echo ""
        return 0
    else
        echo ""
        echo -e "${UI_THEME_SECONDARY}Setup cancelled. You can restart anytime with: ./setup.sh${NC}"
        exit 1
    fi
}