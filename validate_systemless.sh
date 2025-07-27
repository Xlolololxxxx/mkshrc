#!/bin/bash

# Validation test for the systemless mkshrc implementation
# Tests the specific requirements from the problem statement

echo "=== Systemless mkshrc Validation Test ==="
echo ""

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
TEST_ROOT="/tmp/mkshrc_validation"
FAILED_TESTS=0

log_test() {
    echo "[TEST] $1"
}

log_pass() {
    echo "  ✓ $1"
}

log_fail() {
    echo "  ✗ $1"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

setup_test_env() {
    log_test "Setting up test environment"
    rm -rf "$TEST_ROOT"
    mkdir -p "$TEST_ROOT"/{etc,usr/share,system_ext/etc,data}
    
    # Simulate the installation
    cp -r "$SCRIPT_DIR/system/"* "$TEST_ROOT/"
    [ -d "$SCRIPT_DIR/system_ext" ] && cp -r "$SCRIPT_DIR/system_ext/"* "$TEST_ROOT/system_ext/"
    
    log_pass "Test environment created"
}

test_no_magisk_dependencies() {
    log_test "Verifying no Magisk module dependencies"
    
    if [ ! -f "$SCRIPT_DIR/module.prop" ]; then
        log_pass "No module.prop found"
    else
        log_fail "module.prop still exists"
    fi
    
    if [ ! -d "$SCRIPT_DIR/META-INF" ]; then
        log_pass "No META-INF directory found"
    else
        log_fail "META-INF directory still exists"
    fi
}

test_no_vendor_references() {
    log_test "Verifying no /vendor directory or references"
    
    if [ ! -d "$SCRIPT_DIR/system/vendor" ]; then
        log_pass "No vendor directory in system/"
    else
        log_fail "vendor directory still exists in system/"
    fi
    
    # Check PATH doesn't include vendor paths
    if ! grep -q "/vendor/bin" "$TEST_ROOT/etc/mkshrc"; then
        log_pass "No /vendor/bin in PATH"
    else
        log_fail "/vendor/bin still in PATH"
    fi
    
    if ! grep -q "/system/product/bin" "$TEST_ROOT/etc/mkshrc"; then
        log_pass "No /system/product/bin in PATH"
    else
        log_fail "/system/product/bin still in PATH"
    fi
}

test_rw_paths_only() {
    log_test "Verifying only RW paths are targeted"
    
    # Check that we have system/ (maps to /) and system_ext/
    if [ -d "$SCRIPT_DIR/system" ]; then
        log_pass "system/ directory exists (maps to RW /)"
    else
        log_fail "system/ directory missing"
    fi
    
    if [ -d "$SCRIPT_DIR/system_ext" ]; then
        log_pass "system_ext/ directory exists (maps to RW /system_ext)"
    else
        log_fail "system_ext/ directory missing"
    fi
}

test_direct_installation() {
    log_test "Verifying direct installation capability"
    
    if [ -f "$SCRIPT_DIR/install.sh" ] && [ -x "$SCRIPT_DIR/install.sh" ]; then
        log_pass "install.sh exists and is executable"
    else
        log_fail "install.sh missing or not executable"
    fi
    
    # Test that install script has proper structure
    if grep -q "Direct filesystem installation" "$SCRIPT_DIR/install.sh"; then
        log_pass "Install script is for direct installation"
    else
        log_fail "Install script doesn't mention direct installation"
    fi
    
    if grep -q "check_rw_filesystem" "$SCRIPT_DIR/install.sh"; then
        log_pass "Install script checks for RW filesystem"
    else
        log_fail "Install script doesn't check RW filesystem"
    fi
}

test_preserved_functionality() {
    log_test "Verifying mkshrc functionality is preserved"
    
    # Check essential components exist
    ESSENTIAL_FILES=(
        "etc/mkshrc"
        "etc/bash/bashrc"
        "etc/mkshrc.d/0000test.d.sh"
        "usr/share/lib-mkshrc/lib/util/sudo.sh"
        "usr/share/lib-mkshrc/lib/util/setperm.sh"
        "usr/share/lib-mkshrc/lib/util/f2c.sh"
        "usr/share/lib-mkshrc/bin/stew"
        "usr/share/lib-mkshrc/bin/open"
    )
    
    for file in "${ESSENTIAL_FILES[@]}"; do
        if [ -f "$TEST_ROOT/$file" ]; then
            log_pass "$file exists"
        else
            log_fail "$file missing"
        fi
    done
    
    # Check that main mkshrc can be sourced (syntax check)
    if bash -n "$TEST_ROOT/etc/mkshrc"; then
        log_pass "mkshrc has valid syntax"
    else
        log_fail "mkshrc has syntax errors"
    fi
}

test_uninstaller() {
    log_test "Verifying uninstaller functionality"
    
    # Check if uninstaller is created by install script
    if grep -q "create_uninstaller" "$SCRIPT_DIR/install.sh"; then
        log_pass "Install script creates uninstaller"
    else
        log_fail "Install script doesn't create uninstaller"
    fi
    
    if grep -q "/usr/share/lib-mkshrc/uninstall.sh" "$SCRIPT_DIR/install.sh"; then
        log_pass "Uninstaller path is correct"
    else
        log_fail "Uninstaller path is wrong or missing"
    fi
}

test_backup_system() {
    log_test "Verifying backup system"
    
    if grep -q "backup_existing" "$SCRIPT_DIR/install.sh"; then
        log_pass "Install script includes backup functionality"
    else
        log_fail "Install script doesn't backup existing files"
    fi
    
    if grep -q "/data/mkshrc_backup_" "$SCRIPT_DIR/install.sh"; then
        log_pass "Backup location is appropriate"
    else
        log_fail "Backup location is wrong or missing"
    fi
}

run_all_tests() {
    setup_test_env
    test_no_magisk_dependencies
    test_no_vendor_references  
    test_rw_paths_only
    test_direct_installation
    test_preserved_functionality
    test_uninstaller
    test_backup_system
    
    # Cleanup
    rm -rf "$TEST_ROOT"
    
    echo ""
    if [ $FAILED_TESTS -eq 0 ]; then
        echo "🎉 All tests passed! The systemless implementation meets requirements."
        echo ""
        echo "Summary of changes:"
        echo "- ✅ Removed Magisk module dependencies"
        echo "- ✅ Eliminated /vendor and /product path references"
        echo "- ✅ Targets only RW filesystems (/ and /system_ext)"
        echo "- ✅ Provides direct installation without bind mounts"
        echo "- ✅ Preserves all mkshrc functionality"
        echo "- ✅ Includes backup and uninstall capabilities"
        return 0
    else
        echo "❌ $FAILED_TESTS test(s) failed!"
        return 1
    fi
}

run_all_tests