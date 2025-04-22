#!/bin/bash
# Script to manually fix SHA256 mismatches in the Homebrew formula

set -e  # Exit on any error

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# Configuration
VERSION="0.13.5"
FORMULA_PATH="Formula/ducktape.rb"
GITHUB_URL="https://codeload.github.com/ducktapeai/ducktape/tar.gz/refs/tags/v$VERSION"
GITHUB_TARBALL="/tmp/ducktape-github-$VERSION.tar.gz"

echo -e "${YELLOW}Fixing SHA256 mismatch for ducktape version $VERSION${RESET}"

# Step 1: Clean Homebrew cache
echo -e "${YELLOW}Cleaning Homebrew cache...${RESET}"
brew cleanup -s ducktape
rm -f ~/Library/Caches/Homebrew/downloads/*ducktape*

# Step 2: Download tarball directly from GitHub
echo -e "${YELLOW}Downloading fresh tarball from GitHub...${RESET}"
curl -L -s "$GITHUB_URL" -o "$GITHUB_TARBALL"
GITHUB_SHA256=$(shasum -a 256 "$GITHUB_TARBALL" | awk '{print $1}')
echo -e "${GREEN}Tarball downloaded. SHA256: $GITHUB_SHA256${RESET}"

# Step 3: Update formula with correct SHA256
echo -e "${YELLOW}Updating formula with correct SHA256...${RESET}"

# First, manually verify what's currently in the formula
CURRENT_SHA=$(grep -E 'sha256 "[^"]+"' "$FORMULA_PATH" | sed 's/^.*sha256 "\(.*\)".*$/\1/')
echo -e "${YELLOW}Current SHA256 in formula: $CURRENT_SHA${RESET}"
echo -e "${YELLOW}New SHA256 from GitHub: $GITHUB_SHA256${RESET}"

# Only update if needed
if [ "$CURRENT_SHA" != "$GITHUB_SHA256" ]; then
  # Create completely new file with proper SHA
  TMP_FORMULA="/tmp/ducktape-formula.rb"
  cat > "$TMP_FORMULA" << EOF
class Ducktape < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
  homepage "https://github.com/ducktapeai/ducktape"
  url "https://github.com/ducktapeai/ducktape/archive/v$VERSION.tar.gz"
  version "$VERSION"
  sha256 "$GITHUB_SHA256"
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

  # Replace the original file
  cp "$TMP_FORMULA" "$FORMULA_PATH"
  rm -f "$TMP_FORMULA"
  echo -e "${GREEN}Formula updated with new SHA256${RESET}"
  
  # Commit the changes
  echo -e "${YELLOW}Committing changes...${RESET}"
  git add "$FORMULA_PATH"
  git commit -m "Fix SHA256 for ducktape version $VERSION"
  git push
  echo -e "${GREEN}Changes committed and pushed to GitHub${RESET}"
else
  echo -e "${GREEN}SHA256 already correct in formula${RESET}"
fi

# Step 4: Verify the formula
echo -e "${YELLOW}Verifying formula...${RESET}"
brew update
brew upgrade ducktape || {
  echo -e "${RED}Formula verification failed!${RESET}"
  echo -e "${YELLOW}Manual fix required. Try removing the Homebrew cache and retrying:${RESET}"
  echo "rm -rf ~/Library/Caches/Homebrew/downloads/*ducktape*"
  echo "brew upgrade ducktape"
  exit 1
}

echo -e "${GREEN}Formula verified and working!${RESET}"

# Cleanup
rm -f "$GITHUB_TARBALL"
echo -e "${GREEN}Done!${RESET}"
