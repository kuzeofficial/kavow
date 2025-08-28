#!/usr/bin/env bash

set -euo pipefail

readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

source "$PROJECT_ROOT/lib/utils.sh"

test_log_functions() {
    local test_name="test_log_functions"
    
    if ! command -v info >/dev/null 2>&1; then
        echo "FAIL: $test_name - info function not available"
        return 1
    fi
    
    if ! command -v error >/dev/null 2>&1; then
        echo "FAIL: $test_name - error function not available"
        return 1
    fi
    
    if ! command -v warn >/dev/null 2>&1; then
        echo "FAIL: $test_name - warn function not available"
        return 1
    fi
    
    echo "PASS: $test_name"
    return 0
}

test_macos_detection() {
    local test_name="test_macos_detection"
    
    if ! command -v is_macos >/dev/null 2>&1; then
        echo "FAIL: $test_name - is_macos function not available"
        return 1
    fi
    
    if [[ "$(uname)" == "Darwin" ]]; then
        if ! is_macos; then
            echo "FAIL: $test_name - is_macos should return true on macOS"
            return 1
        fi
    fi
    
    echo "PASS: $test_name"
    return 0
}

test_config_parsing() {
    local test_name="test_config_parsing"
    
    local temp_config
    temp_config=$(mktemp)
    
    cat > "$temp_config" << 'EOF'
# Comment line
key1|value1|category1|command1|description1
key2|value2|category2|command2|description2
EOF
    
    local result
    result=$(parse_config_line "key1|value1|category1|command1|description1" 1)
    
    if [[ "$result" != "key1" ]]; then
        echo "FAIL: $test_name - expected 'key1', got '$result'"
        rm -f "$temp_config"
        return 1
    fi
    
    result=$(parse_config_line "key1|value1|category1|command1|description1" 3)
    
    if [[ "$result" != "category1" ]]; then
        echo "FAIL: $test_name - expected 'category1', got '$result'"
        rm -f "$temp_config"
        return 1
    fi
    
    if parse_config_line "# comment" 1 >/dev/null 2>&1; then
        echo "FAIL: $test_name - should not parse comment lines"
        rm -f "$temp_config"
        return 1
    fi
    
    rm -f "$temp_config"
    echo "PASS: $test_name"
    return 0
}

test_format_duration() {
    local test_name="test_format_duration"
    
    local result
    result=$(format_duration 30)
    if [[ "$result" != "30s" ]]; then
        echo "FAIL: $test_name - expected '30s', got '$result'"
        return 1
    fi
    
    result=$(format_duration 90)
    if [[ "$result" != "1m 30s" ]]; then
        echo "FAIL: $test_name - expected '1m 30s', got '$result'"
        return 1
    fi
    
    result=$(format_duration 3661)
    if [[ "$result" != "1h 1m" ]]; then
        echo "FAIL: $test_name - expected '1h 1m', got '$result'"
        return 1
    fi
    
    echo "PASS: $test_name"
    return 0
}

main() {
    echo "Running utils.sh unit tests..."
    
    local tests=(
        "test_log_functions"
        "test_macos_detection"
        "test_config_parsing"
        "test_format_duration"
    )
    
    local passed=0
    local failed=0
    
    for test in "${tests[@]}"; do
        if "$test"; then
            ((passed++))
        else
            ((failed++))
        fi
    done
    
    echo ""
    echo "Utils tests: $passed passed, $failed failed"
    
    if [[ $failed -gt 0 ]]; then
        exit 1
    fi
    
    exit 0
}

main "$@"