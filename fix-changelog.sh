#!/bin/bash
# fix-changelog.sh - Script to clean up and fix the CHANGELOG.md file
#
# This script helps clean up the CHANGELOG.md file by:
# 1. Removing duplicate version entries
# 2. Organizing entries in descending version order
# 3. Fixing version comparison links
#
# Usage: ./fix-changelog.sh /path/to/CHANGELOG.md

set -e  # Exit on any error

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Default path if not specified
CHANGELOG_PATH="${1:-../ducktape/CHANGELOG.md}"

if [ ! -f "$CHANGELOG_PATH" ]; then
    echo -e "${RED}Error: CHANGELOG.md file not found at $CHANGELOG_PATH${RESET}"
    echo "Usage: ./fix-changelog.sh /path/to/CHANGELOG.md"
    exit 1
fi

echo -e "${BLUE}=======================================================${RESET}"
echo -e "${BLUE}CHANGELOG.md Cleanup Utility${RESET}"
echo -e "${BLUE}=======================================================${RESET}"

# Create a backup of the original file
BACKUP_FILE="${CHANGELOG_PATH}.bak"
cp "$CHANGELOG_PATH" "$BACKUP_FILE"
echo -e "${GREEN}Created backup at $BACKUP_FILE${RESET}"

# Create a temporary file for processing
TEMP_FILE="/tmp/changelog_temp.md"
PROCESSED_FILE="/tmp/changelog_processed.md"
SORTED_FILE="/tmp/changelog_sorted.md"
FINAL_FILE="/tmp/changelog_final.md"

# Extract header part (everything before first version entry)
echo -e "${YELLOW}Extracting document header...${RESET}"
awk '/^## \[[0-9]/{exit} {print}' "$CHANGELOG_PATH" > "$TEMP_FILE"

# Extract all version blocks and remove duplicates
echo -e "${YELLOW}Processing version entries and removing duplicates...${RESET}"
grep -n "^## \[" "$CHANGELOG_PATH" | sort -t: -k2 -u | sort -t: -k1n | cut -d: -f2- > "$PROCESSED_FILE"

# Sort versions semantically (most recent first)
echo -e "${YELLOW}Sorting versions semantically...${RESET}"
grep "^## \[" "$PROCESSED_FILE" | 
    sed -E 's/^## \[([0-9]+\.[0-9]+\.[0-9]+)\].*/\1/' | 
    sort -t. -k1,1nr -k2,2nr -k3,3nr > "$SORTED_FILE"

# Create the new CHANGELOG.md with sorted versions
echo -e "${YELLOW}Reconstructing CHANGELOG.md with sorted versions...${RESET}"
cp "$TEMP_FILE" "$FINAL_FILE"

# Add unreleased section if it doesn't exist
if ! grep -q "## \[Unreleased\]" "$FINAL_FILE"; then
    echo -e "\n## [Unreleased]\n### Added\n- (Add new features here)\n\n### Changed\n- (Add non-breaking changes here)\n\n### Fixed\n- (Add bug fixes here)\n" >> "$FINAL_FILE"
    echo -e "${GREEN}Added missing [Unreleased] section${RESET}"
fi

# Process each version in order
declare -a versions
declare -a dates
while read version; do
    echo -e "${YELLOW}Processing version $version...${RESET}"
    
    # Extract the date for this version
    date=$(grep -A1 "## \[$version\]" "$CHANGELOG_PATH" | grep -Eo "[0-9]{4}-[0-9]{2}-[0-9]{2}" | head -1)
    
    # Store version and date for later use in links
    versions+=("$version")
    dates+=("$date")
    
    # Find content for this version and append it to the final file
    sed -n "/## \[$version\]/,/## \[/p" "$CHANGELOG_PATH" | sed '$d' >> "$FINAL_FILE"
    echo -e "\n" >> "$FINAL_FILE"
done < "$SORTED_FILE"

# Generate version comparison links at the bottom
echo -e "${YELLOW}Generating version comparison links...${RESET}"
echo -e "\n# Version Links\n" >> "$FINAL_FILE"

# Add unreleased link (comparing HEAD to latest version)
if [ ${#versions[@]} -gt 0 ]; then
    echo "[unreleased]: https://github.com/ducktapeai/ducktape/compare/v${versions[0]}...HEAD" >> "$FINAL_FILE"
fi

# Add links for each version comparing to previous
for ((i=0; i<${#versions[@]}-1; i++)); do
    echo "[${versions[i]}]: https://github.com/ducktapeai/ducktape/compare/v${versions[i+1]}...v${versions[i]}" >> "$FINAL_FILE"
done

# Add link for first version
if [ ${#versions[@]} -gt 0 ]; then
    # Last version gets a release tag link instead of compare
    last_idx=$((${#versions[@]}-1))
    echo "[${versions[$last_idx]}]: https://github.com/ducktapeai/ducktape/releases/tag/v${versions[$last_idx]}" >> "$FINAL_FILE"
fi

# Apply the changes
mv "$FINAL_FILE" "$CHANGELOG_PATH"

echo -e "${GREEN}CHANGELOG.md has been cleaned up and reformatted!${RESET}"
echo -e "${GREEN}Original file backed up at: $BACKUP_FILE${RESET}"
echo -e "${YELLOW}Please review the changes to ensure everything is correct.${RESET}"

# Cleanup temporary files
rm -f "$TEMP_FILE" "$PROCESSED_FILE" "$SORTED_FILE"
