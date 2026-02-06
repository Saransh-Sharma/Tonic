#!/bin/bash
# Format Swift code using SwiftFormat

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check if swiftformat is installed
if ! command -v swiftformat &> /dev/null; then
    echo "SwiftFormat is not installed."
    echo "Install with: brew install swiftformat"
    exit 1
fi

echo "Formatting Swift code..."
swiftformat --config "$PROJECT_ROOT/.swiftformat" "$PROJECT_ROOT/Tonic"
echo "Done!"
