#!/system/bin/sh

# Direct filesystem installation script for mkshrc
# For devices with RW mounted / and /system_ext

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

print_banner() {
    echo "========================================="
    echo "         Direct Mkshrc Installation      "
    echo "-----------------------------------------"
    echo " Installing mkshrc directly to filesystem"
    echo " for devices with RW root                "
    echo "-----------------------------------------"
    echo "      Direct Installation Version        "
    echo "========================================="
    echo ""
}

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1"
    exit 1
}

check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_error "This script must be run as root"
    fi
}

check_rw_filesystem() {
    log_info "Checking filesystem permissions..."
    
    # Test if root is writable
    if ! touch /test_write 2>/dev/null; then
        log_error "Root filesystem (/) is not writable"
    fi
    rm -f /test_write
    
    # Test if system_ext is writable (if it exists)
    if [ -d /system_ext ]; then
        if ! touch /system_ext/test_write 2>/dev/null; then
            log_error "/system_ext is not writable"
        fi
        rm -f /system_ext/test_write
    fi
    
    log_info "Filesystem permissions verified"
}

backup_existing() {
    log_info "Creating backup of existing files..."
    
    BACKUP_DIR="/data/mkshrc_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup existing mkshrc files
    [ -f /etc/mkshrc ] && cp /etc/mkshrc "$BACKUP_DIR/"
    [ -f /etc/bash/bashrc ] && cp /etc/bash/bashrc "$BACKUP_DIR/"
    [ -d /etc/mkshrc.d ] && cp -r /etc/mkshrc.d "$BACKUP_DIR/"
    [ -d /usr/share/lib-mkshrc ] && cp -r /usr/share/lib-mkshrc "$BACKUP_DIR/"
    
    if [ -d /system_ext ]; then
        [ -f /system_ext/etc/mkshrc ] && cp /system_ext/etc/mkshrc "$BACKUP_DIR/"
        [ -f /system_ext/etc/bash/bashrc ] && cp /system_ext/etc/bash/bashrc "$BACKUP_DIR/"
    fi
    
    echo "$BACKUP_DIR" > /data/mkshrc_last_backup
    log_info "Backup created in: $BACKUP_DIR"
}

install_files() {
    log_info "Installing mkshrc files..."
    
    # Install to root filesystem
    if [ -d "$SCRIPT_DIR/system" ]; then
        log_info "Copying files to root filesystem..."
        cp -r "$SCRIPT_DIR/system/"* /
        
        # Set proper permissions
        chmod 755 /usr/share/lib-mkshrc/bin/* 2>/dev/null
        chmod 644 /etc/mkshrc
        chmod 644 /etc/bash/bashrc
        chmod 644 /etc/mkshrc.d/*.sh 2>/dev/null
        chmod 644 /usr/share/lib-mkshrc/lib/*/*.sh 2>/dev/null
    else
        log_error "Source directory not found: $SCRIPT_DIR/system"
    fi
    
    # Install to system_ext if it exists and we have system_ext files
    if [ -d /system_ext ] && [ -d "$SCRIPT_DIR/system_ext" ]; then
        log_info "Installing system_ext files..."
        cp -r "$SCRIPT_DIR/system_ext/"* /system_ext/
        chmod 644 /system_ext/etc/mkshrc 2>/dev/null
        chmod 644 /system_ext/etc/bash/bashrc 2>/dev/null
    fi
}

create_uninstaller() {
    log_info "Creating uninstaller script..."
    
    cat > /usr/share/lib-mkshrc/uninstall.sh << 'EOF'
#!/system/bin/sh

# Uninstaller for direct mkshrc installation

echo "Removing mkshrc installation..."

# Remove main files
rm -f /etc/mkshrc
rm -f /etc/bash/bashrc
rm -rf /etc/mkshrc.d
rm -rf /usr/share/lib-mkshrc
rm -f /etc/passwd
rm -f /etc/resolv.conf
rm -f /etc/shells

# Remove system_ext files
if [ -d /system_ext ]; then
    rm -f /system_ext/etc/mkshrc
    rm -f /system_ext/etc/bash/bashrc
    rm -f /system_ext/etc/shells
fi

# Restore from backup if available
if [ -f /data/mkshrc_last_backup ]; then
    BACKUP_DIR="$(cat /data/mkshrc_last_backup)"
    if [ -d "$BACKUP_DIR" ]; then
        echo "Restoring backup from: $BACKUP_DIR"
        cp -r "$BACKUP_DIR/"* / 2>/dev/null
    fi
fi

echo "mkshrc uninstalled successfully"
EOF

    chmod 755 /usr/share/lib-mkshrc/uninstall.sh
}

main() {
    print_banner
    check_root
    check_rw_filesystem
    backup_existing
    install_files
    create_uninstaller
    
    log_info "Installation completed successfully!"
    echo ""
    echo "To start using mkshrc, run: su"
    echo "To uninstall later, run: /usr/share/lib-mkshrc/uninstall.sh"
    echo ""
}

main "$@"