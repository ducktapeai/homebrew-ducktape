#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Paths to repositories (adjust these if your paths differ)
DUCKTAPE_DIR="/Users/shaunstuart/RustroverProjects/ducktape"
HOMEBREW_DIR="/Users/shaunstuart/RustroverProjects/homebrew-ducktape"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Error: This script should not be run as root/sudo${NC}"
    echo -e "Please run without sudo: ./update-public-brew.sh"
    exit 1
fi

# Ensure required tools are installed
for cmd in git curl shasum brew gh; do
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${RED}Error: $cmd is required but not installed${NC}"
        exit 1
    fi
done

# Ensure Homebrew environment is set
export PATH="/opt/homebrew/bin:$PATH"
eval "$(/opt/homebrew/bin/brew shellenv)"

# Function to check if a directory is a git repository
check_git_repo() {
    if [ ! -d "$1/.git" ]; then
        echo -e "${RED}Error: $1 is not a git repository${NC}"
        exit 1
    fi
}

# Step 0: Check if the GitHub repository is public
check_repo_public() {
    echo -e "${BLUE}Checking if the GitHub repository is public...${NC}"
    REPO_STATUS=$(gh repo view ducktapeai/ducktape --json isPrivate -q .isPrivate 2>/dev/null || echo "error")

    if [ "$REPO_STATUS" == "true" ]; then
        echo -e "${RED}Error: The repository is private. Please set it to public.${NC}"
        while true; do
            echo -e "${YELLOW}Pause: Set the repository to public and type 'yes' to retry or 'no' to exit.${NC}"
            read -r RESPONSE
            if [ "$RESPONSE" == "yes" ]; then
                check_repo_public # Recheck after user action
                break
            elif [ "$RESPONSE" == "no" ]; then
                echo -e "${RED}Exiting script as requested.${NC}"
                exit 1
            else
                echo -e "${YELLOW}Invalid input. Please type 'yes' or 'no'.${NC}"
            fi
        done
    elif [ "$REPO_STATUS" == "error" ]; then
        echo -e "${RED}Error: Unable to connect to the repository. Please check your network or GitHub access.${NC}"
        exit 1
    else
        echo -e "${GREEN}The repository is public. Proceeding...${NC}"
    fi
}

# Call the function at the start of the script
check_repo_public

# Check both repositories exist and are git repos
check_git_repo "$DUCKTAPE_DIR"
check_git_repo "$HOMEBREW_DIR"

# Step 1: Prompt for new version
echo -e "${BLUE}Current version in ducktape Cargo.toml:${NC}"
CURRENT_VERSION=$(grep '^version =' "$DUCKTAPE_DIR/Cargo.toml" | cut -d'"' -f2)
echo -e "${YELLOW}$CURRENT_VERSION${NC}"
echo -e "${BLUE}Enter the new version (e.g., 0.11.0):${NC}"
read -r NEW_VERSION
if [ -z "$NEW_VERSION" ]; then
    echo -e "${RED}Error: Version cannot be empty${NC}"
    exit 1
fi

# Step 2: Update version in Cargo.toml
echo -e "${BLUE}Updating Cargo.toml to version $NEW_VERSION...${NC}"
cd "$DUCKTAPE_DIR"
sed -i '' "s/version = \"$CURRENT_VERSION\"/version = \"$NEW_VERSION\"/" Cargo.toml
echo -e "${GREEN}Cargo.toml updated${NC}"

# Step 3: Update CHANGELOG.md
echo -e "${BLUE}Updating CHANGELOG.md...${NC}"
TODAY=$(date +%Y-%m-%d)
cat > temp_changelog << EOL
## [$NEW_VERSION] - $TODAY
### Changed
- Started new development cycle with minor version bump
- Preparing for new feature additions

$(cat CHANGELOG.md)
EOL
mv temp_changelog CHANGELOG.md
# Update version links (simplified, assumes a standard format)
sed -i '' "s|\[unreleased\]:.*|\[unreleased\]: https://github.com/ducktapeai/ducktape/compare/v$NEW_VERSION...HEAD|" CHANGELOG.md
echo "[${NEW_VERSION}]: https://github.com/ducktapeai/ducktape/compare/v${CURRENT_VERSION}...v${NEW_VERSION}" >> CHANGELOG.md
echo -e "${GREEN}CHANGELOG.md updated${NC}"

# Step 4: Commit changes to ducktape repository
echo -e "${BLUE}Committing changes to ducktape repository...${NC}"
git add Cargo.toml CHANGELOG.md
git commit -m "Bump version to $NEW_VERSION"
git push origin main
echo -e "${GREEN}Changes committed and pushed${NC}"

# Step 5: Create and push git tag
echo -e "${BLUE}Creating and pushing git tag v$NEW_VERSION...${NC}"

# Check if tag already exists
if git rev-parse "v$NEW_VERSION" >/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: Tag v$NEW_VERSION already exists${NC}"
    echo -e "${BLUE}Choose an option:${NC}"
    echo -e "  1) Try a different version number"
    echo -e "  2) Force update the existing tag"
    echo -e "  3) Skip tag creation and continue with existing tag"
    
    read -p "Enter your choice (1-3): " TAG_OPTION
    
    case $TAG_OPTION in
        1)
            echo -e "${YELLOW}Returning to version selection...${NC}"
            # Reset changes to Cargo.toml and CHANGELOG.md
            cd "$DUCKTAPE_DIR"
            git restore Cargo.toml CHANGELOG.md
            # Start over from step 1
            exec "$0"
            ;;
        2)
            echo -e "${YELLOW}Force updating tag v$NEW_VERSION...${NC}"
            git tag -d "v$NEW_VERSION"
            git push origin --delete "v$NEW_VERSION" || true
            git tag "v$NEW_VERSION"
            git push origin "v$NEW_VERSION"
            ;;
        3)
            echo -e "${YELLOW}Skipping tag creation and continuing with existing tag...${NC}"
            ;;
        *)
            echo -e "${RED}Invalid option. Exiting.${NC}"
            exit 1
            ;;
    esac
else
    # Create tag normally if it doesn't exist
    git tag "v$NEW_VERSION"
    git push origin "v$NEW_VERSION"
    echo -e "${GREEN}Tag v$NEW_VERSION created and pushed${NC}"
fi

# Step 6: Create GitHub release
echo -e "${BLUE}Creating GitHub release for v$NEW_VERSION...${NC}"
RELEASE_NOTES=$(awk "/## \[$NEW_VERSION\]/{flag=1; next} /## \[/{flag=0} flag" CHANGELOG.md | sed 's/^### /### /')
gh release create "v$NEW_VERSION" --title "v$NEW_VERSION" --notes "$RELEASE_NOTES"
echo -e "${GREEN}GitHub release created: https://github.com/ducktapeai/ducktape/releases/tag/v$NEW_VERSION${NC}"

# Step 7: Calculate SHA256 hash
echo -e "${BLUE}Calculating SHA256 hash for v$NEW_VERSION tarball...${NC}"
curl -sL "https://github.com/ducktapeai/ducktape/archive/refs/tags/v$NEW_VERSION.tar.gz" -o temp.tar.gz
SHA256=$(shasum -a 256 temp.tar.gz | cut -d' ' -f1)
rm temp.tar.gz
echo -e "${GREEN}SHA256: $SHA256${NC}"

# Step 8: Update Homebrew formula
echo -e "${BLUE}Updating Homebrew formula in $HOMEBREW_DIR...${NC}"
cd "$HOMEBREW_DIR"
cat > Formula/ducktape.rb << EOL
class Ducktape < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
  homepage "https://github.com/ducktapeai/ducktape"
  url "https://github.com/ducktapeai/ducktape/archive/refs/tags/v$NEW_VERSION.tar.gz"
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
      opoo "Shell completions couldn't be generated: #{e.message}"
      # Create minimal completions as fallback
      (bash_completion/"ducktape").write "# Fallback bash completions for ducktape\n"
      (zsh_completion/"_ducktape").write "# Fallback zsh completions for ducktape\n"
      (fish_completion/"ducktape.fish").write "# Fallback fish completions for ducktape\n"
    end
    
    man1.install "man/ducktape.1" if File.exist?("man/ducktape.1")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ducktape --version")
    system "#{bin}/ducktape", "calendar", "list"
  end
end
EOL
echo -e "${GREEN}Homebrew formula updated${NC}"

# Step 9: Commit and push changes to homebrew-ducktape
echo -e "${BLUE}Committing and pushing changes to homebrew-ducktape...${NC}"
git add Formula/ducktape.rb
git commit -m "Update formula to version $NEW_VERSION"
git push origin main
echo -e "${GREEN}Homebrew formula changes pushed${NC}"

# Step 10: Uninstall existing ducktape versions and clear cache
echo -e "${BLUE}Uninstalling existing ducktape versions...${NC}"
brew uninstall ducktape 2>/dev/null || true
brew uninstall ducktapeai/ducktape/ducktape 2>/dev/null || true
brew untap ducktapeai/ducktape 2>/dev/null || true

# Clean caches to prevent SHA256 mismatch errors
echo -e "${BLUE}Clearing Homebrew cache for ducktape tarballs...${NC}"
rm -f "$HOME/Library/Caches/Homebrew/downloads/"*ducktape*".tar.gz" 2>/dev/null || true
brew cleanup -s ducktape 2>/dev/null || true
brew cleanup --prune=all ducktape 2>/dev/null || true

# Re-tap the repository
brew tap ducktapeai/ducktape https://github.com/ducktapeai/homebrew-ducktape.git
echo -e "${GREEN}Existing versions uninstalled and tap refreshed${NC}"

# Step 11: Install the new version
echo -e "${BLUE}Installing ducktape v$NEW_VERSION via Homebrew...${NC}"
brew install --build-from-source ducktapeai/ducktape/ducktape
echo -e "${GREEN}Installation complete${NC}"

# Step 12: Verify the installation
echo -e "${BLUE}Verifying installed version...${NC}"
INSTALLED_VERSION=$(ducktape --version)
echo "Using ducktape from: $(which ducktape)"
# Extract just the version number for comparison
INSTALLED_VERSION_NUMBER=$(echo "$INSTALLED_VERSION" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
if [[ "$INSTALLED_VERSION_NUMBER" == "$NEW_VERSION" ]]; then
    echo -e "${GREEN}Success: $INSTALLED_VERSION${NC}"
else
    echo -e "${RED}Error: Installed version ($INSTALLED_VERSION) does not match expected version ($NEW_VERSION)${NC}"
    echo -e "${YELLOW}Would you like to continue anyway? (y/n)${NC}"
    read -r CONTINUE_RESPONSE
    if [[ "$CONTINUE_RESPONSE" != "y" && "$CONTINUE_RESPONSE" != "Y" ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}All steps completed successfully!${NC}"