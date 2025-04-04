#!/bin/bash

set -e

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "Error: This script should not be run as root/sudo"
    echo "Please run without sudo: ./update-public-brew.sh"
    exit 1
fi

# Ensure Homebrew environment is properly set
eval "$(/opt/homebrew/bin/brew shellenv)"

echo "Updating Ducktape Public Release Version..."

# Get current version from the formula
CURRENT_VERSION=$(grep 'version "' Formula/ducktape.rb | cut -d'"' -f2)
echo "Current version in formula: ${CURRENT_VERSION}"

# Prompt for version update
read -p "Enter new version (format x.y.z): " NEW_VERSION

# Update version in formula
sed -i '' "s/version \"${CURRENT_VERSION}\"/version \"${NEW_VERSION}\"/" Formula/ducktape.rb

# Create the release tarball URL
GITHUB_URL="https://github.com/ducktapeai/ducktape/archive/refs/tags/v${NEW_VERSION}.tar.gz"

# Download tarball to calculate SHA
echo "Downloading release tarball to calculate SHA256..."
TARBALL="/tmp/ducktape-${NEW_VERSION}.tar.gz"
curl -L -o "$TARBALL" "$GITHUB_URL"
SHA256=$(shasum -a 256 "$TARBALL" | cut -d' ' -f1)
rm -f "$TARBALL"

# Update formula with new URL and SHA
cat > Formula/ducktape.rb << EOL
class Ducktape < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
  homepage "https://github.com/ducktapeai/ducktape"
  version "${NEW_VERSION}"
  url "https://github.com/ducktapeai/ducktape/archive/refs/tags/v\#{version}.tar.gz"
  sha256 "${SHA256}"
  license "MIT"
  
  depends_on "rust" => :build

  def install
    # Build with release optimizations
    system "cargo", "build", "--release"
    
    # Install the binary
    bin.install "target/release/ducktape"
    
    # Install bash completion if it exists
    bash_completion.install "completions/ducktape.bash" if File.exist?("completions/ducktape.bash")
    
    # Install zsh completion if it exists
    zsh_completion.install "completions/_ducktape" if File.exist?("completions/_ducktape")
    
    # Install fish completion if it exists
    fish_completion.install "completions/ducktape.fish" if File.exist?("completions/ducktape.fish")
    
    # Install man page if it exists
    man1.install "man/ducktape.1" if File.exist?("man/ducktape.1")
  end

  test do
    # Verify the installation by checking version output
    assert_match /\\d+\\.\\d+\\.\\d+/, shell_output("\#{bin}/ducktape --version")
  end
end
EOL

echo "Updated formula with version ${NEW_VERSION}"
echo "Don't forget to:"
echo "1. Make the ducktape repo public"
echo "2. Create and push tag v${NEW_VERSION}"
echo "3. Create GitHub release with tag v${NEW_VERSION}"
echo "4. Test installation with: brew install ducktapeai/ducktape/ducktape"
