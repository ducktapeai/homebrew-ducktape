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
# Usage: ./full-release-process.sh <version> "<changelog message>" [--skip-test-check]
#   e.g.: ./full-release-process.sh 0.13.5 "Fixed input handling in notes module"
#   e.g.: ./full-release-process.sh 0.13.5 "Fixed input handling in notes module" --skip-test-check

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

# Default settings
SKIP_TEST_CHECK=0

# Process flags
for arg in "$@"; do
    if [[ "$arg" == "--skip-test-check" ]]; then
        SKIP_TEST_CHECK=1
        break
    fi
done

# Validate arguments
if [[ "$#" -lt 2 ]]; then
    echo -e "${RED}Error: Insufficient arguments${RESET}"
    echo "Usage: ./full-release-process.sh <version> \"<changelog message>\" [--skip-test-check]"
    echo "Example: ./full-release-process.sh 0.13.5 \"Fixed input handling in notes module\""
    echo "Options:"
    echo "  --skip-test-check    Continue even if tests fail (will still prompt for confirmation)"
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
echo -e "\n${YELLOW}Running tests (this may take a few minutes)...${RESET}"

# Capture test output and status
TEST_OUTPUT=$(cargo test --release -- --nocapture 2>&1) || TEST_STATUS=$?

# Check if tests failed
if [[ -n "$TEST_STATUS" ]]; then
    echo -e "${RED}Tests failed with status code $TEST_STATUS${RESET}"
    echo -e "${YELLOW}Test output:${RESET}\n$TEST_OUTPUT\n"
    
    if [[ $SKIP_TEST_CHECK -eq 0 ]]; then
        # Ask user if they want to continue despite failed tests
        read -p "Do you want to continue with the release process anyway? (y/n): " continue_release
        if [[ ! "$continue_release" =~ ^[Yy]$ ]]; then
            echo -e "${RED}Release process aborted due to test failures${RESET}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Continuing despite test failures (--skip-test-check flag was set)${RESET}"
        read -p "Press Enter to continue or Ctrl+C to abort..."
    fi
else
    echo -e "${GREEN}All tests passed successfully!${RESET}"
fi

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

# Push tags with error handling for already existing tags
echo -e "\n${YELLOW}Pushing tags to GitHub...${RESET}"
if ! git push --tags 2> /tmp/git_push_error; then
    # Check if error is just about already existing tags
    if grep -q "rejected.*already exists" /tmp/git_push_error; then
        echo -e "${YELLOW}Warning: Some tags were rejected because they already exist in the remote.${RESET}"
        echo -e "${YELLOW}Only new tags were pushed. This is normal if you're re-running the release process.${RESET}"
        # Show which tag was successfully pushed (should be our new version)
        grep "new tag" /tmp/git_push_error | sed 's/^/  /'
        # Continue with the process despite this "error"
    else
        # If there was a different error, show it and ask to continue
        echo -e "${RED}Error pushing tags:${RESET}"
        cat /tmp/git_push_error
        read -p "Continue despite tag push errors? (y/n): " continue_tag_push
        if [[ ! "$continue_tag_push" =~ ^[Yy]$ ]]; then
            echo -e "${RED}Release process aborted due to tag push errors${RESET}"
            exit 1
        fi
    fi
else
    echo -e "${GREEN}Tags pushed successfully${RESET}"
fi
rm -f /tmp/git_push_error

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
if ! brew audit --strict "$FORMULA_PATH"; then
    echo -e "${RED}Warning: Brew audit reported issues with the formula${RESET}"
    read -p "Continue despite brew audit warnings? (y/n): " continue_audit
    if [[ ! "$continue_audit" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Release process aborted due to brew audit issues${RESET}"
        exit 1
    fi
fi

echo -e "\n${YELLOW}Testing Homebrew formula with 'brew install --build-from-source'...${RESET}"
if ! brew install --build-from-source "$FORMULA_PATH"; then
    echo -e "${RED}Error: Brew install failed!${RESET}"
    read -p "This is a critical error. Continue anyway? (y/n): " continue_install
    if [[ ! "$continue_install" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Release process aborted due to brew install failure${RESET}"
        exit 1
    fi
fi

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