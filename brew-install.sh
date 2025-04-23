#!/bin/bash
# brew-install.sh - Install Ducktape via Homebrew
#
# This script helps manage different installation types:
# - Regular release (stable version)
# - HEAD installation (development version)
# - Local formula installation
#
# Usage: ./brew-install.sh [--head|--local]

set -e  # Exit on error

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
RESET='\033[0m'

echo -e "${BLUE}=== Ducktape Homebrew Installation ===${RESET}\n"

# Parse arguments
INSTALL_TYPE="stable"
if [[ "$1" == "--head" ]]; then
    INSTALL_TYPE="head"
elif [[ "$1" == "--local" ]]; then
    INSTALL_TYPE="local"
fi

# Function to handle formula installation
install_formula() {
    # First, uninstall any existing installation
    if brew list ducktape &>/dev/null; then
        echo -e "${YELLOW}Uninstalling existing Ducktape installation...${RESET}"
        brew uninstall ducktape
        echo -e "${GREEN}Previous installation removed${RESET}"
    fi
    
    # Install based on install type
    case "$INSTALL_TYPE" in
        "stable")
            echo -e "${YELLOW}Installing stable release from tap...${RESET}"
            brew install ducktapeai/ducktape/ducktape
            ;;
        "head")
            echo -e "${YELLOW}Installing development version (HEAD) from tap...${RESET}"
            brew install --head ducktapeai/ducktape/ducktape
            ;;
        "local")
            echo -e "${YELLOW}Installing from local formula...${RESET}"
            FORMULA_PATH="./Formula/ducktape.rb"
            if [ ! -f "$FORMULA_PATH" ]; then
                echo -e "${RED}Error: Formula not found at $FORMULA_PATH${RESET}"
                exit 1
            fi
            brew install --build-from-source "$FORMULA_PATH"
            ;;
    esac
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Installation failed${RESET}"
        exit 1
    fi
}

# Execute installation
install_formula

# Verify installation
echo -e "\n${GREEN}Installation successful!${RESET}"
INSTALLED_VERSION=$(ducktape --version)
echo -e "${BLUE}Installed version:${RESET} $INSTALLED_VERSION"

echo -e "\nTo update in the future, run:"
echo -e "  - For stable releases: ${GREEN}brew upgrade ducktape${RESET}"
echo -e "  - For development version: ${GREEN}brew reinstall --head ducktapeai/ducktape/ducktape${RESET}"
echo -e "  - From local formula: ${GREEN}$0 --local${RESET}"
