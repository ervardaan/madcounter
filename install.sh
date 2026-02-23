#!/bin/bash
# =============================================================================
# MADCounter Installer
# =============================================================================
#
# WHAT THIS SCRIPT DOES:
#   1. Detects your operating system (Linux or macOS)
#   2. Checks that required tools are installed (gcc, make)
#   3. Compiles MADCounter.c into an executable binary
#   4. Installs the binary to /usr/local/bin so it's available everywhere
#   5. Installs the man page so `man madcounter` works
#
# HOW TO RUN:
#   chmod +x install.sh       # Make script executable
#   sudo ./install.sh         # Install
#   sudo ./install.sh remove  # Uninstall
#
# =============================================================================

# ---------------------------------------------------------------------------
# STRICT MODE
# ---------------------------------------------------------------------------
# set -e  : Exit immediately if any command returns non-zero exit code.
#           This prevents errors from silently being ignored.
# set -u  : Treat unset variables as errors.
# set -o pipefail: If a pipe fails, the whole pipe fails (not just last part).
set -euo pipefail

# ---------------------------------------------------------------------------
# COLOR CODES
# ---------------------------------------------------------------------------
# These ANSI escape codes add color to terminal output.
# \033[ = escape sequence start
# 0;32m = color code (green)
# 0m    = reset (back to default)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# Helper functions for colored output
info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; }
step()    { echo -e "${BOLD}--- $* ---${RESET}"; }

# ---------------------------------------------------------------------------
# INSTALLATION DIRECTORIES
# /usr/local/bin  = user-installed executables (in $PATH by default)
# /usr/local/share/man/man1 = man pages for section 1 commands
# ---------------------------------------------------------------------------
INSTALL_BIN="/usr/local/bin"
INSTALL_MAN="/usr/local/share/man/man1"
BINARY_NAME="madcounter"

# ---------------------------------------------------------------------------
# DETECT OPERATING SYSTEM
# Different OSes need slightly different handling.
# uname -s returns the OS name: "Linux", "Darwin" (macOS), etc.
# ---------------------------------------------------------------------------
detect_os() {
    OS=$(uname -s)
    case "$OS" in
        Linux)
            info "Operating system: Linux"
            ;;
        Darwin)
            info "Operating system: macOS"
            ;;
        *)
            error "Unsupported operating system: $OS"
            error "MADCounter supports Linux and macOS only."
            exit 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# CHECK PREREQUISITES
# We need gcc to compile C code and make to use the Makefile.
# `command -v NAME` returns the path if found, empty string if not found.
# ---------------------------------------------------------------------------
check_prerequisites() {
    step "Checking prerequisites"

    local missing=0

    # Check for gcc
    if command -v gcc &>/dev/null; then
        GCC_VERSION=$(gcc --version | head -n1)
        success "gcc found: $GCC_VERSION"
    else
        error "gcc not found! Please install it:"
        error "  Ubuntu/Debian: sudo apt-get install build-essential"
        error "  Fedora/RHEL:   sudo dnf install gcc"
        error "  macOS:         xcode-select --install"
        error "  macOS (brew):  brew install gcc"
        missing=1
    fi

    # Check for make
    if command -v make &>/dev/null; then
        success "make found: $(make --version | head -n1)"
    else
        error "make not found! Please install it:"
        error "  Ubuntu/Debian: sudo apt-get install build-essential"
        error "  macOS:         xcode-select --install"
        missing=1
    fi

    # If anything is missing, exit
    if [ "$missing" -ne 0 ]; then
        error "Please install missing prerequisites and retry."
        exit 1
    fi

    echo ""
}

# ---------------------------------------------------------------------------
# CHECK SUDO / ROOT PERMISSIONS
# Installing to /usr/local/bin requires root permissions.
# We check if we're running as root or if sudo is available.
# ---------------------------------------------------------------------------
check_permissions() {
    # EUID = Effective User ID. Root = 0.
    if [ "$EUID" -ne 0 ]; then
        error "Installation requires root permissions."
        error "Please run: sudo ./install.sh"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# COMPILE
# Runs gcc to compile MADCounter.c into the madcounter binary.
# ---------------------------------------------------------------------------
compile() {
    step "Compiling MADCounter"

    # Check the source file exists
    if [ ! -f "MADCounter.c" ]; then
        error "Source file MADCounter.c not found!"
        error "Make sure you're running this script from the project directory."
        exit 1
    fi

    # Compile with optimizations and strict warning flags
    # -Wall    = all warnings
    # -Werror  = warnings are errors
    # -O2      = optimize for speed
    # -std=c99 = C99 standard
    gcc -Wall -Werror -O2 -std=c99 -o "$BINARY_NAME" MADCounter.c

    success "Compiled successfully: ./$BINARY_NAME"
    echo ""
}

# ---------------------------------------------------------------------------
# INSTALL BINARY
# Copies the compiled binary to /usr/local/bin
# ---------------------------------------------------------------------------
install_binary() {
    step "Installing binary"

    mkdir -p "$INSTALL_BIN"

    # install is better than cp here:
    # - Sets permissions correctly (-m 755 = rwxr-xr-x)
    # - Preserves timestamps
    # - Creates backup if needed
    install -m 755 "$BINARY_NAME" "$INSTALL_BIN/$BINARY_NAME"

    success "Binary installed: $INSTALL_BIN/$BINARY_NAME"
    echo ""
}

# ---------------------------------------------------------------------------
# INSTALL MAN PAGE
# Copies the man page to /usr/local/share/man/man1
# Then updates the man database so `man madcounter` sees it immediately
# ---------------------------------------------------------------------------
install_man_page() {
    step "Installing man page"

    if [ ! -f "man/madcounter.1" ]; then
        warn "Man page not found (man/madcounter.1). Skipping."
        return 0
    fi

    mkdir -p "$INSTALL_MAN"

    # Copy man page. Permission 644 = rw-r--r-- (read by all, write by owner)
    install -m 644 man/madcounter.1 "$INSTALL_MAN/madcounter.1"
    success "Man page installed: $INSTALL_MAN/madcounter.1"

    # Rebuild the man database
    # mandb scans all man directories and updates the index used by `man -k`
    # The `|| true` means: don't fail if mandb isn't available (e.g. on macOS)
    if command -v mandb &>/dev/null; then
        mandb --quiet 2>/dev/null || true
        success "Man database updated"
    elif command -v makewhatis &>/dev/null; then
        makewhatis "$INSTALL_MAN" 2>/dev/null || true
        success "Man database updated (makewhatis)"
    else
        warn "mandb not found. Run 'man madcounter' may need mandb update later."
    fi

    echo ""
}

# ---------------------------------------------------------------------------
# VERIFY INSTALLATION
# Run `madcounter -f <file>` to confirm everything works after installation.
# ---------------------------------------------------------------------------
verify_installation() {
    step "Verifying installation"

    # Check the binary is in PATH
    if ! command -v madcounter &>/dev/null; then
        error "madcounter not found in PATH after installation!"
        error "Make sure $INSTALL_BIN is in your PATH:"
        error "  export PATH=\$PATH:/usr/local/bin"
        exit 1
    fi

    # Quick functional test: analyze a small file
    local testfile
    testfile=$(mktemp /tmp/madcounter_test_XXXXXX.txt)
    echo "hello world hello" > "$testfile"

    RESULT=$(madcounter -f "$testfile" -w 2>&1)
    rm -f "$testfile"

    # Check that output contains expected text
    if echo "$RESULT" | grep -q "Total Number of Words: 3"; then
        success "Functional test passed!"
    else
        error "Functional test failed! Output was:"
        echo "$RESULT"
        exit 1
    fi

    echo ""
}

# ---------------------------------------------------------------------------
# UNINSTALL
# Removes everything that install() put on the system.
# Good practice: a program that installs cleanly should also uninstall cleanly.
# ---------------------------------------------------------------------------
uninstall() {
    step "Uninstalling MADCounter"
    check_permissions

    local removed=0

    if [ -f "$INSTALL_BIN/$BINARY_NAME" ]; then
        rm -f "$INSTALL_BIN/$BINARY_NAME"
        success "Removed: $INSTALL_BIN/$BINARY_NAME"
        removed=1
    else
        warn "Binary not found at $INSTALL_BIN/$BINARY_NAME (already removed?)"
    fi

    if [ -f "$INSTALL_MAN/madcounter.1" ]; then
        rm -f "$INSTALL_MAN/madcounter.1"
        success "Removed: $INSTALL_MAN/madcounter.1"
        removed=1
    else
        warn "Man page not found (already removed?)"
    fi

    # Update man database
    if command -v mandb &>/dev/null; then
        mandb --quiet 2>/dev/null || true
    fi

    if [ "$removed" -eq 1 ]; then
        echo ""
        success "MADCounter has been uninstalled."
    else
        echo ""
        warn "Nothing was removed (MADCounter may not have been installed)."
    fi
}

# ---------------------------------------------------------------------------
# PRINT POST-INSTALL INSTRUCTIONS
# Tells the user what they can now do.
# ---------------------------------------------------------------------------
print_completion() {
    echo ""
    echo -e "${GREEN}${BOLD}========================================${RESET}"
    echo -e "${GREEN}${BOLD}  MADCounter Successfully Installed!${RESET}"
    echo -e "${GREEN}${BOLD}========================================${RESET}"
    echo ""
    echo "You can now use madcounter from anywhere:"
    echo ""
    echo "  madcounter -f <file> -c           # Character analysis"
    echo "  madcounter -f <file> -w           # Word analysis"
    echo "  madcounter -f <file> -l           # Line analysis"
    echo "  madcounter -f <file> -Lw          # Longest word"
    echo "  madcounter -f <file> -Ll          # Longest line"
    echo "  madcounter -f <file> -c -w -l     # All three"
    echo "  madcounter -B <batch.txt>         # Batch mode"
    echo "  madcounter -f <file> -o out.txt   # Write to file"
    echo ""
    echo "  man madcounter                    # View full documentation"
    echo ""
    echo "To uninstall later: sudo ./install.sh remove"
    echo ""
}

# ---------------------------------------------------------------------------
# MAIN ENTRY POINT
# What runs when you execute this script.
# $1 = first argument to the script ("remove" or empty)
# ---------------------------------------------------------------------------
main() {
    echo ""
    echo -e "${BOLD}MADCounter Installer v1.0${RESET}"
    echo "==============================="
    echo ""

    # Handle "remove" argument
    if [ "${1:-}" = "remove" ] || [ "${1:-}" = "uninstall" ]; then
        uninstall
        exit 0
    fi

    # Full install flow
    detect_os
    check_prerequisites
    check_permissions
    compile
    install_binary
    install_man_page
    verify_installation
    print_completion
}

# Run main, passing all script arguments
# "$@" passes all arguments to `main` (preserving quoting)
main "$@"
