#!/bin/bash
# Dark Forest Aztec - Development Environment Setup Script
# Run this script to install all required tools

set -e

echo "============================================"
echo "Dark Forest Aztec - Environment Setup"
echo "============================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running on Linux/WSL
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${RED}This script is designed for Linux/WSL. Please run it in WSL.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 1: Installing Noir (noirup)${NC}"
echo "----------------------------------------"

if command -v nargo &> /dev/null; then
    echo -e "${GREEN}✓ Nargo already installed: $(nargo --version)${NC}"
else
    echo "Installing noirup..."
    curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash

    # Add to PATH for current session
    export PATH="$HOME/.nargo/bin:$PATH"

    # Install latest stable nargo
    echo "Installing nargo (stable)..."
    ~/.nargo/bin/noirup

    echo -e "${GREEN}✓ Nargo installed: $(nargo --version)${NC}"
fi

echo ""
echo -e "${YELLOW}Step 2: Installing Aztec Sandbox${NC}"
echo "----------------------------------------"

if command -v aztec &> /dev/null; then
    echo -e "${GREEN}✓ Aztec CLI already installed: $(aztec --version 2>/dev/null || echo 'installed')${NC}"
else
    echo "Installing Aztec..."
    bash -i <(curl -s https://install.aztec.network)

    echo -e "${GREEN}✓ Aztec installed${NC}"
fi

echo ""
echo -e "${YELLOW}Step 3: Verifying Installation${NC}"
echo "----------------------------------------"

echo -n "Checking nargo... "
if command -v nargo &> /dev/null; then
    echo -e "${GREEN}✓ $(nargo --version)${NC}"
else
    echo -e "${RED}✗ Not found${NC}"
fi

echo -n "Checking aztec... "
if command -v aztec &> /dev/null; then
    echo -e "${GREEN}✓ Installed${NC}"
else
    echo -e "${YELLOW}⚠ Not found (may need to restart terminal)${NC}"
fi

echo ""
echo -e "${YELLOW}Step 4: Compiling Dark Forest Contract${NC}"
echo "----------------------------------------"

cd "$(dirname "$0")"

echo "Running: nargo compile"
if nargo compile 2>&1; then
    echo -e "${GREEN}✓ Compilation successful!${NC}"
else
    echo -e "${RED}✗ Compilation failed. Check errors above.${NC}"
    echo ""
    echo "Common issues:"
    echo "  - Missing dependencies: run 'nargo update'"
    echo "  - Syntax errors: check the error messages"
    exit 1
fi

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Start Aztec Sandbox: aztec start --sandbox"
echo "  2. Run tests: nargo test"
echo "  3. Deploy contract: (see README.md)"
echo ""
