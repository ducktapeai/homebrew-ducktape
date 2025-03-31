#!/bin/bash
set -e

# Colors for better output
GREEN="\033[0;32m"
BLUE="\033[0;34m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
NC="\033[0m" # No Color

echo -e "${BLUE}Updating Ducktape Development Version...${NC}"

# Check if the ducktape-dev formula exists
if [ ! -f "Formula/ducktape-dev.rb" ]; then
    echo -e "${RED}Error: Formula/ducktape-dev.rb not found.${NC}"
    exit 1
fi

echo -e "${BLUE}Ensuring development repository is up to date...${NC}"
(cd /Users/shaunstuart/RustroverProjects/ducktape && git fetch)

# Check if there are code changes in the development repository
echo -e "${BLUE}Checking for local changes in development repository...${NC}"
REPO_STATUS=$(cd /Users/shaunstuart/RustroverProjects/ducktape && git status --porcelain)
if [ -n "$REPO_STATUS" ]; then
    echo -e "${YELLOW}Warning: You have uncommitted changes in your development repository.${NC}"
    echo -e "${YELLOW}These changes will be included in your development build.${NC}"
fi

# Check if the ducktape dev formula is already installed
if brew list ducktape-dev &>/dev/null; then
    echo -e "${BLUE}Unlinking production version if active...${NC}"
    brew unlink ducktape &>/dev/null || true
    
    echo -e "${BLUE}Reinstalling development version from current source...${NC}"
    brew reinstall --build-from-source Formula/ducktape-dev.rb
else
    echo -e "${BLUE}Installing development version for the first time...${NC}"
    brew install --build-from-source Formula/ducktape-dev.rb
fi

echo -e "${BLUE}Ensuring development version is linked...${NC}"
brew link ducktape-dev

# Print version to confirm
echo -e "${GREEN}Successfully updated to development version:${NC}"
ducktape version

echo -e "${BLUE}Development version is now active.${NC}"
echo -e "${BLUE}Run 'ducktape' to use your local development build.${NC}"

# Show development branch information
CURRENT_BRANCH=$(cd /Users/shaunstuart/RustroverProjects/ducktape && git branch --show-current)
echo -e "${YELLOW}Currently on branch: ${CURRENT_BRANCH}${NC}"
echo -e "${YELLOW}To switch branches:${NC}"
echo -e "${YELLOW}cd /Users/shaunstuart/RustroverProjects/ducktape${NC}"
echo -e "${YELLOW}git checkout <branch-name>${NC}"
echo -e "${YELLOW}Then run this script again to build from that branch.${NC}"