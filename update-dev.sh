#!/bin/bash
#
# Development version update script for the Ducktape homebrew formula
# This script rebuilds the development version from your local repository
# and reinstalls it through homebrew
#
# Usage: ./update-dev.sh

set -e

# Colors for better output
GREEN="\033[0;32m"
BLUE="\033[0;34m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
NC="\033[0m" # No Color

# Define repository path
REPO_PATH="/Users/shaunstuart/RustroverProjects/ducktape"
FORMULA_PATH="Formula/ducktape-dev.rb"

# Check required commands
function check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed. Please install $1 and try again.${NC}"
        exit 1
    fi
}

check_command brew
check_command git
check_command grep
check_command sed

echo -e "${BLUE}Updating Ducktape Development Version...${NC}"

# Check if the ducktape-dev formula exists
if [ ! -f "$FORMULA_PATH" ]; then
    echo -e "${RED}Error: $FORMULA_PATH not found.${NC}"
    exit 1
fi

# Check if the development repository exists
if [ ! -d "$REPO_PATH" ]; then
    echo -e "${RED}Error: Development repository not found at $REPO_PATH.${NC}"
    exit 1
fi

# Get the current version from Cargo.toml in the repository
if [ -f "${REPO_PATH}/Cargo.toml" ]; then
    CARGO_VERSION=$(grep -m 1 'version = ' "${REPO_PATH}/Cargo.toml" | sed 's/version = "//g' | sed 's/"//g')
    echo -e "${BLUE}Current version in Cargo.toml: ${YELLOW}${CARGO_VERSION}${NC}"
    
    # Get the current version from the dev formula
    FORMULA_VERSION=$(grep -m 1 'version "' "$FORMULA_PATH" | sed 's/version "//g' | sed 's/"//g')
    echo -e "${BLUE}Current version in formula: ${YELLOW}${FORMULA_VERSION}${NC}"
    
    # Check if versions are different
    if [ "$CARGO_VERSION" != "$FORMULA_VERSION" ]; then
        echo -e "${YELLOW}Warning: Version mismatch between Cargo.toml (${CARGO_VERSION}) and formula (${FORMULA_VERSION}).${NC}"
        read -p "Do you want to update the formula version to match Cargo.toml? (y/n): " UPDATE_VERSION
        
        if [[ $UPDATE_VERSION == "y" || $UPDATE_VERSION == "Y" ]]; then
            sed -i '' "s/version \"${FORMULA_VERSION}\"/version \"${CARGO_VERSION}\"/g" "$FORMULA_PATH"
            if [ $? -ne 0 ]; then
                echo -e "${RED}Error: Failed to update version in formula. Check file permissions.${NC}"
                exit 1
            fi
            echo -e "${BLUE}Updated version in formula to: ${YELLOW}${CARGO_VERSION}${NC}"
        fi
    fi
fi

echo -e "${BLUE}Ensuring development repository is up to date...${NC}"
(cd "$REPO_PATH" && git fetch)

# Check if there are code changes in the development repository
echo -e "${BLUE}Checking for local changes in development repository...${NC}"
REPO_STATUS=$(cd "$REPO_PATH" && git status --porcelain)
if [ -n "$REPO_STATUS" ]; then
    echo -e "${YELLOW}Warning: You have uncommitted changes in your development repository.${NC}"
    echo -e "${YELLOW}These changes will be included in your development build.${NC}"
    
    # Show a summary of changes
    echo -e "${YELLOW}Summary of changes:${NC}"
    cd "$REPO_PATH" && git status -s
    
    # Ask if user wants to continue
    read -p "Do you want to continue with uncommitted changes? (y/n): " CONTINUE_WITH_CHANGES
    if [[ $CONTINUE_WITH_CHANGES != "y" && $CONTINUE_WITH_CHANGES != "Y" ]]; then
        echo -e "${RED}Aborting development version update.${NC}"
        exit 1
    fi
fi

# Backup current installation state
if brew list ducktape &>/dev/null; then
    PROD_VERSION_ACTIVE=true
    PROD_VERSION=$(brew list ducktape --versions | awk '{print $2}')
    echo -e "${BLUE}Found production version ${PROD_VERSION} installed.${NC}"
else
    PROD_VERSION_ACTIVE=false
fi

# Check if the ducktape dev formula is already installed
if brew list ducktape-dev &>/dev/null; then
    echo -e "${BLUE}Unlinking production version if active...${NC}"
    brew unlink ducktape &>/dev/null || true
    
    echo -e "${BLUE}Reinstalling development version from current source...${NC}"
    brew reinstall --build-from-source "$FORMULA_PATH"
else
    echo -e "${BLUE}Installing development version for the first time...${NC}"
    brew install --build-from-source "$FORMULA_PATH"
fi

echo -e "${BLUE}Ensuring development version is linked...${NC}"
brew link ducktape-dev

# Print version to confirm
echo -e "${GREEN}Successfully updated to development version:${NC}"
ducktape version || ducktape --version  # Try both version command formats

# Show development branch information
CURRENT_BRANCH=$(cd "$REPO_PATH" && git branch --show-current)
CURRENT_COMMIT=$(cd "$REPO_PATH" && git rev-parse --short HEAD)
echo -e "${BLUE}Development version is now active from:${NC}"
echo -e "${BLUE}- Branch: ${GREEN}${CURRENT_BRANCH}${NC}"
echo -e "${BLUE}- Commit: ${GREEN}${CURRENT_COMMIT}${NC}"
echo -e "${BLUE}Run 'ducktape' to use your local development build.${NC}"

# Restore production version info if it was active before
if [ "$PROD_VERSION_ACTIVE" = true ]; then
    echo -e "${YELLOW}Note: Production version ${PROD_VERSION} is also installed.${NC}"
    echo -e "${YELLOW}To switch back to production version, run: brew unlink ducktape-dev && brew link ducktape${NC}"
fi

# Show helpful branch switching information
echo -e "\n${GREEN}Development Workflow Tips:${NC}"
echo -e "${YELLOW}1. To switch branches:${NC}"
echo -e "   cd $REPO_PATH"
echo -e "   git checkout <branch-name>"
echo -e "   ./update-dev.sh"
echo -e "${YELLOW}2. After making code changes:${NC}"
echo -e "   cd $REPO_PATH"
echo -e "   cargo fmt"
echo -e "   cargo clippy"
echo -e "   cargo test"
echo -e "   ./update-dev.sh"
echo -e "${YELLOW}3. Follow Ducktape coding standards for commits:${NC}"
echo -e "   - Use descriptive branch names with prefixes (feature/, bugfix/, etc.)"
echo -e "   - Write clear commit messages"
echo -e "   - Reference issue numbers when applicable"