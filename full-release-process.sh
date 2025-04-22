#!/bin/bash
# full-release-process.sh - Automates the Ducktape release and Homebrew update process
# 
# This script handles the entire release process for Ducktape:
# 1. Bumps version in Cargo.toml
# 2. Updates CHANGELOG.md with release notes
# 3. Builds and tests the project
# 4. Creates a Git tag for the release
# 5. Pushes changes to GitHub
# 6. Creates a release tarball
# 7. Updates the Homebrew formula with the new version and SHA
# 8. Pushes the formula update to GitHub
#
# Usage: ./full-release-process.sh <version> "<changelog message>"
#   e.g.: ./full-release-process.sh 0.13.5 "Fixed input handling in notes module"

set -e  # Exit on any error

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Required paths
DUCKTAPE_PATH="/Users/shaunstuart/RustroverProjects/ducktape"
HOMEBREW_PATH="/Users/shaunstuart/RustroverProjects/homebrew-ducktape"
FORMULA_PATH="$HOMEBREW_PATH/Formula/ducktape.rb"

# Validate arguments
if [ "$#" -lt 2 ]; then
    echo -e "${RED}Error: Insufficient arguments${RESET}"
    echo "Usage: ./full-release-process.sh <version> \"<changelog message>\""
    echo "Example: ./full-release-process.sh 0.13.5 \"Fixed input handling in notes module\""
    exit 1
fi

NEW_VERSION="$1"
CHANGELOG_MESSAGE="$2"
CURRENT_DATE=$(date +"%Y-%m-%d")
RELEASE_TARBALL="$DUCKTAPE_PATH/../ducktape-$NEW_VERSION.tar.gz"

echo -e "${BLUE}=======================================================${RESET}"
echo -e "${BLUE}Ducktape Release Process - Version $NEW_VERSION${RESET}"
echo -e "${BLUE}=======================================================${RESET}"

# Step 1: Check that we're on main branch in both repositories
echo -e "\n${YELLOW}Checking git branch status...${RESET}"
cd "$DUCKTAPE_PATH"
DUCKTAPE_BRANCH=$(git branch --show-current)
if [ "$DUCKTAPE_BRANCH" != "main" ]; then
    echo -e "${RED}Error: Not on main branch in ducktape repository${RESET}"
    exit 1
fi

cd "$HOMEBREW_PATH"
HOMEBREW_BRANCH=$(git branch --show-current)
if [ "$HOMEBREW_BRANCH" != "main" ]; then
    echo -e "${RED}Error: Not on main branch in homebrew-ducktape repository${RESET}"
    exit 1
fi

# Step 2: Check for uncommitted changes
echo -e "\n${YELLOW}Checking for uncommitted changes...${RESET}"
cd "$DUCKTAPE_PATH"
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${RED}Error: There are uncommitted changes in ducktape repository${RESET}"
    git status
    exit 1
fi

cd "$HOMEBREW_PATH"
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${RED}Error: There are uncommitted changes in homebrew-ducktape repository${RESET}"
    git status
    exit 1
fi

# Step 3: Pull latest changes
echo -e "\n${YELLOW}Pulling latest changes from remote repositories...${RESET}"
cd "$DUCKTAPE_PATH"
git pull
cd "$HOMEBREW_PATH"
git pull

# Step 4: Update version in Cargo.toml
echo -e "\n${YELLOW}Updating version in Cargo.toml to $NEW_VERSION${RESET}"
cd "$DUCKTAPE_PATH"
sed -i '' "s/^version = \".*\"/version = \"$NEW_VERSION\"/" Cargo.toml

# Step 5: Update CHANGELOG.md
echo -e "\n${YELLOW}Updating CHANGELOG.md${RESET}"
cd "$DUCKTAPE_PATH"
CHANGELOG_ENTRY="## [$NEW_VERSION] - $CURRENT_DATE\n### Fixed\n- $CHANGELOG_MESSAGE\n\n"
sed -i '' "1s/^/$CHANGELOG_ENTRY/" CHANGELOG.md

# Step 6: Build and test the project
echo -e "\n${YELLOW}Building and testing the project...${RESET}"
cd "$DUCKTAPE_PATH"
cargo build --release
cargo test --release -- --nocapture

# Step 7: Commit the version bump and changelog
echo -e "\n${YELLOW}Committing version bump and changelog update...${RESET}"
cd "$DUCKTAPE_PATH"
git add Cargo.toml Cargo.lock CHANGELOG.md
git commit -m "Bump version to $NEW_VERSION: $CHANGELOG_MESSAGE"

# Step 8: Create a git tag
echo -e "\n${YELLOW}Creating git tag v$NEW_VERSION...${RESET}"
cd "$DUCKTAPE_PATH"
git tag -a "v$NEW_VERSION" -m "Release $NEW_VERSION: $CHANGELOG_MESSAGE"

# Step 9: Push the changes and tags
echo -e "\n${YELLOW}Pushing changes and tags to GitHub...${RESET}"
cd "$DUCKTAPE_PATH"
git push
git push --tags

# Step 10: Create a tarball
echo -e "\n${YELLOW}Creating release tarball...${RESET}"
cd "$DUCKTAPE_PATH"
git archive --format=tar.gz --prefix="ducktape-$NEW_VERSION/" "v$NEW_VERSION" > "$RELEASE_TARBALL"
SHA256=$(shasum -a 256 "$RELEASE_TARBALL" | awk '{print $1}')
echo -e "${GREEN}Tarball created: $RELEASE_TARBALL${RESET}"
echo -e "${GREEN}SHA256: $SHA256${RESET}"

# Step 11: Update Homebrew formula
echo -e "\n${YELLOW}Updating Homebrew formula...${RESET}"
cd "$HOMEBREW_PATH"
sed -i '' "s/url \".*\"/url \"https:\/\/github.com\/ducktapeai\/ducktape\/archive\/v$NEW_VERSION.tar.gz\"/" "$FORMULA_PATH"
sed -i '' "s/version \".*\"/version \"$NEW_VERSION\"/" "$FORMULA_PATH"
sed -i '' "s/sha256 \".*\"/sha256 \"$SHA256\"/" "$FORMULA_PATH"

# Step 12: Commit and push Homebrew formula changes
echo -e "\n${YELLOW}Committing and pushing Homebrew formula changes...${RESET}"
cd "$HOMEBREW_PATH"
git add "$FORMULA_PATH"
git commit -m "Update ducktape formula to version $NEW_VERSION"
git push

# Step 13: Verify the formula works
echo -e "\n${YELLOW}Testing Homebrew formula with 'brew audit'...${RESET}"
brew audit --strict "$FORMULA_PATH"
echo -e "\n${YELLOW}Testing Homebrew formula with 'brew install --build-from-source'...${RESET}"
brew install --build-from-source "$FORMULA_PATH"

# Step 14: All done!
echo -e "\n${GREEN}=========================================================${RESET}"
echo -e "${GREEN}Release process completed successfully!${RESET}"
echo -e "${GREEN}Version $NEW_VERSION has been released and Homebrew formula updated.${RESET}"
echo -e "${GREEN}=========================================================${RESET}"
echo -e "${YELLOW}Don't forget to:${RESET}"
echo -e "  - Check the GitHub repository to ensure the tag was created"
echo -e "  - Verify that 'brew upgrade ducktape' works for users"
echo -e "  - Update the website documentation if needed"
echo -e "  - Announce the release to your users"