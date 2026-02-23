# MADCounter Worldwide Distribution Guide

## Overview

This guide explains how to make `madcounter` installable worldwide — so that anyone on any computer can install it with a single command, just like `grep`, `ls`, or `wget`.

**After following this guide, users worldwide can install with:**

- **macOS**: `brew install YOUR_USERNAME/tap/madcounter`
- **All platforms (one-liner)**: `curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/madcounter/main/scripts/install-binary.sh | bash`
- **Arch Linux**: `yay -S madcounter`
- **Ubuntu/Debian (via PPA)**: `sudo apt install madcounter`

---

## Step 1: Create a GitHub Repository (Foundation of Everything)

All worldwide distribution depends on having a public GitHub repository. This is where your source code, compiled binaries, and installer scripts live.

**What to do:**

1. Go to https://github.com → click **New repository**
2. Name it: `madcounter`
3. Set visibility: **Public** (required — package managers need public access)
4. Do NOT initialize with README (you already have files)
5. Click **Create repository**

**Then push your code:**

```bash
cd /Users/vardaankapoor/Documents/p1
git init   # (already done if git is set up)
git remote add origin https://github.com/YOUR_USERNAME/madcounter.git
git add .
git commit -m "Initial release v1.0.0"
git push -u origin main
```

**WHY:** GitHub is the central hub. Homebrew downloads your source from here. GitHub Actions compiles here. The curl installer downloads binaries from here. Without a public GitHub repo, nothing else works.

---

## Step 2: Replace ervardaan in All Files

Before pushing, replace the placeholder in these files:

| File | Find | Replace With |
|------|------|-------------|
| `.github/workflows/release.yml` | `ervardaan` | your GitHub username |
| `homebrew/madcounter.rb` | `ervardaan` | your GitHub username |
| `aur/PKGBUILD` | `ervardaan` | your GitHub username |
| `scripts/install-binary.sh` | `ervardaan` | your GitHub username |
| `man/madcounter.1` (SEE ALSO) | `ervardaan` | your GitHub username |
| `DEPLOYMENT_GUIDE.md` | `ervardaan` | your GitHub username |

**Command to find all occurrences:**
```bash
grep -r "ervardaan" .
grep -r "ervardaan" .
```

---

## Step 3: Tag a Release — This Triggers Automatic Compilation

When you push a git tag, GitHub Actions automatically:
1. Starts 3 machines: Ubuntu Linux, macOS Intel, macOS Apple Silicon
2. Compiles `madcounter` on each machine
3. Creates a GitHub Release with 3 downloadable binaries

**What to do:**

```bash
# Create and push a version tag
git tag v1.0.0
git push origin v1.0.0
```

**Then watch the magic happen:**
1. Go to: `https://github.com/YOUR_USERNAME/madcounter/actions`
2. You will see a workflow run called "Release" — it takes 2-3 minutes
3. After it completes, go to: `https://github.com/YOUR_USERNAME/madcounter/releases`
4. You will see a release called "MADCounter v1.0.0" with 3 binary downloads

**WHY this step matters:** The Homebrew formula and curl installer both download from the GitHub Releases page. Without a tagged release, users have nothing to download.

---

## Step 4: Publish Homebrew Tap (macOS Users)

Homebrew is the #1 package manager for macOS. This makes `brew install madcounter` work.

**What to do:**

### 4a. Create a Homebrew Tap Repository

1. On GitHub, create a **new repository** named exactly: `homebrew-tap`
   - The `homebrew-` prefix is required by Homebrew
   - Full URL: `https://github.com/YOUR_USERNAME/homebrew-tap`
   - Set as Public

2. Create the directory structure:
   ```
   homebrew-tap/
   └── Formula/
       └── madcounter.rb
   ```

3. Copy the formula file from this project:
   ```bash
   mkdir -p Formula
   cp /path/to/madcounter/homebrew/madcounter.rb Formula/
   ```

### 4b. Update the Formula with Real SHA256

After creating the release in Step 3:

```bash
# Download the source archive GitHub created for your tag
curl -Lo madcounter.tar.gz https://github.com/YOUR_USERNAME/madcounter/archive/refs/tags/v1.0.0.tar.gz

# Get its SHA256 hash
shasum -a 256 madcounter.tar.gz
# Output: abc123def456...  madcounter.tar.gz

# Update the formula with this hash
# Edit Formula/madcounter.rb:
#   sha256 "abc123def456..."   ← replace REPLACE_WITH_ACTUAL_SHA256_AFTER_TAGGING
```

### 4c. Push the Tap Repo

```bash
cd homebrew-tap
git init
git add .
git commit -m "Add madcounter formula v1.0.0"
git remote add origin https://github.com/YOUR_USERNAME/homebrew-tap.git
git push -u origin main
```

### 4d. Users Install With:

```bash
brew tap YOUR_USERNAME/tap
brew install madcounter
# or in one command:
brew install YOUR_USERNAME/tap/madcounter
```

**WHY:** `brew` is how basically all developers on macOS install CLI tools. Supporting it makes madcounter accessible to millions of Mac users.

---

## Step 5: Publish to AUR (Arch Linux Users)

AUR (Arch User Repository) is how Arch Linux users install packages. Arch is popular with developers.

**What to do:**

1. Create an account: https://aur.archlinux.org/register

2. Add your SSH key to AUR:
   - Generate key: `ssh-keygen -t ed25519 -C "your-email@example.com"`
   - Log in to AUR website → Account Settings → SSH Key → paste your public key

3. On an Arch Linux machine (or in a Docker container), generate the `.SRCINFO`:
   ```bash
   # Copy PKGBUILD from your project
   cp /path/to/madcounter/aur/PKGBUILD .

   # Update the sha256sum with the actual value:
   # Download the source archive and run:
   # sha256sum madcounter-1.0.0.tar.gz
   # Replace 'SKIP' in PKGBUILD with the real hash

   # Generate .SRCINFO (required by AUR)
   makepkg --printsrcinfo > .SRCINFO
   ```

4. Push to AUR:
   ```bash
   git clone ssh://aur@aur.archlinux.org/madcounter.git
   cp PKGBUILD .SRCINFO madcounter/
   cd madcounter
   git add PKGBUILD .SRCINFO
   git commit -m "Initial AUR submission v1.0.0"
   git push
   ```

5. Users install with:
   ```bash
   yay -S madcounter    # using yay AUR helper
   # or
   paru -S madcounter   # using paru AUR helper
   ```

**WHY:** Arch Linux has millions of developer users, and AUR is their primary way to install software not in the official repos. Supporting AUR gives you reach into a very technically sophisticated audience.

---

## Step 6: Update curl Installer URL in README

After completing Steps 3-4:

1. Edit `scripts/install-binary.sh` and replace `ervardaan` with your actual username
2. Push the update to GitHub
3. Test the installer yourself:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/madcounter/main/scripts/install-binary.sh | bash
   ```

This one-liner works on **any Linux distribution and macOS** without needing a package manager.

---

## Step 7: Submit to Official Package Managers (Optional, Long-Term Goal)

These steps take more time but give you the widest reach:

### Debian/Ubuntu Official Repos
1. Create a Launchpad account: https://launchpad.net
2. Create a PPA (Personal Package Archive)
3. Upload: `debuild -S` then `dput ppa:YOUR_ID/madcounter ...`
4. Users can then: `sudo add-apt-repository ppa:YOUR_ID/madcounter && sudo apt install madcounter`

### Homebrew Core (No Tap Required)
After 30+ days on your tap with 75+ unique installs per month, submit a PR to `homebrew/homebrew-core`. This makes `brew install madcounter` work without adding a tap first.

### Official Arch repos
After your AUR package has been used for a while, a Trusted User on Arch may move it to the official `community` repository.

---

## Quick Reference: Distribution Channels Summary

| Channel | Audience | Command | Status |
|---------|----------|---------|--------|
| GitHub Releases | All users | Manual download | Ready after Step 3 |
| curl installer | All Linux/macOS | `curl ... \| bash` | Ready after Steps 3+6 |
| Homebrew Tap | macOS users | `brew install tap/madcounter` | Ready after Step 4 |
| AUR | Arch Linux | `yay -S madcounter` | Ready after Step 5 |
| Homebrew Core | All macOS | `brew install madcounter` | Long-term goal |
| apt/PPAs | Ubuntu/Debian | `sudo apt install madcounter` | Long-term goal |

---

## Files Created for Distribution

```
.github/
├── workflows/
│   ├── ci.yml              ← Runs tests on every push (green checkmark)
│   └── release.yml         ← Auto-compiles and publishes releases on git tag

homebrew/
└── madcounter.rb           ← Copy this to your homebrew-tap repo

aur/
└── PKGBUILD                ← Submit this to AUR

debian/
└── debian/
    ├── control             ← Package metadata
    ├── rules               ← Build instructions
    └── changelog           ← Version history

scripts/
└── install-binary.sh      ← The curl | bash installer
```
