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
if git tag -l "v$NEW_VERSION" | grep -q "v$NEW_VERSION"; then
    echo -e "${YELLOW}Warning: Tag v$NEW_VERSION already exists${RESET}"
    read -p "Do you want to continue with the existing tag? (y/n): " continue_with_tag
    if [[ ! "$continue_with_tag" =~ ^[Yy]$ ]]; then
        read -p "Do you want to force update the tag? (y/n): " force_tag
        if [[ "$force_tag" =~ ^[Yy]$ ]]; then
            git tag -d "v$NEW_VERSION"
            git tag -a "v$NEW_VERSION" -m "Release $NEW_VERSION: $CHANGELOG_MESSAGE"
            echo -e "${GREEN}Tag v$NEW_VERSION force-updated${RESET}"
        else
            echo -e "${RED}Release process aborted due to tag conflict${RESET}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Continuing with existing tag v$NEW_VERSION${RESET}"
    fi
else
    git tag -a "v$NEW_VERSION" -m "Release $NEW_VERSION: $CHANGELOG_MESSAGE"
    echo -e "${GREEN}Tag v$NEW_VERSION created${RESET}"
fi

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

# Step 10: Create a tarball and verify SHA256 with GitHub
echo -e "\n${YELLOW}Creating release tarball...${RESET}"
cd "$DUCKTAPE_PATH"
git archive --format=tar.gz --prefix="ducktape-$NEW_VERSION/" "v$NEW_VERSION" > "$RELEASE_TARBALL"
GENERATED_SHA256=$(shasum -a 256 "$RELEASE_TARBALL" | awk '{print $1}')
echo -e "${GREEN}Tarball created: $RELEASE_TARBALL${RESET}"
echo -e "${GREEN}Generated SHA256: $GENERATED_SHA256${RESET}"

# Clean homebrew cache and download the GitHub release to ensure we get the real SHA256
echo -e "\n${YELLOW}Cleaning Homebrew cache and downloading GitHub release to verify SHA256...${RESET}"
GITHUB_TARBALL="/tmp/ducktape-github-$NEW_VERSION.tar.gz"
GITHUB_URL="https://github.com/ducktapeai/ducktape/archive/v$NEW_VERSION.tar.gz"

# Clear the cached file if it exists
HOMEBREW_CACHE_PATH="$HOME/Library/Caches/Homebrew/downloads"
CACHED_FILES=$(find "$HOMEBREW_CACHE_PATH" -name "*ducktape-$NEW_VERSION.tar.gz*" 2>/dev/null)
if [[ -n "$CACHED_FILES" ]]; then
    echo -e "${YELLOW}Found cached Homebrew files that may cause SHA mismatch:${RESET}"
    echo "$CACHED_FILES"
    read -p "Do you want to remove these cached files? (y/n): " remove_cache
    if [[ "$remove_cache" =~ ^[Yy]$ ]]; then
        for file in $CACHED_FILES; do
            rm -f "$file"
            echo -e "${GREEN}Removed: $file${RESET}"
        done
    fi
fi

# Perform a fresh download from GitHub
if curl -L -s "$GITHUB_URL" -o "$GITHUB_TARBALL"; then
    GITHUB_SHA256=$(shasum -a 256 "$GITHUB_TARBALL" | awk '{print $1}')
    echo -e "${GREEN}GitHub SHA256: $GITHUB_SHA256${RESET}"
    
    # Always use the GitHub SHA for the formula
    SHA256=$GITHUB_SHA256
    
    if [[ "$GENERATED_SHA256" != "$GITHUB_SHA256" ]]; then
        echo -e "${YELLOW}Warning: SHA256 mismatch between generated and GitHub tarball${RESET}"
        echo -e "${YELLOW}This is normal due to GitHub's tarball generation differing from git archive${RESET}"
        echo -e "${YELLOW}Using GitHub's SHA256 for the formula: $GITHUB_SHA256${RESET}"
    else
        echo -e "${GREEN}SHA256 checksum verification successful!${RESET}"
    fi
else
    echo -e "${RED}Error: Could not download GitHub tarball to verify SHA256${RESET}"
    echo -e "${YELLOW}Using locally generated SHA256 as fallback: $GENERATED_SHA256${RESET}"
    SHA256=$GENERATED_SHA256
fi
rm -f "$GITHUB_TARBALL"

# Step 11: Update Homebrew formula with the correct SHA
echo -e "\n${YELLOW}Updating Homebrew formula...${RESET}"
cd "$HOMEBREW_PATH"

# Extract current values from the formula
CURRENT_VERSION=$(grep -E 'version "[^"]+"' "$FORMULA_PATH" | sed 's/^.*version "\(.*\)".*$/\1/')
CURRENT_SHA=$(grep -E 'sha256 "[^"]+"' "$FORMULA_PATH" | sed 's/^.*sha256 "\(.*\)".*$/\1/')

# Print current values for verification
echo -e "${YELLOW}Current formula values: version=$CURRENT_VERSION, SHA=$CURRENT_SHA${RESET}"
echo -e "${YELLOW}New values to set: version=$NEW_VERSION, SHA=$SHA256${RESET}"

# Only update if there are actual changes
if [[ "$CURRENT_VERSION" != "$NEW_VERSION" || "$CURRENT_SHA" != "$SHA256" ]]; then
    # Use different delimiters to avoid URL path issues
    sed -i '' "s|url \".*\"|url \"https://github.com/ducktapeai/ducktape/archive/v$NEW_VERSION.tar.gz\"|" "$FORMULA_PATH"
    sed -i '' "s|version \".*\"|version \"$NEW_VERSION\"|" "$FORMULA_PATH"
    sed -i '' "s|sha256 \".*\"|sha256 \"$SHA256\"|" "$FORMULA_PATH"
    
    echo -e "${GREEN}Formula updated with new version and SHA${RESET}"
    
    # Step 12: Commit and push Homebrew formula changes
    echo -e "\n${YELLOW}Committing and pushing Homebrew formula changes...${RESET}"
    git add "$FORMULA_PATH"
    if git diff --staged --quiet; then
        echo -e "${YELLOW}No changes to commit. Formula is already up to date.${RESET}"
    else
        git commit -m "Update ducktape formula to version $NEW_VERSION"
        git push
        echo -e "${GREEN}Formula changes pushed to GitHub${RESET}"
    fi
else
    echo -e "${YELLOW}Formula already has the correct version ($NEW_VERSION) and SHA. No updates needed.${RESET}"
fi

# Step 13: Verify the formula works
echo -e "\n${YELLOW}Testing Homebrew formula with 'brew audit'...${RESET}"
FORMULA_NAME="ducktape"
if ! brew audit "$FORMULA_NAME"; then
    echo -e "${RED}Warning: Brew audit reported issues with the formula${RESET}"
    read -p "Continue despite brew audit warnings? (y/n): " continue_audit
    if [[ ! "$continue_audit" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Release process aborted due to brew audit issues${RESET}"
        exit 1
    fi
fi

echo -e "\n${YELLOW}Testing Homebrew formula with 'brew install --build-from-source'...${RESET}"
if ! brew install --build-from-source "$FORMULA_NAME"; then
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