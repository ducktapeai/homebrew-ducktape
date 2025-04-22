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
# Usage: ./full-release-process.sh <version> "<changelog message>" [--skip-test-check] [--skip-build]
#   e.g.: ./full-release-process.sh 0.13.5 "Fixed input handling in notes module"
#   e.g.: ./full-release-process.sh 0.13.5 "Fixed input handling in notes module" --skip-build

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
SKIP_BUILD=0

# Process flags
for arg in "$@"; do
    if [[ "$arg" == "--skip-test-check" ]]; then
        SKIP_TEST_CHECK=1
    fi
    if [[ "$arg" == "--skip-build" ]]; then
        SKIP_BUILD=1
    fi
done

# Validate arguments
if [[ "$#" -lt 2 ]]; then
    echo -e "${RED}Error: Insufficient arguments${RESET}"
    echo "Usage: ./full-release-process.sh <version> \"<changelog message>\" [--skip-test-check] [--skip-build]"
    echo "Example: ./full-release-process.sh 0.13.5 \"Fixed input handling in notes module\""
    echo "Options:"
    echo "  --skip-test-check    Continue even if tests fail (will still prompt for confirmation)"
    echo "  --skip-build         Skip the build and test steps (use when Cargo is not available)"
    exit 1
fi

NEW_VERSION="$1"
CHANGELOG_MESSAGE="$2"
CURRENT_DATE=$(date +"%Y-%m-%d")
RELEASE_TARBALL="$DUCKTAPE_PATH/../ducktape-$NEW_VERSION.tar.gz"

echo -e "${BLUE}=======================================================${RESET}"
echo -e "${BLUE}Ducktape Release Process - Version $NEW_VERSION${RESET}"
echo -e "${BLUE}=======================================================${RESET}"

# Check for required tools
check_prerequisites() {
    echo -e "\n${YELLOW}Checking for required tools...${RESET}"
    
    # Check for Git
    if ! command -v git &> /dev/null; then
        echo -e "${RED}Error: git is not installed or not in PATH${RESET}"
        exit 1
    else
        echo -e "${GREEN}Git: OK${RESET}"
    fi
    
    # Check for Rust/Cargo if build is not skipped
    if [[ $SKIP_BUILD -eq 0 ]]; then
        if ! command -v cargo &> /dev/null; then
            echo -e "${RED}Error: cargo is not installed or not in PATH${RESET}"
            echo -e "${YELLOW}You can use --skip-build flag to skip build and test steps${RESET}"
            exit 1
        else
            echo -e "${GREEN}Cargo: OK${RESET}"
        fi
    else
        echo -e "${YELLOW}Skipping Cargo check as --skip-build flag was provided${RESET}"
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
    
    echo -e "${GREEN}All required tools are available${RESET}"
}

# Run prerequisite check
check_prerequisites

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

# Step 6: Build and test the project (conditionally)
if [[ $SKIP_BUILD -eq 0 ]]; then
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
else
    echo -e "\n${YELLOW}Skipping build and test steps (--skip-build flag was set)${RESET}"
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

# Force clear all Homebrew cache files for this package
HOMEBREW_CACHE_PATH="$HOME/Library/Caches/Homebrew/downloads"
CACHED_FILES=$(find "$HOMEBREW_CACHE_PATH" -name "*ducktape*" 2>/dev/null)
if [[ -n "$CACHED_FILES" ]]; then
    echo -e "${YELLOW}Found cached Homebrew files that may cause SHA mismatch:${RESET}"
    echo "$CACHED_FILES"
    echo -e "${YELLOW}Removing all cached files for ducktape to ensure clean download${RESET}"
    
    for file in $CACHED_FILES; do
        rm -f "$file"
        echo -e "${GREEN}Removed: $file${RESET}"
    done
    
    # Also remove any temp files that might be interfering
    rm -f /tmp/ducktape*
    echo -e "${GREEN}Removed any temporary files${RESET}"
fi

# Thoroughly clean Homebrew cache
echo -e "${YELLOW}Running brew cleanup to ensure all caches are cleared...${RESET}"
brew cleanup -s
echo -e "${GREEN}Brew cleanup completed${RESET}"

# Wait a moment for GitHub to fully process the new tag
echo -e "${YELLOW}Waiting for GitHub to fully process the new tag (10 seconds)...${RESET}"
sleep 10

# Always get the SHA directly from GitHub's codeload URL for consistency
echo -e "${YELLOW}Downloading from direct codeload URL for reliable SHA256...${RESET}"
DIRECT_TARBALL="/tmp/ducktape-direct-$NEW_VERSION.tar.gz"
CODELOAD_URL="https://codeload.github.com/ducktapeai/ducktape/tar.gz/refs/tags/v$NEW_VERSION"
if curl -L -s -H "Cache-Control: no-cache" "$CODELOAD_URL" -o "$DIRECT_TARBALL"; then
    DIRECT_SHA256=$(shasum -a 256 "$DIRECT_TARBALL" | awk '{print $1}')
    echo -e "${GREEN}Direct download successful. SHA256: $DIRECT_SHA256${RESET}"
    SHA256=$DIRECT_SHA256
    
    # Save a copy for debugging if needed
    cp "$DIRECT_TARBALL" "/tmp/ducktape-$NEW_VERSION-github.tar.gz"
    echo -e "${GREEN}Saved GitHub tarball to /tmp/ducktape-$NEW_VERSION-github.tar.gz${RESET}"
else
    echo -e "${RED}Failed to download from GitHub. Using locally generated SHA256${RESET}"
    SHA256=$GENERATED_SHA256
fi

# Step 11: Update the Formula with correct SHA256 using direct file creation
echo -e "\n${YELLOW}Updating Homebrew formula with verified SHA256...${RESET}"
cd "$HOMEBREW_PATH"

# Create the formula file with the correct SHA256
echo -e "${GREEN}Creating formula with verified SHA256: $SHA256${RESET}"
cat > "$FORMULA_PATH" << EOF
class Ducktape < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
  homepage "https://github.com/ducktapeai/ducktape"
  url "https://github.com/ducktapeai/ducktape/archive/v$NEW_VERSION.tar.gz"
  version "$NEW_VERSION"
  sha256 "$SHA256"
  license "MIT"

  depends_on "rust" => :build

  def install
    system "cargo", "install", "--root", prefix, "--path", "."
    
    # Generate shell completions - with error handling
    begin
      output = Utils.safe_popen_read(bin/"ducktape", "completions")
      (bash_completion/"ducktape").write output
      (zsh_completion/"_ducktape").write output
      (fish_completion/"ducktape.fish").write output
    rescue => e
      opoo "Shell completions couldn't be generated: \#{e.message}"
      # Create minimal completions as fallback
      (bash_completion/"ducktape").write "# Fallback bash completions for ducktape\\n"
      (zsh_completion/"_ducktape").write "# Fallback zsh completions for ducktape\\n"
      (fish_completion/"ducktape.fish").write "# Fallback fish completions for ducktape\\n"
    end
    
    man1.install "man/ducktape.1" if File.exist?("man/ducktape.1")
  end

  test do
    assert_match version.to_s, shell_output("\#{bin}/ducktape --version")
    system "\#{bin}/ducktape", "calendar", "list"
  end
end
EOF

# Verify the formula was created correctly
echo -e "${YELLOW}Verifying formula was updated correctly...${RESET}"
FORMULA_SHA=$(grep -E 'sha256 "[^"]+"' "$FORMULA_PATH" | sed 's/^.*sha256 "\(.*\)".*$/\1/')
if [[ "$FORMULA_SHA" == "$SHA256" ]]; then
    echo -e "${GREEN}Formula SHA256 verification successful: $FORMULA_SHA${RESET}"
else
    echo -e "${RED}Error: Formula SHA256 doesn't match expected value!${RESET}"
    echo -e "${RED}Expected: $SHA256${RESET}"
    echo -e "${RED}Found: $FORMULA_SHA${RESET}"
    exit 1
fi

# Step 12: Commit and push the formula changes
echo -e "\n${YELLOW}Committing and pushing Homebrew formula changes...${RESET}"
git add "$FORMULA_PATH"
git commit -m "Update ducktape formula to version $NEW_VERSION with SHA256 $SHA256"
git push
echo -e "${GREEN}Formula changes pushed to GitHub${RESET}"

# Clean up temporary files
rm -f "$DIRECT_TARBALL"

# Step 13: Installing the formula
echo -e "\n${YELLOW}Installing the formula with brew install...${RESET}"

# Make sure we have the latest brew information
echo -e "${YELLOW}Running brew update to refresh taps...${RESET}"
brew update

# Uninstall any previous version to get a clean install
echo -e "${YELLOW}Uninstalling previous versions if present...${RESET}"
brew uninstall ducktape 2>/dev/null || true

# Explicitly tap our repository
echo -e "${YELLOW}Explicitly tapping the ducktapeai/ducktape repository...${RESET}"
brew untap ducktapeai/ducktape 2>/dev/null || true
brew tap ducktapeai/ducktape

# Force a full re-download to avoid any cached files issues
echo -e "${YELLOW}Installing formula from scratch (with build from source)...${RESET}"
brew fetch --force --build-from-source ducktapeai/ducktape/ducktape || {
    echo -e "${RED}Fetch failed. This could indicate SHA issues still exist.${RESET}"
    echo -e "${YELLOW}Let's try installing directly which might use the correct SHA from the freshly updated formula.${RESET}"
}

# Install with --verbose to see what's happening
if ! brew install --verbose ducktapeai/ducktape/ducktape; then
    echo -e "${RED}Error: Failed to install ducktape with standard install${RESET}"
    echo -e "${YELLOW}Trying installation with --build-from-source...${RESET}"
    
    if ! brew install --verbose --build-from-source ducktapeai/ducktape/ducktape; then
        echo -e "${RED}Error: Brew install failed even with build-from-source!${RESET}"
        echo -e "${RED}This suggests there may still be issues with the formula or Homebrew cache.${RESET}"
        echo -e "\n${YELLOW}Troubleshooting suggestions:${RESET}"
        echo -e "1. Run: brew doctor"
        echo -e "2. Run: brew cleanup --prune=all"
        echo -e "3. Manually check: ${FORMULA_PATH}"
        echo -e "4. Try manually: brew fetch --force ducktapeai/ducktape/ducktape"
        
        # Even though install failed, ask if they want to continue with the release process
        read -p "Continue with the release process despite installation failure? (y/n): " continue_install
        if [[ ! "$continue_install" =~ ^[Yy]$ ]]; then
            echo -e "${RED}Release process aborted due to installation failure${RESET}"
            exit 1
        fi
    else
        echo -e "${GREEN}Successfully installed ducktape with --build-from-source!${RESET}"
    fi
else
    echo -e "${GREEN}Successfully installed ducktape!${RESET}"
fi

# Step 14: Verify the installation
echo -e "\n${YELLOW}Verifying installation...${RESET}"
if command -v ducktape >/dev/null 2>&1; then
    VERSION_OUTPUT=$(ducktape --version)
    echo -e "${GREEN}ducktape command found: $VERSION_OUTPUT${RESET}"
    
    if [[ "$VERSION_OUTPUT" == *"$NEW_VERSION"* ]]; then
        echo -e "${GREEN}Version verification successful!${RESET}"
    else
        echo -e "${YELLOW}Warning: Installed version ($VERSION_OUTPUT) doesn't match expected version ($NEW_VERSION)${RESET}"
    fi
else
    echo -e "${RED}Warning: ducktape command not found in path after installation${RESET}"
    echo -e "${YELLOW}This could be due to:${RESET}"
    echo -e "1. Installation failure"
    echo -e "2. The binary not being properly linked"
    echo -e "3. Path issues in your environment"
    echo -e "\n${YELLOW}Try running: brew link --overwrite ducktape${RESET}"
fi

# Step 15: All done!
echo -e "\n${GREEN}=========================================================${RESET}"
echo -e "${GREEN}Release process completed!${RESET}"
echo -e "${GREEN}Version $NEW_VERSION has been released and Homebrew formula updated.${RESET}"
echo -e "${GREEN}=========================================================${RESET}"
echo -e "${YELLOW}Don't forget to:${RESET}"
echo -e "  - Check the GitHub repository to ensure the tag was created"
echo -e "  - Verify that 'brew upgrade ducktape' works for users"
echo -e "  - Update the website documentation if needed"
echo -e "  - Announce the release to your users"

# Step 16: Manual Installation Instructions
cat << EOF

${BLUE}=======================================================
  MANUAL INSTALLATION INSTRUCTIONS
=======================================================${RESET}

If the automatic installation did not work, you can install
ducktape manually using these steps:

1. First, ensure Homebrew is up to date:
   ${YELLOW}brew update${RESET}

2. Untap and re-tap the ducktape repository:
   ${YELLOW}brew untap ducktapeai/ducktape 2>/dev/null || true
   brew tap ducktapeai/ducktape${RESET}

3. Clear any cached downloads:
   ${YELLOW}rm -rf ~/Library/Caches/Homebrew/downloads/*ducktape*${RESET}

4. Install from source:
   ${YELLOW}brew install --build-from-source ducktapeai/ducktape/ducktape${RESET}

5. If you still have issues, try running:
   ${YELLOW}brew doctor${RESET}

EOF