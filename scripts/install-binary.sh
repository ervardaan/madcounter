#!/bin/sh
# =============================================================================
# MADCounter One-Line Installer
# =============================================================================
#
# WHAT THIS SCRIPT DOES:
#   1. Detects your operating system (Linux or macOS)
#   2. Detects your CPU architecture (x86_64 / ARM64)
#   3. Downloads the correct pre-compiled binary from GitHub Releases
#   4. Installs it to /usr/local/bin/madcounter
#   5. Verifies the installation works
#
# HOW USERS RUN THIS (one command, works on any machine):
#   curl -fsSL https://raw.githubusercontent.com/ervardaan/madcounter/main/scripts/install-binary.sh | bash
#   # or with explicit sudo for system-wide install:
#   curl -fsSL https://raw.githubusercontent.com/.../install-binary.sh | sudo bash
#
# WHY THIS IS POWERFUL:
#   - No compiler needed on user's machine
#   - Downloads the binary we pre-built on GitHub Actions
#   - Works on any Linux (Ubuntu, Fedora, Debian, Alpine...) and macOS
#   - Single command — zero friction for new users
#
# SECURITY NOTE:
#   Curl-pipe-bash is convenient but requires trust in the server.
#   For security-conscious users, the manual download option is also shown.
#
# =============================================================================

set -e  # Exit on any error

# -----------------------------------------------------------------------
# CONFIGURATION — Update these when you release a new version
# -----------------------------------------------------------------------
GITHUB_USER="ervardaan"
GITHUB_REPO="madcounter"
VERSION="1.0.0"
BINARY_NAME="madcounter"
INSTALL_DIR="/usr/local/bin"

GITHUB_BASE="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/releases/download/v${VERSION}"

# -----------------------------------------------------------------------
# COLOR OUTPUT
# Uses ANSI escape codes for colored terminal output
# -----------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# Print helpers
info()    { printf "${BLUE}[INFO]${RESET}  %s\n" "$*"; }
success() { printf "${GREEN}[OK]${RESET}    %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${RESET}  %s\n" "$*"; }
error()   { printf "${RED}[ERROR]${RESET} %s\n" "$*" >&2; }

# -----------------------------------------------------------------------
# DETECT OS AND ARCHITECTURE
# -----------------------------------------------------------------------
detect_platform() {
    # uname -s → "Linux" or "Darwin" (macOS uses Darwin as kernel name)
    OS=$(uname -s)
    # uname -m → "x86_64" or "arm64" or "aarch64"
    ARCH=$(uname -m)

    case "$OS" in
        Linux)
            case "$ARCH" in
                x86_64)
                    PLATFORM="linux-x86_64"
                    ;;
                aarch64|arm64)
                    PLATFORM="linux-arm64"
                    ;;
                *)
                    error "Unsupported Linux architecture: $ARCH"
                    error "Supported: x86_64, aarch64"
                    error ""
                    error "To compile from source:"
                    error "  git clone https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
                    error "  cd ${GITHUB_REPO} && make && sudo make install"
                    exit 1
                    ;;
            esac
            ;;
        Darwin)
            case "$ARCH" in
                x86_64)
                    PLATFORM="macos-x86_64"
                    ;;
                arm64)
                    PLATFORM="macos-arm64"
                    ;;
                *)
                    error "Unsupported macOS architecture: $ARCH"
                    exit 1
                    ;;
            esac
            ;;
        MINGW*|CYGWIN*|MSYS*)
            error "Windows detected (Git Bash / MSYS2)."
            error ""
            error "Install via Scoop (recommended for Windows):"
            error "  scoop bucket add ervardaan https://github.com/ervardaan/scoop-bucket"
            error "  scoop install madcounter"
            error ""
            error "Or run inside WSL (Windows Subsystem for Linux):"
            error "  wsl --install          # one-time setup in PowerShell"
            error "  Then re-run this script inside the WSL terminal."
            exit 1
            ;;
        *)
            error "Unsupported operating system: $OS"
            error "MADCounter supports Linux and macOS natively."
            error ""
            error "Windows users: use Scoop or WSL (see above)."
            error ""
            error "To compile from source:"
            error "  git clone https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
            error "  cd ${GITHUB_REPO} && make && sudo make install"
            exit 1
            ;;
    esac

    info "Detected platform: $OS $ARCH → $PLATFORM"
}

# -----------------------------------------------------------------------
# CHECK FOR DOWNLOAD TOOL
# Most systems have curl; fall back to wget if not present
# -----------------------------------------------------------------------
check_downloader() {
    if command -v curl >/dev/null 2>&1; then
        DOWNLOADER="curl"
    elif command -v wget >/dev/null 2>&1; then
        DOWNLOADER="wget"
    else
        error "Neither curl nor wget found."
        error "Please install one:"
        error "  Ubuntu/Debian: sudo apt-get install curl"
        error "  Fedora/RHEL:   sudo dnf install curl"
        error "  macOS:         xcode-select --install"
        exit 1
    fi
    info "Download tool: $DOWNLOADER"
}

# -----------------------------------------------------------------------
# DOWNLOAD THE BINARY
# -----------------------------------------------------------------------
download_binary() {
    ASSET_NAME="${BINARY_NAME}-${PLATFORM}"
    DOWNLOAD_URL="${GITHUB_BASE}/${ASSET_NAME}"
    TEMP_FILE=$(mktemp /tmp/madcounter_XXXXXX)

    info "Downloading from: $DOWNLOAD_URL"

    if [ "$DOWNLOADER" = "curl" ]; then
        # -f = fail on HTTP error
        # -s = silent (no progress bar)
        # -S = show error if it fails
        # -L = follow redirects (GitHub uses redirects for release assets)
        curl -fsSL "$DOWNLOAD_URL" -o "$TEMP_FILE"
    else
        # wget equivalent flags
        wget -q "$DOWNLOAD_URL" -O "$TEMP_FILE"
    fi

    # Verify we actually downloaded something
    if [ ! -s "$TEMP_FILE" ]; then
        error "Downloaded file is empty. Download may have failed."
        error "URL was: $DOWNLOAD_URL"
        error ""
        error "You can manually download at:"
        error "  https://github.com/${GITHUB_USER}/${GITHUB_REPO}/releases"
        rm -f "$TEMP_FILE"
        exit 1
    fi

    success "Downloaded ($(du -h "$TEMP_FILE" | cut -f1) bytes)"
    echo "$TEMP_FILE"
}

# -----------------------------------------------------------------------
# INSTALL THE BINARY
# -----------------------------------------------------------------------
install_binary() {
    TEMP_FILE="$1"

    # Make the downloaded binary executable
    chmod +x "$TEMP_FILE"

    # Quick verify: the file should be an ELF/Mach-O executable
    # `file` command returns "ELF" for Linux binaries, "Mach-O" for macOS
    if command -v file >/dev/null 2>&1; then
        FILE_TYPE=$(file "$TEMP_FILE")
        case "$OS" in
            Linux)
                if ! echo "$FILE_TYPE" | grep -q "ELF"; then
                    error "Downloaded file doesn't appear to be a Linux binary."
                    error "file output: $FILE_TYPE"
                    rm -f "$TEMP_FILE"
                    exit 1
                fi
                ;;
            Darwin)
                if ! echo "$FILE_TYPE" | grep -q "Mach-O"; then
                    error "Downloaded file doesn't appear to be a macOS binary."
                    error "file output: $FILE_TYPE"
                    rm -f "$TEMP_FILE"
                    exit 1
                fi
                ;;
        esac
    fi

    # Try to install to INSTALL_DIR
    # If we're root, do it directly. If not, try sudo.
    if [ -w "$INSTALL_DIR" ] || [ "$(id -u)" -eq 0 ]; then
        mv "$TEMP_FILE" "$INSTALL_DIR/$BINARY_NAME"
        chmod 755 "$INSTALL_DIR/$BINARY_NAME"
    else
        info "Installation requires sudo (writing to $INSTALL_DIR)"
        sudo mv "$TEMP_FILE" "$INSTALL_DIR/$BINARY_NAME"
        sudo chmod 755 "$INSTALL_DIR/$BINARY_NAME"
    fi

    success "Installed: $INSTALL_DIR/$BINARY_NAME"
}

# -----------------------------------------------------------------------
# VERIFY INSTALLATION
# -----------------------------------------------------------------------
verify_installation() {
    # Check it's in PATH
    if ! command -v "$BINARY_NAME" >/dev/null 2>&1; then
        warn "$BINARY_NAME not found in PATH after installation."
        warn "You may need to add $INSTALL_DIR to your PATH:"
        warn "  export PATH=\"\$PATH:$INSTALL_DIR\""
        warn "Add that line to ~/.bashrc or ~/.zshrc to make it permanent."
        return
    fi

    # Quick functional test
    TESTFILE=$(mktemp /tmp/madcounter_verify_XXXXXX.txt)
    printf "hello world hello\n" > "$TESTFILE"
    RESULT=$(madcounter -f "$TESTFILE" -w 2>&1)
    rm -f "$TESTFILE"

    if echo "$RESULT" | grep -q "Total Number of Words: 3"; then
        success "Functional test passed!"
    else
        warn "Functional test produced unexpected output:"
        warn "$RESULT"
    fi
}

# -----------------------------------------------------------------------
# PRINT SUCCESS AND USAGE INSTRUCTIONS
# -----------------------------------------------------------------------
print_welcome() {
    printf "\n"
    printf "${GREEN}${BOLD}================================${RESET}\n"
    printf "${GREEN}${BOLD}  MADCounter ${VERSION} installed!${RESET}\n"
    printf "${GREEN}${BOLD}================================${RESET}\n"
    printf "\n"
    printf "Try these commands:\n"
    printf "\n"
    printf "  madcounter -f <file> -c          # Character analysis\n"
    printf "  madcounter -f <file> -w          # Word analysis\n"
    printf "  madcounter -f <file> -l          # Line analysis\n"
    printf "  madcounter -f <file> -Lw -Ll     # Longest word and line\n"
    printf "  madcounter -f <file> -c -w -l    # All three\n"
    printf "  madcounter -B <batch.txt>        # Batch mode\n"
    printf "\n"
    printf "Documentation:\n"
    printf "  man madcounter                   # Full man page (if installed)\n"
    printf "  madcounter --help                # Quick usage\n"
    printf "\n"
    if [ "$OS" = "Darwin" ]; then
        printf "Tip: Try Homebrew for easier updates:\n"
        printf "  brew tap ${GITHUB_USER}/tap\n"
        printf "  brew install madcounter\n"
        printf "\n"
    fi
}

# -----------------------------------------------------------------------
# MAIN
# -----------------------------------------------------------------------
main() {
    printf "\n"
    printf "${BOLD}MADCounter Installer v${VERSION}${RESET}\n"
    printf "=====================================\n"
    printf "\n"

    detect_platform
    check_downloader

    printf "\n"
    info "Downloading madcounter ${VERSION} for ${PLATFORM}..."
    TEMP_FILE=$(download_binary)

    printf "\n"
    info "Installing to ${INSTALL_DIR}..."
    install_binary "$TEMP_FILE"

    printf "\n"
    info "Verifying installation..."
    verify_installation

    print_welcome
}

main "$@"
