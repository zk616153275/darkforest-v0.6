#!/bin/bash
# Test script to verify nargo works

cd /home/zk/web3-projects/darkforest-v0.6/aztec-darkforest

echo "Nargo version:"
~/.nargo/bin/nargo --version

echo ""
echo "Checking project..."
~/.nargo/bin/nargo check 2>&1
