#!/bin/bash

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")/Tonic"
BUILD_DIR="$PROJECT_DIR/build"
OUTPUT_DIR="$PROJECT_DIR/release"
APP_NAME="Tonic"
VERSION="${1:-dev}"  # Allow version argument

echo "🔨 Building $APP_NAME for distribution..."
echo ""

# Step 1: Generate Xcode project
echo "📦 Generating Xcode project..."
cd "$PROJECT_DIR"
xcodegen generate

# Step 2: Build release configuration
echo "🔧 Building release configuration..."
if ! xcodebuild -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  ONLY_ACTIVE_ARCH=NO \
  build; then
  echo ""
  echo "❌ Build failed! Trying with default DerivedData path..."
  echo ""

  # Fallback: Try building without custom derivedDataPath
  rm -rf "$BUILD_DIR"
  if ! xcodebuild -scheme "$APP_NAME" \
    -configuration Release \
    ONLY_ACTIVE_ARCH=NO \
    build; then
    echo "❌ Release build failed. You may need to fix compilation errors first."
    echo "💡 Try: cd Tonic && xcodebuild -scheme Tonic -configuration Debug build"
    exit 1
  fi

  # Use default DerivedData path
  BUILD_DIR="$HOME/Library/Developer/Xcode/DerivedData/Tonic-*/Build/Products/Release"
fi

# Step 3: Create output directory
echo "📁 Creating release directory..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Step 4: Copy built app to output directory
echo "📋 Copying built app..."

# Try to find the app in multiple possible locations
APP_PATH=""

# First try: Custom build directory
if [ -d "$BUILD_DIR/Build/Products/Release/$APP_NAME.app" ]; then
  APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
# Second try: Direct build directory
elif [ -d "$BUILD_DIR/$APP_NAME.app" ]; then
  APP_PATH="$BUILD_DIR/$APP_NAME.app"
# Third try: Default DerivedData (with wildcard)
else
  APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "$APP_NAME.app" -path "*/Release/*" 2>/dev/null | head -1)
fi

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
  echo "❌ Error: Built app not found"
  echo "🔍 Searched in:"
  echo "   - $BUILD_DIR/Build/Products/Release/"
  echo "   - $BUILD_DIR/"
  echo "   - $HOME/Library/Developer/Xcode/DerivedData/"
  echo ""
  echo "💡 Try building manually in Xcode to see the actual output location"
  exit 1
fi

echo "   Found at: $APP_PATH"
cp -R "$APP_PATH" "$OUTPUT_DIR/"

# Step 5: Create distributable ZIP
echo "📦 Creating ZIP archive..."
cd "$OUTPUT_DIR"
ZIP_NAME="${APP_NAME}-${VERSION}-macOS.zip"
zip -q -r "$ZIP_NAME" "$APP_NAME.app"

# Step 6: Display summary
echo ""
echo "✅ Build complete!"
echo ""
echo "📦 Output:"
echo "   App: $OUTPUT_DIR/$APP_NAME.app"
echo "   ZIP: $OUTPUT_DIR/$ZIP_NAME"
echo ""
echo "📊 Build info:"
SIZE=$(du -sh "$OUTPUT_DIR/$APP_NAME.app" | cut -f1)
ZIP_SIZE=$(du -sh "$OUTPUT_DIR/$ZIP_NAME" | cut -f1)
echo "   App Size: $SIZE"
echo "   ZIP Size: $ZIP_SIZE"
echo "   Version: $VERSION"
echo ""
echo "📤 To share: Send $ZIP_NAME"
echo "ℹ️  Users should right-click → Open to bypass Gatekeeper"
