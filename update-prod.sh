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
check_command grep
check_command sed

echo -e "${BLUE}Updating Ducktape Production Version...${NC}"

# Define formula paths
MAIN_FORMULA="ducktape.rb"
FORMULA_DIR_PATH="Formula/ducktape.rb"

# Check if formulas exist
if [[ ! -f "$MAIN_FORMULA" || ! -f "$FORMULA_DIR_PATH" ]]; then
    echo -e "${RED}Error: Formula files not found. Please ensure you're in the homebrew-ducktape directory.${NC}"
    exit 1
fi

# 1. Get the current version from ducktape.rb
CURRENT_VERSION=$(grep -m 1 'version "' "$MAIN_FORMULA" | sed 's/version "//g' | sed 's/"//g')
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
    
    # Update version in both formula files
    for formula in "$MAIN_FORMULA" "$FORMULA_DIR_PATH"; do
        sed -i '' "s/version \"${CURRENT_VERSION}\"/version \"${NEW_VERSION}\"/g" "$formula"
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error: Failed to update version in $formula. Check file permissions.${NC}"
            exit 1
        fi
        echo -e "${BLUE}Updated version in $formula to: ${YELLOW}${NEW_VERSION}${NC}"
    done
    
    # Automatically calculate the SHA256 for the new version
    echo -e "${BLUE}Calculating SHA256 hash for release tarball v${NEW_VERSION}...${NC}"
    
    # Define GitHub release URL and temp file
    TARBALL_URL="https://github.com/DuckTapeAI/ducktape/archive/refs/tags/v${NEW_VERSION}.tar.gz"
    TEMP_TARBALL="/tmp/ducktape-v${NEW_VERSION}.tar.gz"
    
    echo -e "${BLUE}Downloading tarball from: ${YELLOW}${TARBALL_URL}${NC}"
    
    # Try to download the tarball with proper error handling
    if curl -L --fail --silent --show-error --max-time 30 -o "$TEMP_TARBALL" "$TARBALL_URL"; then
        # Calculate SHA256 hash from downloaded file for added security
        NEW_SHA=$(shasum -a 256 "$TEMP_TARBALL" | cut -d ' ' -f 1)
        
        if [ -z "$NEW_SHA" ]; then
            echo -e "${RED}Error: Failed to calculate SHA256 hash.${NC}"
            exit 1
        fi
        
        echo -e "${BLUE}Successfully downloaded tarball and calculated SHA256 hash.${NC}"
        echo -e "${BLUE}SHA256: ${YELLOW}${NEW_SHA}${NC}"
        
        # Clean up temp file
        rm -f "$TEMP_TARBALL"
    else
        echo -e "${RED}Error: Failed to download the release tarball.${NC}"
        echo -e "${YELLOW}Please ensure you've created the v${NEW_VERSION} release on GitHub before running this script.${NC}"
        
        # Offer manual SHA input option
        echo -e "${YELLOW}Would you like to enter the SHA256 hash manually? (y/n)${NC}"
        read -p "> " MANUAL_SHA_OPTION
        
        if [[ $MANUAL_SHA_OPTION == "y" || $MANUAL_SHA_OPTION == "Y" ]]; then
            read -p "Enter SHA256 hash: " MANUAL_SHA
            
            # Simple validation of SHA256 format
            if ! [[ $MANUAL_SHA =~ ^[0-9a-f]{64}$ ]]; then
                echo -e "${RED}Error: Invalid SHA256 hash format. It should be a 64-character hexadecimal string.${NC}"
                exit 1
            fi
            
            NEW_SHA="$MANUAL_SHA"
        else
            echo -e "${RED}Aborting version update.${NC}"
            exit 1
        fi
    fi
    
    # Update SHA in both formula files
    CURRENT_SHA=$(grep -m 1 'sha256 "' "$MAIN_FORMULA" | sed 's/sha256 "//g' | sed 's/"//g')
    
    for formula in "$MAIN_FORMULA" "$FORMULA_DIR_PATH"; do
        sed -i '' "s/sha256 \"${CURRENT_SHA}\"/sha256 \"${NEW_SHA}\"/g" "$formula"
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error: Failed to update SHA256 hash in $formula. Check file permissions.${NC}"
            exit 1
        fi
        echo -e "${GREEN}Successfully updated SHA256 hash in $formula.${NC}"
    done
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
ducktape version || ducktape --version  # Try both version command formats

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
    echo -e "${YELLOW}git add ducktape.rb Formula/ducktape.rb${NC}"
    echo -e "${YELLOW}git commit -m \"Update formulas to v${NEW_VERSION}\"${NC}"
    echo -e "${YELLOW}git push${NC}"
fi