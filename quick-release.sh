#!/bin/bash
# quick-release.sh - Quick script to create a new Ducktape release with build steps skipped
#
# This script is a simple wrapper around full-release-process.sh that automatically
# skips the build and test steps, useful when Cargo is not available.
#
# Usage: ./quick-release.sh <version> "<changelog message>" [OPTIONS]
#   e.g.: ./quick-release.sh 0.13.6 "Fixed input handling in notes module"

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

FULL_RELEASE_SCRIPT="./full-release-process.sh"

# Check if full release script exists
if [ ! -f "$FULL_RELEASE_SCRIPT" ]; then
    echo -e "${RED}Error: full-release-process.sh not found${RESET}"
    echo -e "${YELLOW}Please ensure you're running this script from the correct directory${RESET}"
    exit 1
fi

# Make sure the script is executable
chmod +x "$FULL_RELEASE_SCRIPT"

# Validate arguments
if [[ "$#" -lt 2 ]]; then
    echo -e "${RED}Error: Insufficient arguments${RESET}"
    echo "Usage: ./quick-release.sh <version> \"<changelog message>\" [OPTIONS]"
    echo "For more information, run: ./full-release-process.sh --help"
    exit 1
fi

VERSION="$1"
MESSAGE="$2"
shift 2  # Remove the first two arguments

# Validate version format
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Invalid version format. Must be X.Y.Z (e.g., 0.13.6)${RESET}"
    exit 1
fi

# Check if we need to clean the CHANGELOG first
echo -e "${YELLOW}Checking CHANGELOG.md for duplicate entries...${RESET}"
DUCKTAPE_PATH="/Users/shaunstuart/RustroverProjects/ducktape"
CHANGELOG_PATH="$DUCKTAPE_PATH/CHANGELOG.md"

if [ -f "$CHANGELOG_PATH" ]; then
    VERSION_COUNT=$(grep -c "## \[$VERSION\]" "$CHANGELOG_PATH")
    
    if [ "$VERSION_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}Warning: Version $VERSION already exists in CHANGELOG.md ($VERSION_COUNT occurrences)${RESET}"
        
        if [ -f "./fix-changelog.sh" ]; then
            read -p "Would you like to run fix-changelog.sh to clean up duplicates? (y/n): " fix_choice
            if [[ "$fix_choice" =~ ^[Yy]$ ]]; then
                chmod +x ./fix-changelog.sh
                ./fix-changelog.sh "$CHANGELOG_PATH"
            fi
        else
            echo -e "${YELLOW}fix-changelog.sh not found. You may want to manually clean your CHANGELOG.${RESET}"
            read -p "Continue anyway? (y/n): " continue_choice
            if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}Release aborted${RESET}"
                exit 0
            fi
        fi
    fi
fi

# Execute the full release script with --skip-build flag
echo -e "${BLUE}=======================================================${RESET}"
echo -e "${BLUE}Ducktape Quick Release - Version $VERSION${RESET}"
echo -e "${BLUE}=======================================================${RESET}"
echo -e "${YELLOW}Running with --skip-build flag and other provided options${RESET}"
echo -e "${YELLOW}Command: $FULL_RELEASE_SCRIPT \"$VERSION\" \"$MESSAGE\" --skip-build $*${RESET}"

# Ask for confirmation before running
read -p "Continue with this release? (y/n): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Release aborted${RESET}"
    exit 0
fi

# Run the release script
$FULL_RELEASE_SCRIPT "$VERSION" "$MESSAGE" --skip-build "$@"
