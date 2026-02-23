# =============================================================================
# MADCounter Makefile
# =============================================================================
#
# A Makefile is a set of instructions for the `make` tool.
# It tells make: "here are the source files, here are the targets,
# here is how to build each target."
#
# HOW TO USE:
#   make           - Compile the program (produces ./madcounter)
#   make install   - Install globally (requires sudo)
#   make uninstall - Remove from system (requires sudo)
#   make clean     - Delete compiled binary
#   make test      - Run a quick smoke test
#
# =============================================================================

# -----------------------------------------------------------------------------
# VARIABLES
# The := assignment evaluates immediately (faster than = which is lazy).
# $() references the variable.
# -----------------------------------------------------------------------------

# The C compiler to use. gcc is the standard on Linux; clang works on macOS.
CC := gcc

# Compiler flags:
#   -Wall   : Enable ALL common warnings. Good code should have zero warnings.
#   -Werror : Treat every warning as a hard error. Forces clean code.
#   -O2     : Optimization level 2. Makes the binary run faster.
#   -std=c99: Use the C99 standard (allows // comments, for-loop declarations)
CFLAGS := -Wall -Werror -O2 -std=c99

# Source file
SRC := MADCounter.c

# Name of the compiled binary
BINARY := madcounter

# -----------------------------------------------------------------------------
# INSTALLATION DIRECTORIES
# On Linux/macOS these are the standard places for user-installed commands.
# DESTDIR allows package managers to install to a staging area first.
# -----------------------------------------------------------------------------

# /usr/local/bin is where user-installed commands live.
# (As opposed to /usr/bin which is for OS-managed packages.)
BINDIR    := $(DESTDIR)/usr/local/bin

# /usr/local/share/man/man1 is where section-1 man pages live.
# man(1) = user commands. man(2) = system calls. man(3) = library functions.
MANDIR    := $(DESTDIR)/usr/local/share/man/man1

# -----------------------------------------------------------------------------
# BUILD TARGETS
# Format:
#   target: dependencies
#   <TAB> command
#
# IMPORTANT: the indentation MUST be a TAB character, not spaces.
# -----------------------------------------------------------------------------

# Default target: what runs when you just type `make`
# The .PHONY declaration (bottom of file) marks this as a non-file target.
all: $(BINARY)

# How to build the `madcounter` binary from MADCounter.c
# $@ = the target name (madcounter)
# $< = the first dependency (MADCounter.c)
$(BINARY): $(SRC)
	@echo "Compiling $(BINARY)..."
	$(CC) $(CFLAGS) -o $@ $<
	@echo "Build successful! Binary: ./$(BINARY)"

# -----------------------------------------------------------------------------
# INSTALL TARGET
# Copies the binary and man page into system directories.
# This is what makes `madcounter` available from anywhere on the system.
# Requires sudo (writing to /usr/local/bin needs root permission).
# -----------------------------------------------------------------------------
install: $(BINARY)
	@echo ""
	@echo "=== Installing MADCounter ==="

	# Create directories if they don't exist
	# -p = no error if already exists, create parents too
	@mkdir -p $(BINDIR)
	@mkdir -p $(MANDIR)

	# Copy the binary to /usr/local/bin/madcounter
	# -m 755 = set permissions: owner can rwx, others can rx (execute but not write)
	install -m 755 $(BINARY) $(BINDIR)/$(BINARY)
	@echo "  [OK] Binary installed: $(BINDIR)/$(BINARY)"

	# Copy the man page to /usr/local/share/man/man1/madcounter.1
	install -m 644 man/madcounter.1 $(MANDIR)/madcounter.1
	@echo "  [OK] Man page installed: $(MANDIR)/madcounter.1"

	# Update the man page database so `man madcounter` works immediately
	# The `|| true` means: don't fail if mandb isn't available (e.g. on macOS)
	@mandb 2>/dev/null || true

	@echo ""
	@echo "=== Installation Complete! ==="
	@echo "Try these commands:"
	@echo "  madcounter -f <file> -c      (character analysis)"
	@echo "  man madcounter               (view documentation)"
	@echo ""

# -----------------------------------------------------------------------------
# UNINSTALL TARGET
# Removes everything that `make install` put on the system.
# Always provide this so users can cleanly remove your program.
# -----------------------------------------------------------------------------
uninstall:
	@echo ""
	@echo "=== Uninstalling MADCounter ==="

	# Remove the binary
	rm -f $(BINDIR)/$(BINARY)
	@echo "  [OK] Removed: $(BINDIR)/$(BINARY)"

	# Remove the man page
	rm -f $(MANDIR)/madcounter.1
	@echo "  [OK] Removed: $(MANDIR)/madcounter.1"

	# Update man database
	@mandb 2>/dev/null || true

	@echo ""
	@echo "=== MADCounter uninstalled ==="

# -----------------------------------------------------------------------------
# CLEAN TARGET
# Removes built artifacts. Keeps source code only.
# Useful before a fresh rebuild or before distributing source.
# -----------------------------------------------------------------------------
clean:
	@echo "Cleaning build artifacts..."
	rm -f $(BINARY)
	@echo "  [OK] Removed: ./$(BINARY)"

# -----------------------------------------------------------------------------
# TEST TARGET
# Quick smoke test: compile, run on a temp file, verify it works.
# Smoke test = "does it catch fire when you turn it on?" (basic sanity check)
# -----------------------------------------------------------------------------
test: $(BINARY)
	@echo ""
	@echo "=== Running smoke test ==="

	# Create a small test file
	@echo "the quick brown fox jumps over the lazy dog" > /tmp/madcounter_test.txt

	# Run the program with all flags
	@echo "--- Running: ./madcounter -f /tmp/madcounter_test.txt -c -w -l -Lw -Ll ---"
	@./$(BINARY) -f /tmp/madcounter_test.txt -c -w -l -Lw -Ll

	# Clean up
	@rm -f /tmp/madcounter_test.txt

	@echo ""
	@echo "=== Test passed! ==="

# -----------------------------------------------------------------------------
# HELP TARGET
# Self-documenting: shows available commands.
# Good practice for any Makefile.
# -----------------------------------------------------------------------------
help:
	@echo ""
	@echo "MADCounter - Text Analysis Utility"
	@echo "==================================="
	@echo ""
	@echo "Build Commands:"
	@echo "  make           Compile the program"
	@echo "  make install   Install globally (requires sudo)"
	@echo "  make uninstall Remove from system (requires sudo)"
	@echo "  make clean     Remove compiled files"
	@echo "  make test      Run quick smoke test"
	@echo ""
	@echo "Usage after install:"
	@echo "  madcounter -f <file> [-o <outfile>] [-c] [-w] [-l] [-Lw] [-Ll]"
	@echo "  madcounter -B <batch_file>"
	@echo "  man madcounter"
	@echo ""

# -----------------------------------------------------------------------------
# .PHONY declaration
# Tells make: these target names are NOT filenames.
# Without this, if a file named "clean" existed, `make clean` would do nothing.
# -----------------------------------------------------------------------------
.PHONY: all install uninstall clean test help
