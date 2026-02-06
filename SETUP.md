# Tonic Development Setup

Guide for setting up a local development environment for Tonic.

## Prerequisites

- macOS 14.0 (Sonoma) or later
- Xcode 16.0 or later
- XcodeGen (for generating Xcode project from YAML)
- SwiftFormat (optional, for code formatting)
- SwiftLint (optional, for code linting)

## Installation

### 1. Install Xcode

Download from the Mac App Store or [Apple Developer Portal](https://developer.apple.com/download/all/).

### 2. Install XcodeGen

```bash
brew install xcodegen
```

### 3. Install SwiftFormat (optional)

```bash
brew install swiftformat
```

### 4. Install SwiftLint (optional)

```bash
brew install swiftlint
```

## Project Setup

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/TONIC.git
cd TONIC
```

### 2. Generate Xcode Project

```bash
xcodegen generate
```

This generates `Tonic/Tonic.xcodeproj` from `Tonic/project.yml`.

### 3. Open in Xcode

```bash
open Tonic/Tonic.xcodeproj
```

## Building

### Debug Build

```bash
xcodebuild -scheme Tonic -configuration Debug build
```

Or from Xcode: Product > Build (Cmd+B)

### Release Build

```bash
xcodebuild -scheme Tonic -configuration Release build
```

### Build Helper Tool

The privileged helper tool requires a separate build:

```bash
xcodebuild -scheme TonicHelperTool -configuration Release build
```

## Running

From Xcode, press Cmd+R or select Product > Run.

The first run may require granting permissions:
- Full Disk Access (for scanning and cleanup)
- Notifications (for alerts)
- Location (for weather widget)

## Testing

### Run All Tests

```bash
xcodebuild test -scheme Tonic -project Tonic/Tonic.xcodeproj
```

### Run Specific Test

From Xcode, use the Test Navigator (Cmd+6).

## Code Quality

### Format Code

```bash
./Scripts/format.sh
```

Or directly:

```bash
swiftformat --config .swiftformat Tonic/
```

### Lint Code

```bash
./Scripts/lint.sh
```

Or directly:

```bash
swiftlint lint --config .swiftlint.yml
```

### Auto-fix Lint Issues

```bash
swiftlint --config .swiftlint.yml --correct
```

## Development Workflow

1. Make changes to source files
2. Run `./Scripts/format.sh` to format code
3. Run `./Scripts/lint.sh` to check for issues
4. Build and test in Xcode
5. Commit changes

## Troubleshooting

### Project Won't Build

- Ensure Xcode version is 16.0+
- Run `xcodegen generate` to regenerate project
- Clean build folder: Product > Clean Build Folder (Shift+Cmd+K)

### SwiftFormat/SwiftLint Not Found

- Install via Homebrew: `brew install swiftformat swiftlint`
- Ensure Homebrew bin directory is in PATH

### Helper Tool Installation Fails

- Requires admin authentication
- Check System Settings > Privacy & Security
- Remove existing helper: `sudo rm -rf /Library/PrivilegedHelperTools/com.tonic.TonicHelperTool`

## Project Structure Reference

```
TONIC/
├── Tonic/
│   ├── Tonic/              # Main app source code
│   │   ├── Views/          # SwiftUI views
│   │   ├── Services/       # Business logic
│   │   ├── Models/         # Data types
│   │   ├── Design/         # Design system
│   │   └── MenuBarWidgets/ # Widget implementation
│   ├── TonicTests/         # Unit tests
│   └── project.yml         # XcodeGen config
├── TonicHelperTool/        # Privileged helper
├── Scripts/                # Utility scripts
│   ├── format.sh           # Code formatting
│   └── lint.sh             # Code linting
├── .swift-version          # Swift version pin
├── .swiftformat            # SwiftFormat config
├── .swiftlint.yml          # SwiftLint config
└── CLAUDE.md               # AI/agent context
```

## Additional Resources

- [CLAUDE.md](CLAUDE.md) - Project conventions and architecture
- [README.md](README.md) - Project overview and features
- [ARCHITECTURE.md](ARCHITECTURE.md) - Detailed architecture documentation
