# fn-8-v3b.13 Add SMC write commands to TonicHelperTool

## Description
Add SMC write commands to `TonicHelperTool` for fan control functionality.

**Size:** M

**Files:**
- `TonicHelperTool/` (helper tool source)
- `Tonic/Tonic/Utilities/PrivilegedHelperManager.swift` (XPC client)

## Approach

1. Add new XPC command to helper tool:
   ```swift
   case setFanSpeed(fanId: Int, speed: Int)
   case setFanMode(mode: FanMode)
   ```

2. Implement SMC write in helper:
   - Use `SMCService` or direct SMC key writes
   - Fan speed keys: `F0Md` (fan mode), `F0Tx` (fan target speed)
   - Return success/failure status

3. Add client methods in `PrivilegedHelperManager`:
   ```swift
   func setFanSpeed(_ fanId: Int, speed: Int) async throws
   func setFanMode(_ mode: FanMode) async throws
   ```

4. Handle errors:
   - Helper not installed
   - Permission denied
   - Invalid fan ID
   - Invalid speed range

## Key Context

SMC (System Management Controller) keys for fans:
- `F0Md` - Fan mode (0=auto, 1=forced/manual)
- `F0Tx` - Fan target speed (RPM)
- `F1Md`, `F1Tx` - Fan 1, etc.

Helper tool requires:
- `com.apple.developer.driverkit` entitlement (if using DriverKit)
- Or `com.apple.security.cs.disable-library-validation` for development

Fan speed values are typically RPM, not percentage. Need to map slider 0-100% to min-max RPM range.

Reference: `SMCReader.swift` for existing SMC read patterns.
## Acceptance
- [ ] TonicHelperTool has setFanSpeed command
- [ ] TonicHelperTool has setFanMode command
- [ ] PrivilegedHelperManager exposes setFanSpeed/setFanMode methods
- [ ] SMC writes succeed for valid fan IDs and speeds
- [ ] Errors handled: helper not installed, permission denied, invalid values
- [ ] Fan speed maps correctly from percentage to RPM
- [ ] Fan mode changes persist across app restart
## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs: