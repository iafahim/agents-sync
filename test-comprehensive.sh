#!/usr/bin/env bash
# =============================================================================
# AGENTS-SYNC Comprehensive Test Suite v1.0.0
# =============================================================================
#
# Comprehensive test suite covering all functionality including:
# - Depth-by-depth traversal
# - Smart directory filtering
# - File pattern matching
# - All command modes
# - Edge cases
#
# Usage:
#   ./test-comprehensive.sh              Run all tests
#   ./test-comprehensive.sh --verbose    Run with verbose output
#   ./test-comprehensive.sh --setup      Setup test environment only
#   ./test-comprehensive.sh --cleanup    Cleanup test environment
#
# =============================================================================

set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/agents-sync.sh"
TEST_BASE_DIR="/tmp/agents-sync-comprehensive-test"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

# Test tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0
VERBOSE=${VERBOSE:-0}

# Logging functions
log_test() {
    echo -n "[TEST $((TESTS_TOTAL + 1))] $1..."
}

log_pass() {
    echo -e " ${GREEN}PASS${NC}"
    ((TESTS_PASSED++)) || true
    ((TESTS_TOTAL++)) || true
}

log_fail() {
    echo -e " ${RED}FAIL${NC}"
    ((TESTS_FAILED++)) || true
    ((TESTS_TOTAL++)) || true
}

log_info() {
    if [[ $VERBOSE -eq 1 ]]; then
        echo -e "${CYAN}[INFO]${NC} $*"
    fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_section() {
    echo ""
    echo "============================================================================"
    echo "$1"
    echo "============================================================================"
    echo ""
}

# Setup test environment
setup_test_env() {
    log_info "Setting up test environment..."

    # Clean up any existing test directory
    rm -rf "$TEST_BASE_DIR" 2>/dev/null || true

    # Create test directory structure
    mkdir -p "$TEST_BASE_DIR"

    # Create a directory structure for testing depth-by-depth traversal
    mkdir -p "$TEST_BASE_DIR/depth-test/level1/level2/level3/level4/level5/level6"
    mkdir -p "$TEST_BASE_DIR/depth-test/level1/level2/level2-alt/level3"
    mkdir -p "$TEST_BASE_DIR/depth-test/branch1/subbranch1"
    mkdir -p "$TEST_BASE_DIR/depth-test/branch2/subbranch2/deep"

    # Create AGENTS.md files at various depths
    echo "# Root AGENTS.md" > "$TEST_BASE_DIR/depth-test/AGENTS.md"
    echo "# Level1 AGENTS.md" > "$TEST_BASE_DIR/depth-test/level1/CLAUDE.md"
    echo "# Level2 AGENTS.md" > "$TEST_BASE_DIR/depth-test/level1/level2/GEMINI.md"
    echo "# Level2-alt AGENTS.md" > "$TEST_BASE_DIR/depth-test/level1/level2/level2-alt/AGENTS.md"
    echo "# Deep AGENTS.md" > "$TEST_BASE_DIR/depth-test/level1/level2/level3/level4/level5/level6/CLAUDE.md"

    # Create a directory structure for testing excluded directories
    mkdir -p "$TEST_BASE_DIR/exclude-test/node_modules/package/lib"
    mkdir -p "$TEST_BASE_DIR/exclude-test/.git/hooks"
    mkdir -p "$TEST_BASE_DIR/exclude-test/vendor/package"
    mkdir -p "$TEST_BASE_DIR/exclude-test/target/classes"
    mkdir -p "$TEST_BASE_DIR/exclude-test/.venv/lib"
    mkdir -p "$TEST_BASE_DIR/exclude-test/.idea/modules"
    mkdir -p "$TEST_BASE_DIR/exclude-test/.cursor/settings"

    # Create AGENTS.md files in excluded directories (should be ignored)
    echo "# Node modules AGENTS.md" > "$TEST_BASE_DIR/exclude-test/node_modules/AGENTS.md"
    echo "# Git AGENTS.md" > "$TEST_BASE_DIR/exclude-test/.git/AGENTS.md"
    echo "# Vendor AGENTS.md" > "$TEST_BASE_DIR/exclude-test/vendor/AGENTS.md"
    echo "# Target AGENTS.md" > "$TEST_BASE_DIR/exclude-test/target/AGENTS.md"

    # Create valid AGENTS.md files
    mkdir -p "$TEST_BASE_DIR/exclude-test/src"
    echo "# Project root" > "$TEST_BASE_DIR/exclude-test/AGENTS.md"
    echo "# src folder" > "$TEST_BASE_DIR/exclude-test/src/AGENTS.md"

    # Create system directories that should be skipped
    mkdir -p "$TEST_BASE_DIR/skip-test/usr/bin"
    mkdir -p "$TEST_BASE_DIR/skip-test/.config/app"
    mkdir -p "$TEST_BASE_DIR/skip-test/.cache/app"
    mkdir -p "$TEST_BASE_DIR/skip-test/.npm/pkg"
    mkdir -p "$TEST_BASE_DIR/skip-test/Windows/System32"

    # Create AGENTS.md in system dirs (should be skipped)
    echo "# usr AGENTS.md" > "$TEST_BASE_DIR/skip-test/usr/AGENTS.md"
    echo "# .config AGENTS.md" > "$TEST_BASE_DIR/skip-test/.config/AGENTS.md"
    echo "# .cache AGENTS.md" > "$TEST_BASE_DIR/skip-test/.cache/AGENTS.md"

    # Create valid project alongside
    mkdir -p "$TEST_BASE_DIR/skip-test/myproject"
    echo "# My project AGENTS.md" > "$TEST_BASE_DIR/skip-test/myproject/AGENTS.md"

    log_info "Test environment created at: $TEST_BASE_DIR"
}

# Cleanup test environment
cleanup_test_env() {
    log_info "Cleaning up test environment..."
    rm -rf "$TEST_BASE_DIR" 2>/dev/null || true
    # Also clean up agents-sync config
    rm -rf "${HOME}/.agents-sync" 2>/dev/null || true
    log_info "Cleanup complete"
}

# Test 1: Script loads without errors
test_script_loads() {
    log_test "Script loads without errors"
    if bash "$SCRIPT_PATH" help &> /dev/null; then
        log_pass
    else
        log_fail
    fi
}

# Test 2: Init command creates template
test_init_creates_template() {
    log_test "Template command creates template"
    bash "$SCRIPT_PATH" template &> /dev/null || true
    CONFIG_DIR="${HOME}/.agents-sync"
    TEMPLATE_PATH="${CONFIG_DIR}/template.md"
    if [[ -f "$TEMPLATE_PATH" ]]; then
        log_pass
    else
        log_fail
    fi
}

# Test 3: Init from source file
test_init_from_source() {
    log_test "Template from source file"
    local source_file="${TEST_BASE_DIR}/source-AGENTS.md"
    echo "# Source AGENTS.md content" > "$source_file"
    bash "$SCRIPT_PATH" template --source "$source_file" &> /dev/null || true
    TEMPLATE_PATH="${HOME}/.agents-sync/template.md"
    if grep -q "Source AGENTS.md content" "$TEMPLATE_PATH" 2>/dev/null; then
        log_pass
    else
        log_fail
    fi
}

# Test 4: Edit command shows path
test_edit_shows_path() {
    log_test "Edit command shows path"
    local PATH_OUTPUT
    PATH_OUTPUT=$(bash "$SCRIPT_PATH" edit --show-path 2>&1 || true)
    if echo "$PATH_OUTPUT" | grep -q "template.md"; then
        log_pass
    else
        log_fail
    fi
}

# Test 5: Status command works
test_status_works() {
    log_test "Status command works"
    local STATUS_OUTPUT
    STATUS_OUTPUT=$(bash "$SCRIPT_PATH" status 2>&1 || true)
    if echo "$STATUS_OUTPUT" | grep -q "Version" && echo "$STATUS_OUTPUT" | grep -q "Template Path"; then
        log_pass
    else
        log_fail
    fi
}

# Test 6: Local command creates AGENTS.md
test_local_creates_agents() {
    log_test "Local command creates AGENTS.md"
    local test_dir="${TEST_BASE_DIR}/local-test"
    mkdir -p "$test_dir"
    cd "$test_dir"
    bash "$SCRIPT_PATH" local --force &> /dev/null || true
    if [[ -f "$test_dir/AGENTS.md" ]]; then
        log_pass
    else
        log_fail
    fi
    cd - > /dev/null
}

# Test 7: Backup file created on overwrite
test_backup_created() {
    log_test "Backup file created on overwrite"
    local test_dir="${TEST_BASE_DIR}/backup-test"
    mkdir -p "$test_dir"
    cd "$test_dir"
    echo "Original content" > AGENTS.md
    bash "$SCRIPT_PATH" local --force &> /dev/null || true
    if [[ -f "${test_dir}/AGENTS.md.backup" ]]; then
        if grep -q "Original content" "${test_dir}/AGENTS.md.backup"; then
            log_pass
        else
            log_fail
        fi
    else
        log_fail
    fi
    cd - > /dev/null
}

# Test 8: Dry run does not modify files
test_dry_run_safe() {
    log_test "Dry run does not modify files"
    local test_dir="${TEST_BASE_DIR}/dryrun-test"
    mkdir -p "$test_dir"
    cd "$test_dir"
    echo "Original content" > AGENTS.md
    bash "$SCRIPT_PATH" local --dry-run --force &> /dev/null || true
    if grep -q "Original content" AGENTS.md; then
        log_pass
    else
        log_fail
    fi
    cd - > /dev/null
}

# Test 9: Depth-by-depth traversal finds files at correct levels
test_depth_traversal() {
    log_test "Depth-by-depth traversal finds files correctly"
    local results
    results=$(bash "$SCRIPT_PATH" scan --path "${TEST_BASE_DIR}/depth-test" --dry-run --force 2>&1 | grep -c "File:" || true)
    # Should find 5 files (we created 5 AGENTS.md files)
    if [[ $results -ge 5 ]]; then
        log_pass
    else
        log_fail
    fi
}

# Test 10: Excluded directories are ignored
test_excluded_dirs() {
    log_test "Excluded directories are ignored"
    local output
    output=$(bash "$SCRIPT_PATH" scan --path "${TEST_BASE_DIR}/exclude-test" --dry-run --force 2>&1)
    # Should NOT contain files from node_modules, .git, vendor, target
    if ! echo "$output" | grep -q "node_modules/AGENTS.md" && \
       ! echo "$output" | grep -q "\.git/AGENTS.md" && \
       ! echo "$output" | grep -q "vendor/AGENTS.md" && \
       ! echo "$output" | grep -q "target/AGENTS.md"; then
        log_pass
    else
        log_fail
    fi
}

# Test 11: System directories are skipped
test_system_dirs_skipped() {
    log_test "System directories are skipped"
    local output
    output=$(bash "$SCRIPT_PATH" scan --path "${TEST_BASE_DIR}/skip-test" --dry-run --force 2>&1)
    # Should NOT contain files from usr, .config, .cache, .npm
    if ! echo "$output" | grep -q "/usr/AGENTS.md" && \
       ! echo "$output" | grep -q "/\.config/AGENTS.md" && \
       ! echo "$output" | grep -q "/\.cache/AGENTS.md"; then
        log_pass
    else
        log_fail
    fi
}

# Test 12: Valid projects are found alongside system dirs
test_valid_projects_found() {
    log_test "Valid projects are found alongside system dirs"
    local output
    output=$(bash "$SCRIPT_PATH" scan --path "${TEST_BASE_DIR}/skip-test" --dry-run --force 2>&1)
    # Should contain the valid myproject file
    if echo "$output" | grep -q "myproject/AGENTS.md"; then
        log_pass
    else
        log_fail
    fi
}

# Test 13: Custom patterns work
test_custom_patterns() {
    log_test "Custom file patterns work"
    local test_dir="${TEST_BASE_DIR}/patterns-test"
    mkdir -p "$test_dir"
    cd "$test_dir"
    echo "# CUSTOM.md" > CUSTOM.md
    echo "# OTHER.md" > OTHER.md
    bash "$SCRIPT_PATH" scan --path "$test_dir" --patterns "CUSTOM.md" --dry-run --force &> /dev/null
    # Should find CUSTOM.md but not OTHER.md
    local output
    output=$(bash "$SCRIPT_PATH" scan --path "$test_dir" --patterns "CUSTOM.md" --dry-run --force 2>&1)
    if echo "$output" | grep -q "CUSTOM.md" && ! echo "$output" | grep -q "OTHER.md"; then
        log_pass
    else
        log_fail
    fi
    cd - > /dev/null
}

# Test 14: Multiple patterns work
test_multiple_patterns() {
    log_test "Multiple patterns work"
    local test_dir="${TEST_BASE_DIR}/multi-pattern-test"
    mkdir -p "$test_dir"
    cd "$test_dir"
    echo "# AGENTS.md" > AGENTS.md
    echo "# CLAUDE.md" > CLAUDE.md
    echo "# GEMINI.md" > GEMINI.md
    bash "$SCRIPT_PATH" scan --path "$test_dir" --patterns "AGENTS.md,CLAUDE.md,GEMINI.md" --dry-run --force &> /dev/null
    local output
    output=$(bash "$SCRIPT_PATH" scan --path "$test_dir" --patterns "AGENTS.md,CLAUDE.md,GEMINI.md" --dry-run --force 2>&1)
    local count
    count=$(echo "$output" | grep -c "File:" || true)
    # Should find 3 files
    if [[ $count -eq 3 ]]; then
        log_pass
    else
        log_fail
    fi
    cd - > /dev/null
}

# Test 15: Max depth is respected
test_max_depth() {
    log_test "Max depth limit is respected"
    local output
    output=$(bash "$SCRIPT_PATH" scan --path "${TEST_BASE_DIR}/depth-test" --dry-run --force 2>&1)
    # Should find files but not go beyond max_depth=6
    # Our deepest file is at level 6, should be found
    if echo "$output" | grep -q "level6/CLAUDE.md"; then
        log_pass
    else
        log_fail
    fi
}

# Test 16: Empty directory handling
test_empty_directory() {
    log_test "Empty directory handling"
    local test_dir="${TEST_BASE_DIR}/empty-test"
    mkdir -p "$test_dir"
    local output
    output=$(bash "$SCRIPT_PATH" scan --path "$test_dir" --dry-run --force 2>&1)
    # Should handle gracefully without errors
    if [[ $? -eq 0 ]]; then
        log_pass
    else
        log_fail
    fi
}

# Test 17: Non-existent path handling
test_nonexistent_path() {
    log_test "Non-existent path handling"
    local output
    output=$(bash "$SCRIPT_PATH" scan --path "/nonexistent/path/that/does/not/exist" --dry-run --force 2>&1 || true)
    # Should handle gracefully with error message
    if echo "$output" | grep -qE "(ERROR|error|not found|Path not found)"; then
        log_pass
    else
        log_fail
    fi
}

# Test 18: Template content sync
test_template_sync() {
    log_test "Template content is synced correctly"
    local test_dir="${TEST_BASE_DIR}/sync-test"
    mkdir -p "$test_dir"
    cd "$test_dir"
    # Set custom template content
    echo "# Custom Template" > "${HOME}/.agents-sync/template.md"
    bash "$SCRIPT_PATH" local --force &> /dev/null
    if grep -q "Custom Template" AGENTS.md; then
        log_pass
    else
        log_fail
    fi
    cd - > /dev/null
}

# Test 19: Help command
test_help_command() {
    log_test "Help command displays usage"
    local output
    output=$(bash "$SCRIPT_PATH" help 2>&1)
    if echo "$output" | grep -q "USAGE" && echo "$output" | grep -q "COMMANDS"; then
        log_pass
    else
        log_fail
    fi
}

# Test 20: Directory with special characters
test_special_characters() {
    log_test "Directory names with special characters"
    local test_dir="${TEST_BASE_DIR}/special-test"
    mkdir -p "$test_dir"
    mkdir -p "$test_dir/project with spaces"
    mkdir -p "$test_dir/project-with-dashes"
    mkdir -p "$test_dir/project_with_underscores"
    echo "# Spaces" > "$test_dir/project with spaces/AGENTS.md"
    echo "# Dashes" > "$test_dir/project-with-dashes/AGENTS.md"
    echo "# Underscores" > "$test_dir/project_with_underscores/AGENTS.md"
    local output
    output=$(bash "$SCRIPT_PATH" scan --path "$test_dir" --dry-run --force 2>&1)
    local count
    count=$(echo "$output" | grep -c "File:" || true)
    if [[ $count -eq 3 ]]; then
        log_pass
    else
        log_fail
    fi
}

# Run all tests
run_all_tests() {
    log_section "AGENTS-SYNC COMPREHENSIVE TEST SUITE v${VERSION}"
    echo -e "${GRAY}Test directory: ${TEST_BASE_DIR}${NC}"
    echo ""

    setup_test_env

    log_section "RUNNING TESTS"

    test_script_loads
    test_init_creates_template
    test_init_from_source
    test_edit_shows_path
    test_status_works
    test_local_creates_agents
    test_backup_created
    test_dry_run_safe
    test_depth_traversal
    test_excluded_dirs
    test_system_dirs_skipped
    test_valid_projects_found
    test_custom_patterns
    test_multiple_patterns
    test_max_depth
    test_empty_directory
    test_nonexistent_path
    test_template_sync
    test_help_command
    test_special_characters

    # Final summary
    log_section "TEST SUMMARY"
    echo "Total Tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}ALL TESTS PASSED!${NC}"
    else
        echo -e "${RED}SOME TESTS FAILED!${NC}"
    fi
    echo ""

    # Ask about cleanup
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "Test environment kept at: $TEST_BASE_DIR"
        echo "Run '$0 --cleanup' to remove it"
    fi

    return $TESTS_FAILED
}

# Parse arguments
case "${1:-}" in
    --verbose)
        VERBOSE=1
        run_all_tests
        ;;
    --setup)
        setup_test_env
        echo "Test environment created at: $TEST_BASE_DIR"
        ;;
    --cleanup)
        cleanup_test_env
        ;;
    --help|"-h")
        cat << EOF
AGENTS-SYNC Comprehensive Test Suite v${VERSION}

Usage:
    $0 [options]

Options:
    --verbose    Run with verbose output
    --setup      Setup test environment only
    --cleanup    Cleanup test environment
    --help       Show this help message

EOF
        ;;
    *)
        run_all_tests
        ;;
esac

exit $TESTS_FAILED
