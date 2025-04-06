#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Error: This script should not be run as root/sudo${NC}"
    echo -e "Please run without sudo: ./update-public-brew.sh"
    exit 1
fi

# Ensure Homebrew environment is properly set
eval "$(/opt/homebrew/bin/brew shellenv)"

# Uninstall any existing ducktape installations
echo -e "${BLUE}Checking for existing ducktape installations...${NC}"

# Check for public tap version
if brew list ducktapeai/ducktape/ducktape &>/dev/null; then
    echo -e "${YELLOW}Uninstalling public tap version...${NC}"
    brew uninstall ducktapeai/ducktape/ducktape
fi

# Check for local formula version
if brew list --formula | grep -q "^ducktape$"; then
    echo -e "${YELLOW}Uninstalling local formula version...${NC}"
    brew uninstall ducktape
fi

echo -e "${BLUE}Updating Ducktape formula...${NC}"

# Get current version from the formula
CURRENT_VERSION=$(grep -m 1 'version "' Formula/ducktape.rb | sed 's/version "//g' | sed 's/"//g')
echo -e "${BLUE}Current version in formula: ${YELLOW}${CURRENT_VERSION}${NC}"

NEW_VERSION="0.11.0"
echo -e "${BLUE}Setting new version to: ${YELLOW}${NEW_VERSION}${NC}"

# Calculate SHA256 for the GitHub tarball
SHA256=$(curl -sL "https://github.com/ducktapeai/ducktape/archive/refs/tags/v${NEW_VERSION}.tar.gz" | shasum -a 256 | cut -d' ' -f1)

# Update the formula
cat > Formula/ducktape.rb << EOL
class Ducktape < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
  homepage "https://github.com/ducktapeai/ducktape"
  url "https://github.com/ducktapeai/ducktape/archive/refs/tags/v${NEW_VERSION}.tar.gz"
  version "${NEW_VERSION}"
  sha256 "${SHA256}"
  license "MIT"

  depends_on "rust" => :build

  def install
    system "cargo", "install", "--root", prefix, "--path", "."
    
    # Generate shell completions
    output = Utils.safe_popen_read(bin/"ducktape", "completions")
    (bash_completion/"ducktape").write output
    (zsh_completion/"_ducktape").write output
    (fish_completion/"ducktape.fish").write output
    
    man1.install "man/ducktape.1" if File.exist?("man/ducktape.1")
  end

  test do
    assert_match version.to_s, shell_output("\#{bin}/ducktape --version")
    system "\#{bin}/ducktape", "calendar", "list"
  end
end
EOL

echo -e "${GREEN}Successfully updated formula to version ${NEW_VERSION}${NC}"
echo -e "${BLUE}To install the new version, run:${NC}"
echo -e "${YELLOW}brew install --build-from-source Formula/ducktape.rb${NC}"
