#!/bin/bash
# fix-changelog.sh - Script to clean up and fix the CHANGELOG.md file
#
# This script helps clean up the CHANGELOG.md file by:
# 1. Removing duplicate version entries
# 2. Organizing entries in descending version order
# 3. Fixing version comparison links
#
# Usage: ./fix-changelog.sh [path/to/CHANGELOG.md]

set -e  # Exit on any error

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Default path if not specified
DEFAULT_PATH="/Users/shaunstuart/RustroverProjects/ducktape/CHANGELOG.md"
CHANGELOG_PATH="${1:-$DEFAULT_PATH}"

if [ ! -f "$CHANGELOG_PATH" ]; then
    echo -e "${RED}Error: CHANGELOG.md file not found at $CHANGELOG_PATH${RESET}"
    echo "Usage: ./fix-changelog.sh [path/to/CHANGELOG.md]"
    exit 1
fi

echo -e "${BLUE}=======================================================${RESET}"
echo -e "${BLUE}CHANGELOG.md Cleanup Utility${RESET}"
echo -e "${BLUE}=======================================================${RESET}"

# Create a backup of the original file
BACKUP_FILE="${CHANGELOG_PATH}.bak.$(date +%Y%m%d%H%M%S)"
cp "$CHANGELOG_PATH" "$BACKUP_FILE"
echo -e "${GREEN}Created backup at $BACKUP_FILE${RESET}"

# Create temporary files for processing
TEMP_FILE=$(mktemp)
PROCESSED_FILE=$(mktemp)
SORTED_FILE=$(mktemp)
FINAL_FILE=$(mktemp)

cleanup() {
    # Clean up temporary files
    rm -f "$TEMP_FILE" "$PROCESSED_FILE" "$SORTED_FILE" "$FINAL_FILE"
    echo -e "${YELLOW}Temporary files cleaned up${RESET}"
}

# Set up trap to ensure cleanup on exit
trap cleanup EXIT

# Extract header part (everything before first version entry)
echo -e "${YELLOW}Extracting document header...${RESET}"
awk '/^## \[[0-9]/{exit} {print}' "$CHANGELOG_PATH" > "$TEMP_FILE"

# Find all version entries
echo -e "${YELLOW}Finding all version entries...${RESET}"
VERSIONS=$(grep -E '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' "$CHANGELOG_PATH" | 
           sed -E 's/^## \[([0-9]+\.[0-9]+\.[0-9]+)\].*/\1/' | 
           sort -t. -k1,1nr -k2,2nr -k3,3nr | 
           uniq)

echo -e "${GREEN}Found $(echo "$VERSIONS" | wc -l | xargs) unique versions${RESET}"

# Add header to final file
cat "$TEMP_FILE" > "$FINAL_FILE"

# Add unreleased section if it doesn't exist in the header
if ! grep -q "## \[Unreleased\]" "$TEMP_FILE"; then
    echo -e "\n## [Unreleased]\n### Added\n- (Add new features here)\n\n### Changed\n- (Add non-breaking changes here)\n\n### Fixed\n- (Add bug fixes here)\n" >> "$FINAL_FILE"
    echo -e "${GREEN}Added missing [Unreleased] section${RESET}"
fi

# Process each version in order
for version in $VERSIONS; do
    echo -e "${YELLOW}Processing version $version...${RESET}"
    
    # Find the first occurrence of this version's entry
    sed -n "/## \[$version\]/,/## \[/p" "$CHANGELOG_PATH" | sed '$d' > "$TEMP_FILE"
    
    # Extract the date for this version
    DATE=$(grep -E "## \[$version\]" "$TEMP_FILE" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}" || echo "YYYY-MM-DD")
    
    # If no date found, use today's date
    if [ "$DATE" = "YYYY-MM-DD" ]; then
        DATE=$(date +"%Y-%m-%d")
        echo -e "${YELLOW}No date found for version $version, using today's date: $DATE${RESET}"
        
        # Fix the header line to include the date
        sed -i '' "s/## \[$version\].*/## [$version] - $DATE/" "$TEMP_FILE"
    fi
    
    # Append to final file
    cat "$TEMP_FILE" >> "$FINAL_FILE"
    echo -e "\n" >> "$FINAL_FILE"
done

# Generate version comparison links at the bottom
echo -e "${YELLOW}Generating version comparison links...${RESET}"
echo -e "\n# Version Links\n" >> "$FINAL_FILE"

# Add unreleased link (comparing HEAD to latest version)
LATEST_VERSION=$(echo "$VERSIONS" | head -n 1)
if [ -n "$LATEST_VERSION" ]; then
    echo "[unreleased]: https://github.com/ducktapeai/ducktape/compare/v${LATEST_VERSION}...HEAD" >> "$FINAL_FILE"
fi

# Add links for each version comparing to previous
PREV_VERSION=""
for version in $VERSIONS; do
    if [ -n "$PREV_VERSION" ]; then
        echo "[$PREV_VERSION]: https://github.com/ducktapeai/ducktape/compare/v${version}...v${PREV_VERSION}" >> "$FINAL_FILE"
    fi
    PREV_VERSION="$version"
done

# Add link for first version
if [ -n "$PREV_VERSION" ]; then
    # Last version gets a release tag link instead of compare
    echo "[$PREV_VERSION]: https://github.com/ducktapeai/ducktape/releases/tag/v${PREV_VERSION}" >> "$FINAL_FILE"
fi

# Apply the changes
mv "$FINAL_FILE" "$CHANGELOG_PATH"

echo -e "${GREEN}CHANGELOG.md has been cleaned up and reformatted!${RESET}"
echo -e "${GREEN}Original file backed up at: $BACKUP_FILE${RESET}"
echo -e "${YELLOW}Please review the changes to ensure everything is correct.${RESET}"
