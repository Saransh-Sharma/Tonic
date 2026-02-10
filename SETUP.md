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

The generated project includes two app targets:

- `Tonic` (direct distribution)
- `TonicStore` (Mac App Store-safe distribution with `TONIC_STORE`)

### 3. Open in Xcode

```bash
open Tonic/Tonic.xcodeproj
```

## Building

### Build Direct Target (`Tonic`)

```bash
xcodebuild \
  -project Tonic/Tonic.xcodeproj \
  -scheme Tonic \
  -configuration Debug \
  -destination 'platform=macOS' \
  build CODE_SIGNING_ALLOWED=NO
```

### Build Store Target (`TonicStore`)

```bash
xcodebuild \
  -project Tonic/Tonic.xcodeproj \
  -scheme TonicStore \
  -configuration Debug \
  -destination 'platform=macOS' \
  build CODE_SIGNING_ALLOWED=NO
```

### Release Builds

```bash
xcodebuild -project Tonic/Tonic.xcodeproj -scheme Tonic -configuration Release -destination 'platform=macOS' build
xcodebuild -project Tonic/Tonic.xcodeproj -scheme TonicStore -configuration Release -destination 'platform=macOS' build
```

### Build Helper Tool

The privileged helper tool requires a separate build:

```bash
xcodebuild -scheme TonicHelperTool -configuration Release build
```

## Running

From Xcode, press Cmd+R or select Product > Run.

The first run may require granting permissions:
- Store target: authorized scopes (Home/Applications/startup disk) for full feature coverage
- Direct target: Full Disk Access (for scanning and cleanup)
- Notifications (for alerts)
- Location (for weather widget)

## Security Model Notes (Store Edition)

Store edition uses security-scoped bookmarks and typed access-state handling.

Key implementation surfaces:

- `Tonic/Tonic/Models/AccessScopeModels.swift`
- `Tonic/Tonic/Services/AccessBroker.swift`
- `Tonic/Tonic/Services/ScopeResolver.swift`
- `Tonic/Tonic/Services/ScopedFileSystem.swift`
- `Tonic/Tonic/Utilities/BuildFlavor.swift`

### What to use in new code

- Use `ScopedFileSystem` for file reads/writes/trash/remove/enumeration.
- Use scoped `resourceValues(...)` helpers for metadata reads.
- Use `ScopeBlockedReason` instead of ad-hoc strings.
- Do not add Store-sensitive logic that bypasses `withReadAccess`/`withWriteAccess`.

### Blocked reason taxonomy

- `missingScope`
- `staleBookmark`
- `disconnectedScope`
- `sandboxReadDenied`
- `sandboxWriteDenied`
- `macOSProtected`

## Testing

### Run All Tests

```bash
xcodebuild \
  -project Tonic/Tonic.xcodeproj \
  -scheme Tonic \
  -configuration Debug \
  -destination 'platform=macOS' \
  test CODE_SIGNING_ALLOWED=NO
```

### Run Scope/Access Migration Suites

```bash
xcodebuild \
  -project Tonic/Tonic.xcodeproj \
  -scheme Tonic \
  -configuration Debug \
  -destination 'platform=macOS' \
  test CODE_SIGNING_ALLOWED=NO \
  -only-testing:TonicTests/AccessScopeModelsTests \
  -only-testing:TonicTests/ScopeResolverTests \
  -only-testing:TonicTests/ServiceErrorHandlingTests
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

### Store Target Fails or Behaves Differently

- Confirm build scheme is `TonicStore`.
- Verify `Tonic/Tonic/TonicStore.entitlements` contains sandbox and user-selected read/write.
- Verify scope UI is used to grant Home/Applications/startup disk.
- Check for stale/disconnected scopes in Settings permissions management UI.
- Audit feature code for raw `FileManager` and raw `URL.resourceValues` calls.
- Route all Store-sensitive file access through `ScopedFileSystem`.

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
- [STORE_SECURITY_SCOPES_AND_BUILDS.md](STORE_SECURITY_SCOPES_AND_BUILDS.md) - Scope/bookmark lifecycle and build matrix deep dive
- [Tonic/APP_STORE_REVIEW_NOTES.md](Tonic/APP_STORE_REVIEW_NOTES.md) - Store review demo notes
