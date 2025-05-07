#!/bin/bash
# update-formula.sh - A script to manage Ducktape formula updates
# 
# This script helps automate the process of updating the Homebrew formula
# for the Ducktape project by:
# 1. Creating a tarball of the specified version
# 2. Calculating the SHA256 hash
# 3. Updating the formula with the new version and hash
#
# Following the Ducktape project's Rust coding standards for shell scripts.

set -e

# Check if version argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 0.16.17"
    exit 1
fi

VERSION=$1
FORMULA_PATH="Formula/ducktape.rb"
DUCKTAPE_PATH="../ducktape"
TARBALL_NAME="ducktape-$VERSION.tar.gz"
TEMP_DIR="temp_tarball"

echo "🦆 Ducktape Formula Update Process"
echo "===================================="
echo "Version: $VERSION"

# Step 1: Create a temporary directory for tarball creation
mkdir -p "$TEMP_DIR"
echo "✅ Created temporary directory"

# Step 2: Create a tarball of the source code
echo "Creating tarball from Ducktape source..."
(cd "$DUCKTAPE_PATH" && tar -czf "../homebrew-ducktape/$TEMP_DIR/$TARBALL_NAME" --exclude=target --exclude=.git .)
echo "✅ Created tarball: $TEMP_DIR/$TARBALL_NAME"

# Step 3: Calculate SHA256 hash
echo "Calculating SHA256 hash..."
TARBALL_HASH=$(shasum -a 256 "$TEMP_DIR/$TARBALL_NAME" | cut -d' ' -f1)
echo "✅ SHA256 hash: $TARBALL_HASH"

# Step 4: Update the formula
echo "Updating Homebrew formula..."
# Using sed to update version and hash in the formula
sed -i '' "s|^  url \".*\"|  url \"https://github.com/ducktapeai/ducktape/archive/v$VERSION.tar.gz\"|" "$FORMULA_PATH"
sed -i '' "s|^  version \".*\"|  version \"$VERSION\"|" "$FORMULA_PATH"
sed -i '' "s|^  sha256 \".*\"|  sha256 \"$TARBALL_HASH\"|" "$FORMULA_PATH"
echo "✅ Updated formula with new version and hash"

# Step 5: Show diff
echo "Formula changes:"
git diff "$FORMULA_PATH"

echo
echo "Formula update completed. Next steps:"
echo "1. Review the formula changes"
echo "2. Commit the changes: git add $FORMULA_PATH && git commit -m \"chore(formula): update to version $VERSION\""
echo "3. Push the changes: git push origin HEAD"
echo 
echo "Note: The temporary tarball is stored in $TEMP_DIR/$TARBALL_NAME and should not be committed to the repository."