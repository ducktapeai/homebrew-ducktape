#!/bin/bash
# Simple manual formula updater for Ducktape
# Usage: ./update-formula.sh 0.13.7 [sha256]

set -e  # Exit on error

NEW_VERSION=$1
SHA256=$2

if [ -z "$NEW_VERSION" ]; then
    echo "Error: No version specified"
    echo "Usage: ./update-formula.sh 0.13.7 [sha256]"
    exit 1
fi

FORMULA_PATH="./Formula/ducktape.rb"

# Check if formula exists
if [ ! -f "$FORMULA_PATH" ]; then
    echo "Error: Formula not found at $FORMULA_PATH"
    exit 1
fi

# Extract current version
CURRENT_VERSION=$(grep -E 'version "[^"]+"' "$FORMULA_PATH" | sed 's/^.*version "\(.*\)".*$/\1/')
echo "Current version in formula: $CURRENT_VERSION"

# Update version in formula
echo "Updating formula version to $NEW_VERSION"
sed -i '' "s/version \"$CURRENT_VERSION\"/version \"$NEW_VERSION\"/" "$FORMULA_PATH"

# If SHA256 is provided, update it
if [ -n "$SHA256" ]; then
    echo "Updating SHA256 to $SHA256"
    CURRENT_SHA=$(grep -E 'sha256 "[^"]+"' "$FORMULA_PATH" | sed 's/^.*sha256 "\(.*\)".*$/\1/')
    sed -i '' "s/sha256 \"$CURRENT_SHA\"/sha256 \"$SHA256\"/" "$FORMULA_PATH"
else
    echo "No SHA256 provided. You'll need to update it manually after downloading the tarball."
    echo "You can calculate it with: shasum -a 256 path/to/ducktape-$NEW_VERSION.tar.gz"
fi

echo "Done!"
echo "Next steps:"
echo "1. If you didn't provide a SHA256, download the tarball and update the SHA256:"
echo "   - URL: https://github.com/ducktapeai/ducktape/archive/refs/tags/v$NEW_VERSION.tar.gz"
echo "   - Calculate SHA256: shasum -a 256 path/to/ducktape-$NEW_VERSION.tar.gz"
echo "   - Then update the formula manually"
echo "2. Test the formula: brew install --build-from-source ./Formula/ducktape.rb"
echo "3. Commit the changes: git commit -am \"Update formula to $NEW_VERSION\""
echo "4. Push changes: git push"
