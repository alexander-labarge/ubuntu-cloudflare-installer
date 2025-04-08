# Install Cloudflare WARP and Cloudflared on Ubuntu 24.04.2 LTS

This repository provides a single, self-contained Bash script that **safely** installs both [Cloudflare WARP](https://pkg.cloudflareclient.com/) and [Cloudflared](https://pkg.cloudflare.com/) using apt package management. It **automatically** detects your Ubuntu architecture and codename, then adds the correct Cloudflare repositories with `[arch=...]` constraints to avoid annoying multi-architecture errors.

---

## Why This Utility Is Necessary

- **Manual `.deb` downloads**: As of now, there is **no official out-of-the-box support** for Ubuntu 24.04 in Cloudflare’s default apt repositories. Users are forced to download `.deb` packages manually, which is not ideal for updates or security.
- **Multi-arch warnings**: By default, Ubuntu 24.04 LTS includes `i386` support (multi-arch). Cloudflare’s own instructions often omit `[arch=amd64]`, causing apt to look for non-existent i386 packages. This can produce irritating warnings and even build failures.
- **Automatic setup**: The script automatically detects:
  1. Your system’s architecture (`dpkg --print-architecture`)  
  2. Your Ubuntu codename (`lsb_release -cs`) – e.g. `jammy`, `noble`, etc.
- **Repository lines with `[arch=...]`**: The script inserts the correct `[arch=$ARCH]` constraints in your `/etc/apt/sources.list.d/` entries. That fixes the “Failed to fetch i386 packages” errors on multi-arch setups.
- **One-command solution**: This script handles everything in a single pass, including keyrings, repository configuration, and installing both `cloudflare-warp` and `cloudflared`. 

---

## Features

1. **Automatic Architecture Detection**  
   Reads your system architecture with:
   ```bash
   dpkg --print-architecture
   ```
   This ensures your Cloudflare repository lines match the actual architecture you’re running.

2. **Codename Auto-Detection**  
   Fetches your Ubuntu codename via:
   ```bash
   lsb_release -cs
   ```
   so you get the correct repository lines for your release (e.g., `jammy`, `noble`, etc.).

3. **Proper `[arch=...]` Constraints**  
   Each repository line is appended with `[arch=$ARCH]` to avoid multi-arch conflicts that lead to 404 errors and warnings about missing i386 packages.

4. **Colored Output**  
   Status messages are color-coded for clarity. Errors and success messages are clearly distinguished.

5. **Idempotent**  
   Re-running the script won’t break existing configurations. If you already have the keys and repos set up, the script will simply skip or re-check those steps.

---

## Usage

1. **Download the Script**

   ```bash
   curl -O https://raw.githubusercontent.com/alexander-labarge/ubuntu-cloudflare-installer/refs/heads/main/install_cloudflare.sh
   ```
   
   *(Or copy/paste the contents into a local file named `install_cloudflare.sh`.)*

2. **Make It Executable**

   ```bash
   chmod +x install_cloudflare.sh
   ```

3. **Run It with sudo**
   
   ```bash
   sudo ./install_cloudflare.sh
   ```

4. **Follow the Prompts**
   - The script will display your detected architecture and Ubuntu codename.
   - It will also show you the repository lines it intends to add to `/etc/apt/sources.list.d/`.
   - You’ll be asked to confirm before proceeding with the changes.

5. **Enjoy Cloudflare Tools!**  
   After the script finishes, you’ll have **cloudflared** and **cloudflare-warp** installed.  
   - Check with `cloudflared --version` and `warp-cli --version`.

---

## Script Contents

Below is the entire script for reference (you can also open it in any text editor):

```bash
#!/usr/bin/env bash
#
# install_cloudflare.sh
#
# This script safely installs Cloudflare’s WARP and cloudflared clients
# on Ubuntu 24.04 LTS (or any other Ubuntu version) using the official Cloudflare
# repositories, with colored output for better readability.
#
# 1) It automatically detects your architecture (dpkg --print-architecture)
# 2) Uses your Ubuntu codename (lsb_release -cs) – e.g. "jammy", "noble", etc.
# 3) Adds the appropriate Cloudflare repository lines *with* the [arch=...]
#    constraint to avoid 32-bit/i386 warnings.
# 4) Installs the "cloudflared" and "cloudflare-warp" packages.
#
# https://pkg.cloudflareclient.com/ - Cloudflare’s default WARP installer issue:
# ---------------------------------------------------------------------
# Cloudflare’s default WARP installer adds a repo line like:
#   deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ <codename> main
# But it does NOT specify [arch=amd64] or [arch=$(dpkg --print-architecture)].
# On multi-arch systems that include i386 (32-bit) support, Apt will attempt to
# fetch i386 packages from that repository – which do not exist. Hence the error.
# This is especially problematic on Ubuntu 24.04 LTS, which defaults to multi-arch.
# ---------------------------------------------------------------------

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
#  Colors
# ─────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
RESET='\033[0m'

# ─────────────────────────────────────────────────────────────────────────────
#  Check if the script is run as root
# ─────────────────────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}${BOLD}ERROR:${RESET} This script must be run as root. Please use sudo."
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
#  Check if the system is Ubuntu
# ─────────────────────────────────────────────────────────────────────────────
if ! grep -qi "ubuntu" /etc/os-release; then
  echo -e "${RED}${BOLD}ERROR:${RESET} This script is intended for Ubuntu systems only."
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
#  1) Detect Architecture and Ubuntu Codename
# ─────────────────────────────────────────────────────────────────────────────
ARCH="$(dpkg --print-architecture)"
CODENAME="$(lsb_release -cs)"

echo -e "${BLUE}Detected architecture:${RESET} ${GREEN}${BOLD}$ARCH${RESET}"
echo -e "${BLUE}Detected Ubuntu codename:${RESET} ${GREEN}${BOLD}$CODENAME${RESET}"

# ─────────────────────────────────────────────────────────────────────────────
#  2) Define GPG keys and repo lines for WARP and cloudflared
# ─────────────────────────────────────────────────────────────────────────────
WARP_GPG_KEY_URL="https://pkg.cloudflareclient.com/pubkey.gpg"
WARP_KEYRING_PATH="/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg"
WARP_REPO_LINE="deb [arch=${ARCH} signed-by=${WARP_KEYRING_PATH}] https://pkg.cloudflareclient.com/ ${CODENAME} main"

CLOUDFLARED_GPG_KEY_URL="https://pkg.cloudflare.com/cloudflare-main.gpg"
CLOUDFLARED_KEYRING_PATH="/usr/share/keyrings/cloudflare-main.gpg"
CLOUDFLARED_REPO_LINE="deb [arch=${ARCH} signed-by=${CLOUDFLARED_KEYRING_PATH}] https://pkg.cloudflare.com/cloudflared ${CODENAME} main"

# ─────────────────────────────────────────────────────────────────────────────
#  3) Preview the changes
# ─────────────────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}We will add the following entries to your apt sources:${RESET}"
echo
echo -e "${YELLOW}${BOLD}File: /etc/apt/sources.list.d/cloudflare-client.list${RESET}"
echo -e "${WARP_REPO_LINE}"
echo
echo -e "${YELLOW}${BOLD}File: /etc/apt/sources.list.d/cloudflared.list${RESET}"
echo -e "${CLOUDFLARED_REPO_LINE}"
echo

# ─────────────────────────────────────────────────────────────────────────────
#  4) User confirmation
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}Please confirm that you want to proceed with adding these repositories and installing the Cloudflare packages.${RESET}"
read -rp "Proceed with adding these repos and installing Cloudflare packages? [y/N] " RESPONSE

if [[ ! "$RESPONSE" =~ ^[Yy] ]]; then
  echo -e "${RED}Aborting installation.${RESET}"
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
#  5) Install GPG keys for WARP
# ─────────────────────────────────────────────────────────────────────────────
echo
echo -e "${BLUE}Downloading and installing Cloudflare WARP GPG key...${RESET}"
curl -fsSL "$WARP_GPG_KEY_URL" \
  | gpg --dearmor \
  | tee "$WARP_KEYRING_PATH" >/dev/null

# ─────────────────────────────────────────────────────────────────────────────
#  6) Write WARP repo file
# ─────────────────────────────────────────────────────────────────────────────
echo
echo -e "${BLUE}Adding WARP repo to /etc/apt/sources.list.d/cloudflare-client.list...${RESET}"
echo "$WARP_REPO_LINE" | tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null

# ─────────────────────────────────────────────────────────────────────────────
#  7) Install GPG keys for cloudflared
# ─────────────────────────────────────────────────────────────────────────────
echo
echo -e "${BLUE}Downloading and installing cloudflared GPG key...${RESET}"
curl -fsSL "$CLOUDFLARED_GPG_KEY_URL" \
  | gpg --dearmor \
  | tee "$CLOUDFLARED_KEYRING_PATH" >/dev/null

# ─────────────────────────────────────────────────────────────────────────────
#  8) Write cloudflared repo file
# ─────────────────────────────────────────────────────────────────────────────
echo
echo -e "${BLUE}Adding cloudflared repo to /etc/apt/sources.list.d/cloudflared.list...${RESET}"
echo "$CLOUDFLARED_REPO_LINE" | tee /etc/apt/sources.list.d/cloudflared.list >/dev/null

# ─────────────────────────────────────────────────────────────────────────────
#  9) Update apt and install
# ─────────────────────────────────────────────────────────────────────────────
echo
echo -e "${BLUE}Updating package lists...${RESET}"
apt-get update

echo
echo -e "${BLUE}Installing cloudflared...${RESET}"
apt-get install -y cloudflared

echo
echo -e "${BLUE}Installing cloudflare-warp...${RESET}"
apt-get install -y cloudflare-warp

echo
echo -e "${GREEN}${BOLD}Installation complete!${RESET}"
echo -e "You can now use ${BOLD}cloudflared${RESET} and/or ${BOLD}WARP${RESET} as needed."
```

---

## Important Notes

- **Root/Sudo Required**  
  Because this script modifies system repositories and installs system packages, you must run it as root (via `sudo` or logging in as root).

- **Multi-Arch Systems**  
  This script is particularly useful if you have `i386` enabled (common for gaming or WINE). Without `[arch=...]` constraints, apt complains about missing i386 Cloudflare packages.

- **Compatibility**  
  Although primarily tested on **Ubuntu 24.04.2 LTS**, this script should work on **other Ubuntu releases** as well. It dynamically uses your system’s actual codename.

- **No Affiliation**  
  This utility is neither provided nor endorsed by Cloudflare. Use at your own risk.

---

## Contributing

Pull requests, improvements, or feedback are always welcome. If you encounter issues, feel free to open an Issue or submit a fix.

---

## License

Distributed under the MIT License.