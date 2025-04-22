#!/bin/bash
# update-version.sh - Simple script to update the version in Cargo.toml
#
# This script updates the version field in the Cargo.toml file to the specified version.
# It helps resolve issues with the full release process when the version needs to be updated.
#
# Usage: ./update-version.sh <new-version>
#   e.g.: ./update-version.sh 0.13.6

set -e  # Exit on any error

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Check if a version was provided
if [ $# -ne 1 ]; then
    echo -e "${RED}Error: Please specify a version number${RESET}"
    echo "Usage: $0 <new-version>"
    echo "Example: $0 0.13.6"
    exit 1
fi

NEW_VERSION="$1"

# Validate the version format
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Error: Invalid version format. Must be in the format X.Y.Z${RESET}"
    exit 1
fi

# Path to Cargo.toml file
DUCKTAPE_PATH="/Users/shaunstuart/RustroverProjects/ducktape"
CARGO_TOML="$DUCKTAPE_PATH/Cargo.toml"

# Check if Cargo.toml exists
if [ ! -f "$CARGO_TOML" ]; then
    echo -e "${RED}Error: Cargo.toml file not found at $CARGO_TOML${RESET}"
    exit 1
fi

echo -e "${BLUE}Updating version in Cargo.toml to $NEW_VERSION${RESET}"

# Create a backup
cp "$CARGO_TOML" "$CARGO_TOML.bak"
echo -e "${GREEN}Created backup: $CARGO_TOML.bak${RESET}"

# Read the current version
CURRENT_VERSION=$(grep -E "^version = \"[0-9]+\.[0-9]+\.[0-9]+\"" "$CARGO_TOML" | sed 's/^version = "\(.*\)".*$/\1/')
echo -e "${YELLOW}Current version: $CURRENT_VERSION${RESET}"

# Update the version in Cargo.toml
sed -i '' "s/^version = \"$CURRENT_VERSION\"/version = \"$NEW_VERSION\"/" "$CARGO_TOML"

# Verify the change
NEW_VERSION_CHECK=$(grep -E "^version = \"[0-9]+\.[0-9]+\.[0-9]+\"" "$CARGO_TOML" | sed 's/^version = "\(.*\)".*$/\1/')
if [ "$NEW_VERSION_CHECK" = "$NEW_VERSION" ]; then
    echo -e "${GREEN}Successfully updated version from $CURRENT_VERSION to $NEW_VERSION${RESET}"
else
    echo -e "${RED}Failed to update version. Current value: $NEW_VERSION_CHECK${RESET}"
    echo -e "${YELLOW}Restoring from backup...${RESET}"
    cp "$CARGO_TOML.bak" "$CARGO_TOML"
    exit 1
fi

echo -e "\n${BLUE}Next steps:${RESET}"
echo -e "1. Run the following command to perform the release:"
echo -e "   ${GREEN}./quick-release.sh $NEW_VERSION \"Your changelog message\" --skip-build${RESET}"
echo -e "2. Or run the full release script directly:"
echo -e "   ${GREEN}./full-release-process.sh $NEW_VERSION \"Your changelog message\" --skip-build${RESET}"
