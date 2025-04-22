#!/bin/bash
# create-release.sh - Simplified script to create a new Ducktape release
#
# This script provides a more user-friendly interface to create releases
# by guiding the user through a series of prompts.
#
# Usage: ./create-release.sh

set -e  # Exit on any error

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

FULL_RELEASE_SCRIPT="./full-release-process.sh"

echo -e "${BLUE}=======================================================${RESET}"
echo -e "${BLUE}Ducktape Interactive Release Creator${RESET}"
echo -e "${BLUE}=======================================================${RESET}"

# Check if full release script exists
if [ ! -f "$FULL_RELEASE_SCRIPT" ]; then
    echo -e "${RED}Error: full-release-process.sh not found${RESET}"
    echo -e "${YELLOW}Please ensure you're running this script from the correct directory${RESET}"
    exit 1
fi

# Make sure the script is executable
chmod +x "$FULL_RELEASE_SCRIPT"

# Check for required tools early to avoid wasting time on configuration
echo -e "\n${YELLOW}Checking for required tools...${RESET}"

# Check for Git
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: git is not installed or not in PATH${RESET}"
    exit 1
else
    echo -e "${GREEN}Git: OK${RESET}"
fi

# Check for Rust/Cargo and automatically set skip build if not available
SKIP_BUILD_DEFAULT="n"
if ! command -v cargo &> /dev/null; then
    echo -e "${YELLOW}Warning: cargo is not installed or not in PATH${RESET}"
    echo -e "${YELLOW}Build steps will be automatically skipped${RESET}"
    SKIP_BUILD_DEFAULT="y"
else
    echo -e "${GREEN}Cargo: OK${RESET}"
fi

# Check for shasum
if ! command -v shasum &> /dev/null; then
    echo -e "${RED}Error: shasum is not installed or not in PATH${RESET}"
    exit 1
else
    echo -e "${GREEN}shasum: OK${RESET}"
fi

# Check for brew
if ! command -v brew &> /dev/null; then
    echo -e "${RED}Error: brew is not installed or not in PATH${RESET}"
    exit 1
else
    echo -e "${GREEN}brew: OK${RESET}"
fi

# Get the current version from the formula file
FORMULA_PATH="./Formula/ducktape.rb"
if [ -f "$FORMULA_PATH" ]; then
    CURRENT_VERSION=$(grep -E 'version "[^"]+"' "$FORMULA_PATH" | sed 's/^.*version "\(.*\)".*$/\1/')
    echo -e "${YELLOW}Current version in formula: $CURRENT_VERSION${RESET}"
    
    # Parse current version components
    IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"
    
    # Calculate suggested next versions
    PATCH_BUMP="${major}.${minor}.$((patch+1))"
    MINOR_BUMP="${major}.$((minor+1)).0"
    MAJOR_BUMP="$((major+1)).0.0"
    
    echo -e "Suggested versions:"
    echo -e "  1) Patch: ${GREEN}$PATCH_BUMP${RESET} (bug fixes)"
    echo -e "  2) Minor: ${GREEN}$MINOR_BUMP${RESET} (new features)"
    echo -e "  3) Major: ${GREEN}$MAJOR_BUMP${RESET} (breaking changes)"
    echo -e "  4) Custom version"
    
    # Get user choice
    read -p "Select version type [1-4]: " version_choice
    
    case $version_choice in
        1) NEW_VERSION="$PATCH_BUMP" ;;
        2) NEW_VERSION="$MINOR_BUMP" ;;
        3) NEW_VERSION="$MAJOR_BUMP" ;;
        4) 
            read -p "Enter custom version (format X.Y.Z): " NEW_VERSION
            # Validate custom version format
            if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo -e "${RED}Invalid version format. Must be X.Y.Z${RESET}"
                exit 1
            fi
            ;;
        *) 
            echo -e "${RED}Invalid selection${RESET}"
            exit 1
            ;;
    esac
else
    # Formula file not found, ask for version
    read -p "Enter version (format X.Y.Z): " NEW_VERSION
    
    # Validate version format
    if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Invalid version format. Must be X.Y.Z${RESET}"
        exit 1
    fi
fi

echo -e "\n${YELLOW}Change Type:${RESET}"
echo "  1) fixed  - Bug fixes"
echo "  2) added  - New features"
echo "  3) changed - Non-breaking changes"
echo "  4) deprecated - Soon-to-be removed features"
echo "  5) removed - Removed features"
echo "  6) security - Security fixes"

read -p "Select change type [1-6]: " change_choice

case $change_choice in
    1) CHANGE_TYPE="fixed" ;;
    2) CHANGE_TYPE="added" ;;
    3) CHANGE_TYPE="changed" ;;
    4) CHANGE_TYPE="deprecated" ;;
    5) CHANGE_TYPE="removed" ;;
    6) CHANGE_TYPE="security" ;;
    *) 
        echo -e "${RED}Invalid selection${RESET}"
        exit 1
        ;;
esac

# Get changelog message
echo -e "\n${YELLOW}Enter changelog message:${RESET}"
read -p "> " CHANGELOG_MESSAGE

# Confirm details
echo -e "\n${BLUE}Release Summary:${RESET}"
echo -e "  Version: ${GREEN}$NEW_VERSION${RESET}"
echo -e "  Type: ${GREEN}$CHANGE_TYPE${RESET}"
echo -e "  Message: ${GREEN}$CHANGELOG_MESSAGE${RESET}"

read -p "Continue with release? (y/n): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Release aborted${RESET}"
    exit 0
fi

# Ask about build options
echo -e "\n${YELLOW}Build Options:${RESET}"
if [ "$SKIP_BUILD_DEFAULT" = "y" ]; then
    echo -e "${YELLOW}Build will be skipped because cargo is not available${RESET}"
    SKIP_BUILD_FLAG="--skip-build"
else
    read -p "Skip build and test steps? (y/n) [${SKIP_BUILD_DEFAULT}]: " skip_build
    skip_build=${skip_build:-$SKIP_BUILD_DEFAULT}
    if [[ "$skip_build" =~ ^[Yy]$ ]]; then
        SKIP_BUILD_FLAG="--skip-build"
    else
        SKIP_BUILD_FLAG=""
    fi
fi

read -p "Skip test check? (y/n) [n]: " skip_test
skip_test=${skip_test:-"n"}
if [[ "$skip_test" =~ ^[Yy]$ ]]; then
    SKIP_TEST_FLAG="--skip-test-check"
else
    SKIP_TEST_FLAG=""
fi

read -p "GitHub wait seconds (default 10): " wait_seconds
if [[ -z "$wait_seconds" ]]; then
    WAIT_SECONDS_FLAG=""
else
    WAIT_SECONDS_FLAG="--wait=$wait_seconds"
fi

# Check for duplicate version
echo -e "\n${YELLOW}Checking for duplicate version in CHANGELOG.md...${RESET}"
DUCKTAPE_PATH="/Users/shaunstuart/RustroverProjects/ducktape"
CHANGELOG_PATH="$DUCKTAPE_PATH/CHANGELOG.md"
VERSION_COUNT=0

if [ -f "$CHANGELOG_PATH" ]; then
    VERSION_COUNT=$(grep -c "## \[$NEW_VERSION\]" "$CHANGELOG_PATH")
    
    if [ "$VERSION_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}Warning: Version $NEW_VERSION already exists in CHANGELOG.md${RESET}"
        echo -e "${YELLOW}Found $VERSION_COUNT occurrences.${RESET}"
        
        read -p "Do you want to fix duplicate entries before continuing? (y/n): " fix_duplicates
        
        if [[ "$fix_duplicates" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}To fix duplicate entries, you can:${RESET}"
            echo -e "1. Edit CHANGELOG.md manually to remove duplicates"
            echo -e "2. Use the fix-changelog.sh script if available"
            
            read -p "Press enter to continue after fixing the CHANGELOG, or Ctrl+C to abort..."
        fi
    else
        echo -e "${GREEN}No duplicate versions found. Proceeding...${RESET}"
    fi
else
    echo -e "${YELLOW}CHANGELOG.md not found at $CHANGELOG_PATH${RESET}"
    echo -e "${YELLOW}Skipping duplicate version check${RESET}"
fi

# Execute the full release process
echo -e "\n${GREEN}Starting release process...${RESET}"
echo -e "${YELLOW}Running: $FULL_RELEASE_SCRIPT \"$NEW_VERSION\" \"$CHANGELOG_MESSAGE\" --type=\"$CHANGE_TYPE\" $SKIP_BUILD_FLAG $SKIP_TEST_FLAG $WAIT_SECONDS_FLAG${RESET}"

# Add a confirmation before executing
read -p "Press enter to continue or Ctrl+C to abort..."

$FULL_RELEASE_SCRIPT "$NEW_VERSION" "$CHANGELOG_MESSAGE" --type="$CHANGE_TYPE" $SKIP_BUILD_FLAG $SKIP_TEST_FLAG $WAIT_SECONDS_FLAG
