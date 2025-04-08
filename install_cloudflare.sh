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
