#!/bin/bash
#
# Update script for the Ducktape homebrew formula
# This script updates the version and SHA256 hash in the formula 
# and reinstalls the production version
#
# Usage: ./update-prod.sh

set -e

# Colors for better output
GREEN="\033[0;32m"
BLUE="\033[0;34m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
NC="\033[0m" # No Color

# Check required commands
function check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed. Please install $1 and try again.${NC}"
        exit 1
    fi
}

check_command curl
check_command shasum
check_command brew

echo -e "${BLUE}Updating Ducktape Production Version...${NC}"

# 1. Get the current version from ducktape.rb
if [ ! -f "ducktape.rb" ]; then
    echo -e "${RED}Error: ducktape.rb file not found in current directory.${NC}"
    exit 1
fi

CURRENT_VERSION=$(grep -m 1 'version "' ducktape.rb | sed 's/version "//g' | sed 's/"//g')
echo -e "${BLUE}Current version in formula: ${YELLOW}${CURRENT_VERSION}${NC}"

# Ask if user wants to update the version
read -p "Do you want to update the version? (y/n): " UPDATE_VERSION

if [[ $UPDATE_VERSION == "y" || $UPDATE_VERSION == "Y" ]]; then
    read -p "Enter new version (format x.y.z): " NEW_VERSION
    
    # Validate version format
    if ! [[ $NEW_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Error: Invalid version format. Please use x.y.z format (e.g., 1.2.3).${NC}"
        exit 1
    fi
    
    # Update version in the formula file
    sed -i '' "s/version \"${CURRENT_VERSION}\"/version \"${NEW_VERSION}\"/g" ducktape.rb
    
    echo -e "${BLUE}Updated formula version to: ${YELLOW}${NEW_VERSION}${NC}"
    
    # Automatically calculate the SHA256 for the new version
    echo -e "${BLUE}Calculating SHA256 hash for release tarball v${NEW_VERSION}...${NC}"
    
    # Download the tarball and calculate its SHA256 hash
    TARBALL_URL="https://github.com/DuckTapeAI/ducktape/archive/refs/tags/v${NEW_VERSION}.tar.gz"
    echo -e "${BLUE}Downloading tarball from: ${YELLOW}${TARBALL_URL}${NC}"
    
    # Try to download and calculate hash with timeout
    NEW_SHA=""
    if curl --output /dev/null --silent --head --fail --max-time 10 "${TARBALL_URL}"; then
        NEW_SHA=$(curl -sL --max-time 30 "${TARBALL_URL}" | shasum -a 256 | cut -d ' ' -f 1)
    fi
    
    if [ -z "$NEW_SHA" ]; then
        echo -e "${RED}Error: Failed to calculate SHA256 hash. The release tarball may not exist yet.${NC}"
        echo -e "${YELLOW}Please ensure you've created the release on GitHub before running this script.${NC}"
        echo -e "${YELLOW}Or manually enter the SHA256 hash if you have it:${NC}"
        read -p "Enter SHA256 hash (leave blank to abort): " MANUAL_SHA
        
        if [ -z "$MANUAL_SHA" ]; then
            echo -e "${RED}Aborting version update.${NC}"
            exit 1
        else
            NEW_SHA="$MANUAL_SHA"
        fi
    fi
    
    echo -e "${BLUE}New SHA256 hash: ${YELLOW}${NEW_SHA}${NC}"
    
    # Update SHA in the formula file
    CURRENT_SHA=$(grep -m 1 'sha256 "' ducktape.rb | sed 's/sha256 "//g' | sed 's/"//g')
    sed -i '' "s/sha256 \"${CURRENT_SHA}\"/sha256 \"${NEW_SHA}\"/g" ducktape.rb
    
    echo -e "${GREEN}Successfully updated SHA256 hash in formula.${NC}"
fi

# Backup current installation state
if brew list ducktape-dev &>/dev/null; then
    DEV_VERSION_ACTIVE=true
    echo -e "${BLUE}Found development version installed.${NC}"
else
    DEV_VERSION_ACTIVE=false
fi

# Check if the ducktape production formula is already installed
if brew list ducktape &>/dev/null; then
    echo -e "${BLUE}Unlinking development version if active...${NC}"
    brew unlink ducktape-dev &>/dev/null || true
    
    echo -e "${BLUE}Reinstalling production version...${NC}"
    brew reinstall --build-from-source Formula/ducktape.rb
else
    echo -e "${BLUE}Installing production version for the first time...${NC}"
    brew install --build-from-source Formula/ducktape.rb
fi

echo -e "${BLUE}Ensuring production version is linked...${NC}"
brew link ducktape

# Print version to confirm
echo -e "${GREEN}Successfully updated to production version:${NC}"
ducktape --version

echo -e "${BLUE}Production version is now active.${NC}"
echo -e "${BLUE}Run 'ducktape' to use the production build.${NC}"

# Restore development version if it was active before
if [ "$DEV_VERSION_ACTIVE" = true ]; then
    echo -e "${YELLOW}Note: Development version was previously installed.${NC}"
    echo -e "${YELLOW}To switch back to development version, run: brew unlink ducktape && brew link ducktape-dev${NC}"
fi

# Remind about committing changes if version was updated
if [[ $UPDATE_VERSION == "y" || $UPDATE_VERSION == "Y" ]]; then
    echo -e "${YELLOW}Don't forget to commit and push the updated formula:${NC}"
    echo -e "${YELLOW}git add Formula/ducktape.rb${NC}"
    echo -e "${YELLOW}git commit -m \"Update to v${NEW_VERSION}\"${NC}"
    echo -e "${YELLOW}git push${NC}"
fi