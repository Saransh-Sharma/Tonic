#!/bin/bash
# Lint Swift code using SwiftLint

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check if swiftlint is installed
if ! command -v swiftlint &> /dev/null; then
    echo "SwiftLint is not installed."
    echo "Install with: brew install swiftlint"
    exit 1
fi

echo "Linting Swift code..."
swiftlint lint --config "$PROJECT_ROOT/.swiftlint.yml"
echo "Lint complete!"
