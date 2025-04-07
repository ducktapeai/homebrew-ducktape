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
eval "$(/opt/homebrew/bin/brew shellenv)"

# Function to check if a directory is a git repository
check_git_repo() {
    if [ ! -d "$1/.git" ]; then
        echo -e "${RED}Error: $1 is not a git repository${NC}"
        exit 1
    fi
}

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
git tag "v$NEW_VERSION"
git push origin "v$NEW_VERSION"
echo -e "${GREEN}Tag v$NEW_VERSION created and pushed${NC}"

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
    
    # Generate shell completions
    output = Utils.safe_popen_read(bin/"ducktape", "completions")
    (bash_completion/"ducktape").write output
    (zsh_completion/"_ducktape").write output
    (fish_completion/"ducktape.fish").write output
    
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

# Step 10: Uninstall existing ducktape versions
echo -e "${BLUE}Uninstalling existing ducktape versions...${NC}"
brew uninstall ducktape 2>/dev/null || true
brew uninstall ducktapeai/ducktape/ducktape 2>/dev/null || true
brew untap ducktapeai/ducktape 2>/dev/null || true
brew tap ducktapeai/ducktape https://github.com/ducktapeai/homebrew-ducktape.git
echo -e "${GREEN}Existing versions uninstalled and tap refreshed${NC}"

# Step 11: Install the new version
echo -e "${BLUE}Installing ducktape v$NEW_VERSION via Homebrew...${NC}"
brew install --build-from-source ducktapeai/ducktape/ducktape
echo -e "${GREEN}Installation complete${NC}"

# Step 12: Verify the installation
echo -e "${BLUE}Verifying installed version...${NC}"
INSTALLED_VERSION=$(ducktape --version)
if [[ "$INSTALLED_VERSION" == *"version $NEW_VERSION"* ]]; then
    echo -e "${GREEN}Success: $INSTALLED_VERSION${NC}"
else
    echo -e "${RED}Error: Installed version ($INSTALLED_VERSION) does not match expected version ($NEW_VERSION)${NC}"
    exit 1
fi

echo -e "${GREEN}All steps completed successfully!${NC}"