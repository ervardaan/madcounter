# =============================================================================
# Homebrew Formula for MADCounter
# =============================================================================
#
# WHAT THIS FILE IS:
#   A "formula" is a Ruby script that tells Homebrew how to download,
#   compile, and install a package. This is how `brew install madcounter`
#   works — Homebrew reads this file, follows the instructions, and
#   installs the tool on the user's Mac.
#
# HOW TO PUBLISH THIS (so all macOS users can install):
#   1. Create a new GitHub repo named "homebrew-tap"
#      (MUST be named homebrew-<something>, the "homebrew-" prefix is required)
#      e.g., github.com/ervardaan/homebrew-tap
#
#   2. Create the directory structure in that repo:
#      homebrew-tap/
#      └── Formula/
#          └── madcounter.rb   ← this file goes here
#
#   3. Update the `url` and `sha256` fields below:
#      - `url`: GitHub archive URL for your tagged release
#      - `sha256`: SHA256 checksum of that archive (run: shasum -a 256 <file>)
#
#   4. Users install with:
#      brew tap ervardaan/tap
#      brew install madcounter
#
#   Or in one command:
#      brew install ervardaan/tap/madcounter
#
# HOW TO UPDATE AFTER A NEW RELEASE:
#   1. Push a new git tag (e.g., v1.1.0)
#   2. Download the GitHub-generated source archive:
#      curl -Lo madcounter.tar.gz https://github.com/ervardaan/madcounter/archive/refs/tags/v1.1.0.tar.gz
#   3. Get its hash:
#      shasum -a 256 madcounter.tar.gz
#   4. Update `url` and `sha256` in this file
#   5. Push to your homebrew-tap repo
#
# =============================================================================

class Madcounter < Formula
  desc "Analyze text files for character, word, and line statistics"
  homepage "https://github.com/ervardaan/madcounter"

  # -------------------------------------------------------------------------
  # SOURCE ARCHIVE
  # Replace this URL and sha256 after tagging your first release.
  #
  # The URL format for GitHub source archives is:
  #   https://github.com/USER/REPO/archive/refs/tags/TAG.tar.gz
  #
  # To get the sha256:
  #   curl -Lo madcounter.tar.gz https://github.com/.../vX.Y.Z.tar.gz
  #   shasum -a 256 madcounter.tar.gz
  # -------------------------------------------------------------------------
  url "https://github.com/ervardaan/madcounter/archive/refs/tags/v1.1.1.tar.gz"
  sha256 "610a9c69e7b3a7fed56ddd156a42e90a837a4b5d5c66dacdeeea3343b6eabf0f"
  version "1.1.1"
  license "MIT"

  # -------------------------------------------------------------------------
  # DEPENDENCIES
  # MADCounter is pure C with no external libraries.
  # The only tool needed is a C compiler — Homebrew provides that via Xcode.
  # So we have NO runtime dependencies.
  # -------------------------------------------------------------------------
  # (none)

  # -------------------------------------------------------------------------
  # INSTALL METHOD
  # Homebrew calls this method to build and install the package.
  # `bin.install` copies the binary to Homebrew's bin directory,
  # which is already in $PATH.
  # -------------------------------------------------------------------------
  def install
    # Compile from source using the system C compiler
    # Homebrew sets CC, CFLAGS, etc. automatically based on the platform
    system ENV.cc,
           "-Wall", "-Werror", "-O2", "-std=c99",
           "-o", "madcounter",
           "MADCounter.c"

    # Install the compiled binary to Homebrew's bin
    # This puts it in /opt/homebrew/bin/ (Apple Silicon) or /usr/local/bin/ (Intel)
    bin.install "madcounter"

    # Install the man page
    # man1.install puts it in /opt/homebrew/share/man/man1/
    man1.install "man/madcounter.1"
  end

  # -------------------------------------------------------------------------
  # TESTS
  # `brew test madcounter` runs these to verify the installation works.
  # Good practice — Homebrew CI will run these before accepting your formula
  # into the official homebrew-core repository.
  # -------------------------------------------------------------------------
  test do
    # Create a simple test file
    (testpath/"test.txt").write("hello world hello\n")

    # Run word analysis and check the output contains expected text
    assert_match "Total Number of Words: 3", shell_output("#{bin}/madcounter -f #{testpath}/test.txt -w")

    # Run character analysis
    assert_match "Total Number of Chars", shell_output("#{bin}/madcounter -f #{testpath}/test.txt -c")

    # Verify it errors correctly on missing file
    assert_match "ERROR:", shell_output("#{bin}/madcounter -f /tmp/nonexistent_xyz.txt -c", 1)
  end
end
