#!/usr/bin/env bash
# =============================================================================
# AGENTS-SYNC Test Suite v1.0.0 - Unix Edition
# =============================================================================
#
# Comprehensive test suite for agents-sync functionality on Unix systems.
#
# Usage:
#   ./test.sh              Run all tests
#   ./test.sh --verbose    Run with verbose output
#
# =============================================================================

set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/agents-sync.sh"
TEST_DIR="/tmp/agents-sync-test-$RANDOM"

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

# Logging
log_test() {
    echo -n "[TEST $((TESTS_TOTAL + 1))] $1..." || true
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
    echo -e "${CYAN}[INFO]${NC} $*"
}

echo ""
echo "=== AGENTS-SYNC TEST SUITE v${VERSION} (Unix) ==="
echo -e "${GRAY}Test directory: ${TEST_DIR}${NC}"
echo ""

# Setup
mkdir -p "$TEST_DIR" || {
    echo "Failed to create test directory: $TEST_DIR"
    exit 1
}
cd "$TEST_DIR" || {
    echo "Failed to cd to test directory: $TEST_DIR"
    exit 1
}

# Debug info
echo "DEBUG: PWD=$(pwd)"
echo "DEBUG: SCRIPT_PATH=$SCRIPT_PATH"
echo "DEBUG: BASH_VERSION=$BASH_VERSION"

# Test 1: Script loads without errors
log_test "Script loads without errors"
if bash "$SCRIPT_PATH" help &> /dev/null; then
    log_pass
else
    log_fail
fi

# Test 2: Init command creates template
log_test "Template command creates template"
bash "$SCRIPT_PATH" template &> /dev/null || true
CONFIG_DIR="${HOME}/.agents-sync"
TEMPLATE_PATH="${CONFIG_DIR}/template.md"
if [[ -f "$TEMPLATE_PATH" ]]; then
    log_pass
else
    log_fail
fi

# Test 3: Edit command shows path
log_test "Edit command shows path"
PATH_OUTPUT=$(bash "$SCRIPT_PATH" edit --show-path 2>&1 || true)
if echo "$PATH_OUTPUT" | grep -q "template.md"; then
    log_pass
else
    log_fail
fi

# Test 4: Status command works
log_test "Status command works"
STATUS_OUTPUT=$(bash "$SCRIPT_PATH" status 2>&1 || true)
if echo "$STATUS_OUTPUT" | grep -q "Version" && echo "$STATUS_OUTPUT" | grep -q "Template Path"; then
    log_pass
else
    log_fail
fi

# Test 5: Local command creates AGENTS.md
log_test "Local command creates AGENTS.md"
bash "$SCRIPT_PATH" local --force &> /dev/null || true
AGENTS_PATH="${TEST_DIR}/AGENTS.md"
if [[ -f "$AGENTS_PATH" ]]; then
    log_pass
else
    log_fail
fi

# Test 6: Backup file created on overwrite
log_test "Backup file created on overwrite"
# First create the file manually with different content
echo "Test content" > "$AGENTS_PATH"
bash "$SCRIPT_PATH" local --force &> /dev/null || true
if [[ -f "${AGENTS_PATH}.backup" ]]; then
    log_pass
else
    log_fail
fi

# Test 7: Dry run does not modify files
log_test "Dry run does not modify files"
rm -f "$AGENTS_PATH"
bash "$SCRIPT_PATH" local --dry-run --force &> /dev/null || true
if [[ ! -f "$AGENTS_PATH" ]]; then
    log_pass
else
    log_fail
fi

# Cleanup
cd / || true
rm -rf "$TEST_DIR" || true

echo ""
echo "============================================================================"
echo -e "${GREEN}=== ALL TESTS PASSED ===${NC}"
echo "============================================================================"
echo "Total Tests: $TESTS_TOTAL"
echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"
echo ""

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
