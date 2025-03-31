#!/bin/bash
set -e

# Colors for better output
GREEN="\033[0;32m"
BLUE="\033[0;34m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
NC="\033[0m" # No Color

echo -e "${BLUE}Updating Ducktape Production Version...${NC}"

# 1. Get the current version from ducktape.rb
CURRENT_VERSION=$(grep -m 1 'version "' ducktape.rb | sed 's/version "//g' | sed 's/"//g')
echo -e "${BLUE}Current version in formula: ${YELLOW}${CURRENT_VERSION}${NC}"

# Ask if user wants to update the version
read -p "Do you want to update the version? (y/n): " UPDATE_VERSION

if [[ $UPDATE_VERSION == "y" || $UPDATE_VERSION == "Y" ]]; then
    read -p "Enter new version (format x.y.z): " NEW_VERSION
    
    # Update version in the formula file
    sed -i '' "s/version \"${CURRENT_VERSION}\"/version \"${NEW_VERSION}\"/g" ducktape.rb
    
    echo -e "${BLUE}Updated formula version to: ${YELLOW}${NEW_VERSION}${NC}"
    
    # Automatically calculate the SHA256 for the new version
    echo -e "${BLUE}Calculating SHA256 hash for release tarball v${NEW_VERSION}...${NC}"
    
    # Check if curl exists
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}Error: curl is not installed. Please install curl and try again.${NC}"
        exit 1
    fi
    
    # Check if shasum exists
    if ! command -v shasum &> /dev/null; then
        echo -e "${RED}Error: shasum is not installed. Please install shasum and try again.${NC}"
        exit 1
    fi
    
    # Download the tarball and calculate its SHA256 hash
    TARBALL_URL="https://github.com/DuckTapeAI/ducktape/archive/refs/tags/v${NEW_VERSION}.tar.gz"
    echo -e "${BLUE}Downloading tarball from: ${YELLOW}${TARBALL_URL}${NC}"
    
    NEW_SHA=$(curl -sL "${TARBALL_URL}" | shasum -a 256 | cut -d ' ' -f 1)
    
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

# Check if the ducktape production formula is already installed
if brew list ducktape &>/dev/null; then
    echo -e "${BLUE}Unlinking development version if active...${NC}"
    brew unlink ducktape-dev &>/dev/null || true
    
    echo -e "${BLUE}Reinstalling production version...${NC}"
    brew reinstall --build-from-source ducktape.rb
else
    echo -e "${BLUE}Installing production version for the first time...${NC}"
    brew install --build-from-source ducktape.rb
fi

echo -e "${BLUE}Ensuring production version is linked...${NC}"
brew link ducktape

# Print version to confirm
echo -e "${GREEN}Successfully updated to production version:${NC}"
ducktape --version

echo -e "${BLUE}Production version is now active.${NC}"
echo -e "${BLUE}Run 'ducktape' to use the production build.${NC}"

# Remind about committing changes if version was updated
if [[ $UPDATE_VERSION == "y" || $UPDATE_VERSION == "Y" ]]; then
    echo -e "${YELLOW}Don't forget to commit and push the updated formula:${NC}"
    echo -e "${YELLOW}git add ducktape.rb${NC}"
    echo -e "${YELLOW}git commit -m \"Update to v${NEW_VERSION}\"${NC}"
    echo -e "${YELLOW}git push${NC}"
fi