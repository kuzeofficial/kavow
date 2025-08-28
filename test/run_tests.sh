#!/usr/bin/env bash

set -euo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$PROJECT_ROOT/lib/utils.sh"

show_success() {
    echo "✓ $1"
}

show_error() {
    echo "✗ $1" >&2
}

readonly TEST_STATE_DIR="/tmp/kavow-test-$$"
readonly ORIGINAL_STATE_DIR="$HOME/.kavow"

setup_test_environment() {
    info "Setting up test environment..."

    export STATE_DIR="$TEST_STATE_DIR"
    export STATE_FILE="$TEST_STATE_DIR/state.json"

    create_directory "$TEST_STATE_DIR" "700"

    if [[ -d "$ORIGINAL_STATE_DIR" ]]; then
        warn "Backing up existing state directory"
        cp -r "$ORIGINAL_STATE_DIR" "$TEST_STATE_DIR/backup"
    fi
}

cleanup_test_environment() {
    info "Cleaning up test environment..."

    if [[ -d "$TEST_STATE_DIR" ]]; then
        rm -rf "$TEST_STATE_DIR"
    fi
}

run_unit_tests() {
    info "Running unit tests..."

    local test_files
    if [[ -d "$TEST_DIR/unit" ]]; then
        test_files=$(find "$TEST_DIR/unit" -name "*.sh" -type f | sort)
    fi

    if [[ -z "$test_files" ]]; then
        warn "No unit test files found in $TEST_DIR/unit"
        return 0
    fi

    local passed=0
    local failed=0

    while IFS= read -r test_file; do
        if [[ -z "$test_file" ]]; then
            continue
        fi
        local test_name
        test_name=$(basename "$test_file" .sh)

        info "Running test: $test_name"

        if bash "$test_file"; then
            show_success "✓ $test_name"
            ((passed++))
        else
            show_error "✗ $test_name"
            ((failed++))
        fi
    done <<< "$test_files"

    echo ""
    info "Unit tests completed: $passed passed, $failed failed"

    if [[ $failed -gt 0 ]]; then
        return 1
    fi

    return 0
}

run_integration_tests() {
    info "Running integration tests..."

    local test_files
    if [[ -d "$TEST_DIR/integration" ]]; then
        test_files=$(find "$TEST_DIR/integration" -name "*.sh" -type f | sort)
    fi

    if [[ -z "$test_files" ]]; then
        warn "No integration test files found in $TEST_DIR/integration"
        return 0
    fi

    local passed=0
    local failed=0

    while IFS= read -r test_file; do
        if [[ -z "$test_file" ]]; then
            continue
        fi
        local test_name
        test_name=$(basename "$test_file" .sh)

        info "Running integration test: $test_name"

        if bash "$test_file"; then
            show_success "✓ $test_name"
            ((passed++))
        else
            show_error "✗ $test_name"
            ((failed++))
        fi
    done <<< "$test_files"

    echo ""
    info "Integration tests completed: $passed passed, $failed failed"

    if [[ $failed -gt 0 ]]; then
        return 1
    fi

    return 0
}

validate_project_structure() {
    info "Validating project structure..."

    local required_files=(
        "setup.sh"
        "lib/utils.sh"
        "lib/state.sh"
        "lib/ui_hybrid.sh"
        "lib/brew.sh"
        "lib/installer.sh"
        "data/apps.conf"
        "data/categories.conf"
        "modules/git/setup.sh"
        "modules/ssh/keygen.sh"
        "modules/github/auth.sh"
        "README.md"
        "PLAN.md"
        "CLAUDE.md"
    )

    local missing_files=()

    for file in "${required_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
            missing_files+=("$file")
        fi
    done

    if [[ ${#missing_files[@]} -gt 0 ]]; then
        error "Missing required files:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        return 1
    fi

    show_success "All required project files are present"
    return 0
}

check_shell_syntax() {
    info "Checking shell script syntax..."

    local shell_files
    shell_files=$(find "$PROJECT_ROOT" -name "*.sh" -type f)

    local syntax_errors=0

    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            if ! bash -n "$file" 2>/dev/null; then
                error "Syntax error in: $file"
                ((syntax_errors++))
            fi
        fi
    done <<< "$shell_files"

    if [[ $syntax_errors -gt 0 ]]; then
        error "Found $syntax_errors syntax errors"
        return 1
    fi

    show_success "All shell scripts have valid syntax"
    return 0
}

main() {
    local test_type="${1:-all}"

    echo ""
    info "=== kavow Test Suite ==="
    info "Test type: $test_type"
    echo ""

    setup_test_environment

    trap cleanup_test_environment EXIT

    local exit_code=0

    case "$test_type" in
        "structure")
            validate_project_structure || exit_code=1
            ;;
        "syntax")
            check_shell_syntax || exit_code=1
            ;;
        "unit")
            check_shell_syntax || exit_code=1
            validate_project_structure || exit_code=1
            run_unit_tests || exit_code=1
            ;;
        "integration")
            check_shell_syntax || exit_code=1
            validate_project_structure || exit_code=1
            run_integration_tests || exit_code=1
            ;;
        "all"|*)
            check_shell_syntax || exit_code=1
            validate_project_structure || exit_code=1
            run_unit_tests || exit_code=1
            run_integration_tests || exit_code=1
            ;;
    esac

    echo ""
    if [[ $exit_code -eq 0 ]]; then
        show_success "All tests passed! ✅"
    else
        show_error "Some tests failed! ❌"
    fi

    exit $exit_code
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi