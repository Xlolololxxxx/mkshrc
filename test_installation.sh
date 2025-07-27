#!/bin/bash

# Test script for direct mkshrc installation

set -e

echo "Testing mkshrc direct installation..."

# Create a temporary test environment
TEST_ROOT="/tmp/mkshrc_test"
rm -rf "$TEST_ROOT"
mkdir -p "$TEST_ROOT"

# Create fake filesystem structure
mkdir -p "$TEST_ROOT"/{etc,usr/share,system_ext/etc}

# Copy source files to test directory
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
cp -r "$SCRIPT_DIR/system"/* "$TEST_ROOT/"
[ -d "$SCRIPT_DIR/system_ext" ] && cp -r "$SCRIPT_DIR/system_ext"/* "$TEST_ROOT/system_ext/"

echo "✓ Files copied to test environment"

# Test that main mkshrc file exists and is readable
if [ -f "$TEST_ROOT/etc/mkshrc" ]; then
    echo "✓ Main mkshrc file exists"
else
    echo "✗ Main mkshrc file missing"
    exit 1
fi

# Test that library files exist
if [ -d "$TEST_ROOT/usr/share/lib-mkshrc/lib" ]; then
    echo "✓ Library directory exists"
else
    echo "✗ Library directory missing"
    exit 1
fi

# Test that essential library files exist
ESSENTIAL_LIBS=(
    "util/sudo.sh"
    "util/setperm.sh"
    "util/f2c.sh"
    "console/ui_print.sh"
    "console/abort.sh"
)

for lib in "${ESSENTIAL_LIBS[@]}"; do
    if [ -f "$TEST_ROOT/usr/share/lib-mkshrc/lib/$lib" ]; then
        echo "✓ Library $lib exists"
    else
        echo "✗ Library $lib missing"
        exit 1
    fi
done

# Test that binaries exist
if [ -d "$TEST_ROOT/usr/share/lib-mkshrc/bin" ]; then
    echo "✓ Binary directory exists"
    ls -la "$TEST_ROOT/usr/share/lib-mkshrc/bin/"
else
    echo "✗ Binary directory missing"
    exit 1
fi

# Test system_ext files if they exist
if [ -d "$TEST_ROOT/system_ext" ]; then
    if [ -f "$TEST_ROOT/system_ext/etc/mkshrc" ]; then
        echo "✓ system_ext mkshrc file exists"
    else
        echo "✗ system_ext mkshrc file missing"
        exit 1
    fi
fi

# Test that main mkshrc script can be sourced (syntax check)
echo "Testing mkshrc syntax..."
if bash -n "$TEST_ROOT/etc/mkshrc"; then
    echo "✓ mkshrc syntax is valid"
else
    echo "✗ mkshrc syntax error"
    exit 1
fi

echo ""
echo "All tests passed! ✓"
echo "Installation structure is valid."

# Cleanup
rm -rf "$TEST_ROOT"