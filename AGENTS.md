# Agent Guide: a-shell (iOS App)

## Overview

**a-shell** is the iOS terminal emulator app. It bundles native Linux tools (bash, vim, git, python) and provides a terminal interface for running them.

## Architecture

```
a-Shell.app/
├── a-Shell                     # Main app binary (Swift)
├── Frameworks/
│   ├── a_shell_kernel.framework   # Syscalls
│   ├── libz.dylib
│   ├── libssl.dylib
│   ├── libncurses.dylib
│   └── ...                     # All core libraries
│
├── bin/                        # Core tools (~30MB)
│   ├── bash                    # Shell
│   ├── ls, cp, mv, cat, grep   # Coreutils (50+ binaries)
│   ├── python3.12              # Python
│   ├── git                     # Git
│   ├── vim                     # Vim
│   ├── curl, ssh               # Network
│   ├── tar, gzip               # Archivers
│   └── pkg                     # Package manager
│
└── share/
    └── python3.12/             # Python standard library

User Space (~/Documents/.a-shell/)
├── wasm/
│   └── bin/
│       ├── node.wasm           # WASM packages
│       ├── ripgrep.wasm
│       └── ...
│
└── pkg/
    ├── installed/              # Package metadata
    └── cache/                  # Downloaded packages
```

## Responsibilities

### What This Layer DOES

1. **Terminal UI**
   - WebView-based terminal (hterm)
   - Keyboard input handling
   - Touch gestures
   - Themes/colors
   - Tabs/sessions

2. **Bundle Core Tools**
   - Include bash, vim, git, python
   - Include 50+ coreutils
   - Pre-built, signed at build time
   - No extraction needed

3. **Session Management**
   - Spawn bash processes (via kernel)
   - Manage multiple tabs/sessions
   - Environment variables
   - Working directory tracking

4. **Package Management**
   - Swift PackageManager class
   - Download WASM packages from GitHub
   - Install to ~/Documents/.a-shell/
   - IPC with pkg binary

5. **File Management**
   - Access iOS file system
   - iCloud Drive integration
   - Share files with other apps
   - Working Copy support

### What This Layer DOES NOT DO

- ❌ NOT a syscall layer (that's a-shell-kernel/)
- ❌ NOT a build system (that's a-shell-packages/)
- ❌ NOT compile code (just runs pre-built binaries)
- ❌ NOT download native code (only WASM allowed by Apple)

## Key Components

### TerminalView (SwiftUI)

**File**: `a-Shell/ContentViewTerm.swift`

**Responsibilities**:
- Display terminal output (hterm WebView)
- Capture keyboard input
- Handle gestures (swipe, pinch)
- Show/hide keyboard

### SessionManager (Swift)

**File**: `a-Shell/SessionManager.swift` (to be created)

**Responsibilities**:
- Start bash processes
- Track active sessions
- Handle session switching
- Environment per session

```swift
class SessionManager {
    func startSession() -> Session
    func executeCommand(_ cmd: String, in session: Session)
    func switchSession(to session: Session)
}
```

### PackageManager (Swift)

**File**: `a-Shell/Package/PackageManager.swift` (to be created)

**Responsibilities**:
- Download WASM from GitHub
- Install to user space
- Track installed packages
- Handle IPC from pkg command

```swift
class PackageManager {
    static func install(_ name: String) async throws
    static func remove(_ name: String)
    static func list() -> [Package]
    static func handleCommand(_ args: [String]) -> Int32
}
```

### WebAssembly Runtime (WAMR)

**File**: `a-Shell/WasmRuntime.swift` (to be created)

**Responsibilities**:
- Load WASM modules
- Execute via WAMR
- WASI support (file I/O)

```swift
class WasmRuntime {
    func load(_ wasm: URL) -> Module
    func execute(_ module: Module, with args: [String])
}
```

## Build System

### Xcode Build Phases

**Phase 1**: Compile Swift sources
```bash
swiftc a-Shell/*.swift ...
```

**Phase 2**: Build core packages (external script)
```bash
cd ../a-shell-packages
./scripts/build-core.sh
```

**Phase 3**: Copy built artifacts
```bash
# Copy binaries to app bundle
cp ../a-shell-packages/.build/bin/* "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/bin/"
cp ../a-shell-packages/.build/lib/* "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/lib/"
```

**Phase 4**: Link frameworks
```bash
# Link a-shell-kernel.framework
# Link other frameworks
```

**Phase 5**: Sign and bundle
```bash
codesign --force --sign "$CODE_SIGN_IDENTITY" ...
```

### Build Settings

**Target**: iOS 16.0+
**Architecture**: arm64 (device), x86_64/arm64 (simulator)
**Bundle ID**: AsheKube.app.a-Shell

### Output

**IPA**: a-Shell.ipa (~40-50MB)
- Signed with distribution certificate
- Includes all core tools
- Ready for App Store

## Integration Points

### With a-shell-kernel

```
a-Shell.app
├── bin/bash
│   ↓ calls syscalls
├── a_shell_kernel.framework
│   ↓ translates to
└── iOS APIs
```

**Kernel provides**:
- fork(), exec(), waitpid()
- open(), read(), write()
- signal handling
- File operations

### With a-shell-packages

```
a-shell-packages/           a-Shell.app/
├── packages/core/          ├── bin/
│   └── bash/build.sh           └── bash
│       ↓ builds
│   bin/bash
└── pkg/
    └── pkg.c
        ↓ compiles to
    bin/pkg
```

**Packages provide**:
- Core tools (built during Xcode build)
- pkg command (manages WASM)

## Two-Tier System

### Tier 1: Core Native Tools (Built-in)

**Location**: App bundle `bin/`

**Tools**:
- Shell: bash
- Utilities: ls, cp, mv, cat, grep, sed, awk
- Editor: vim
- Version control: git
- Languages: python3.12
- Network: curl, ssh
- Archivers: tar, gzip

**Total**: ~50 tools, ~30MB

**Update**: Via App Store only

**Access**: Always available, no download needed

### Tier 2: WASM Packages (User-installed)

**Location**: `~/Documents/.a-shell/wasm/bin/`

**Tools**:
- JavaScript: node
- Search: ripgrep, fd
- Tools: extras not in core

**Total**: Variable, user decides

**Update**: Via `pkg install <name>`

**Access**: Downloaded on demand

## PATH Resolution

**Shell searches in order**:
```bash
1. ~/Documents/.a-shell/wasm/bin    # User WASM
2. /usr/bin (app bundle)            # Core native
3. /bin (app bundle)                # More core
```

**Implementation**:
```bash
export PATH="$HOME/Documents/.a-shell/wasm/bin:/usr/bin:/bin"
```

## User Flows

### First Launch

```
1. User opens app
2. Terminal starts
3. Bash spawns (built-in)
4. Ready to use immediately
```

**No extraction delay** - everything built-in.

### Installing Package

```
1. User types: pkg install node
2. Shell execs bin/pkg
3. pkg IPCs to PackageManager
4. PackageManager downloads node.wasm
5. Extracts to ~/Documents/.a-shell/
6. Records in pkg database
7. User can now run: node
```

### Running Core Tool

```
1. User types: git clone https://...
2. Shell finds /usr/bin/git
3. Execs git (built-in)
4. Git uses kernel syscalls
5. Output displayed in terminal
```

## Agent Instructions

### When Working on This Layer

1. **Test on device frequently**
   - Simulator ≠ real iOS behavior
   - Especially for file system, networking

2. **Handle sandbox correctly**
   - ~/Documents/ - user files
   - ~/Library/ - app data
   - Never write outside these

3. **Respect App Store rules**
   - No downloaded native code (WASM only)
   - All native code signed at build
   - No JIT compilation

### Common Tasks

**Adding a built-in tool**:
1. Add build.sh to a-shell-packages/packages/core/<tool>/
2. Update a-shell-packages/scripts/build-core.sh
3. Add copy step in Xcode build phase
4. Test on device
5. Commit: "feat(app): add <tool> to core"

**Adding WASM support**:
1. Create WASM package in a-shell-packages/packages/wasm/<tool>/
2. Build .wasm file
3. Upload to GitHub releases
4. Update index.json
5. Test: pkg install <tool>

**Fixing terminal UI**:
1. Edit a-Shell/ContentViewTerm.swift
2. Test on device
3. Check hterm integration
4. Commit: "fix(ui): <description>"

## Constraints

- **No JIT**: WebKit only, no custom JIT
- **No fork**: Use threads via kernel
- **Sandbox**: Only ~/Documents/, ~/Library/
- **Signed code**: All native code signed at build
- **Size**: App bundle < 200MB (prefer < 100MB)
- **Network**: HTTPS only

## Testing

### Unit Tests
```bash
# Run Swift tests
xcodebuild test -project a-Shell.xcodeproj -scheme a-Shell
```

### Integration Tests
```bash
# Test core tools
./test-core.sh

# Test package manager
./test-pkg.sh
```

### Device Testing
```bash
# Install on device
xcodebuild -project a-Shell.xcodeproj -scheme a-Shell -destination 'platform=iOS'

# Run manual tests
# - Bash commands
# - File operations
# - Package installation
```

## Documentation

- **App code**: `a-Shell/*.swift`
- **UI**: `a-Shell/ContentView*.swift`
- **Package manager**: `a-Shell/Package/`
- **Build**: Xcode project settings
- **This guide**: `AGENTS.md`

## Integration Checklist

When modifying a layer:

**Kernel changes**:
- [ ] Rebuild a-shell-kernel.xcframework
- [ ] Update framework reference in app
- [ ] Test core tools still work

**Package changes**:
- [ ] Rebuild packages
- [ ] Update app build phase
- [ ] Test on device

**App changes**:
- [ ] Test UI
- [ ] Test built-in tools
- [ ] Test package manager
- [ ] Generate IPA
- [ ] Test on device

---

**Last Updated**: 2026-03-20
**Status**: App structure defined, needs Swift PackageManager implementation
**Next Steps**: 
1. Create SessionManager.swift
2. Create PackageManager.swift
3. Create WasmRuntime.swift
4. Update Xcode build phases
5. Build and test IPA

## Testing via a-Shell App

### Overview

Package tests are executed **inside the a-shell iOS app** rather than on iOS Simulator directly. This provides the strongest validation that packages work in the actual iOS environment with all constraints (sandbox, kernel, etc.).

### Test Architecture

```
Build System                    a-Shell App                    Results
     │                               │                            │
     ├─→ Build test binaries ─────→│                            │
     │   (example, minigzip)       │                            │
     │                               │                            │
     ├─→ Copy to a-shell/ ─────────→│                            │
     │   project resources/          │                            │
     │                               │                            │
     │                          ┌────┴────────────────┐           │
     │                          │ TestRunner.swift   │           │
     │                          │ - Spawns test      │           │
     │                          │ - Captures stdout  │           │
     │                          │ - Writes JSON      │           │
     │                          │   results          │           │
     │                          └────┬────────────────┘           │
     │                               │                            │
     │                          ┌────┴────────────────┐           │
     │                          │ Documents/test/    │◄───────────┤
     │                          │ results/           │  Read JSON │
     │                          └────────────────────┘            │
     │                               │                            │
```

### Why This Approach?

**iOS Simulator Limitations:**
- ❌ Cannot spawn raw command-line binaries
- ❌ Requires app bundles for execution
- ❌ Complex app packaging for each test
- ❌ Security policy blocks unsigned binaries

**a-Shell Testing Advantages:**
- ✅ Runs in actual iOS environment
- ✅ Uses kernel syscall layer (a_shell_fork, etc.)
- ✅ Real sandbox constraints
- ✅ Simple file I/O for results
- ✅ Validates complete integration
- ✅ No app bundle complexity

### Test Binary Locations

**Embedded in app:**
```
a-Shell.app/
├── Resources/
│   └── Tests/
│       ├── libz/
│       │   ├── example
│       │   ├── minigzip
│       │   └── manifest.json
│       ├── libssl/
│       │   └── ...
│       └── ...
└── ...
```

**manifest.json:**
```json
{
  "package": "libz",
  "version": "1.3.2",
  "tests": [
    {
      "name": "example",
      "binary": "example",
      "args": ["/tmp/testfile"]
    },
    {
      "name": "minigzip",
      "binary": "minigzip",
      "args": ["-h"]
    }
  ]
}
```

### Test Runner Implementation

**TestRunner.swift:**
```swift
import Foundation

class TestRunner {
    func runPackageTests(_ package: String) -> TestReport {
        let manifest = loadManifest(for: package)
        var results: [TestResult] = []
        
        for test in manifest.tests {
            let result = runTest(test)
            results.append(result)
        }
        
        // Write results to Documents
        writeResultsToFile(results, for: package)
        
        return TestReport(results: results)
    }
    
    func runTest(_ test: TestConfig) -> TestResult {
        // Spawn via kernel
        let process = Process()
        process.executableURL = test.binaryURL
        process.arguments = test.args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        process.launch()
        process.waitUntilExit()
        
        return TestResult(
            name: test.name,
            status: process.terminationStatus == 0 ? .passed : .failed,
            duration: Date().timeIntervalSince(start),
            output: String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                          encoding: .utf8) ?? ""
        )
    }
    
    func writeResultsToFile(_ results: [TestResult], for package: String) {
        let resultsDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("test-results")
        
        try? FileManager.default.createDirectory(
            at: resultsDir, withIntermediateDirectories: true
        )
        
        let resultFile = resultsDir
            .appendingPathComponent("\(package)-\(ISO8601DateFormatter().string(from: Date())).json")
        
        let report = TestReport(results: results)
        let jsonData = try? JSONEncoder().encode(report)
        try? jsonData?.write(to: resultFile)
    }
}
```

### Result Export

**Written to Documents:**
```
~/Documents/
└── test-results/
    ├── libz-20260321-150000.json
    ├── libssl-20260321-150500.json
    └── ...
```

**JSON Format:**
```json
{
  "package": "libz",
  "timestamp": "2026-03-21T15:00:00Z",
  "target": "ios",
  "results": {
    "total": 2,
    "passed": 2,
    "failed": 0,
    "skipped": 0
  },
  "tests": [
    {
      "name": "example",
      "status": "passed",
      "duration_ms": 150,
      "stdout": "zlib version 1.3.2...",
      "stderr": ""
    },
    {
      "name": "minigzip",
      "status": "passed",
      "duration_ms": 120,
      "stdout": "usage: minigzip...",
      "stderr": ""
    }
  ]
}
```

### Testing Workflow

**Development:**
```bash
# From a-shell-packages/
./scripts/build-package.sh libz --target ios

# Install tests to a-shell
./scripts/install-tests-in-app.sh libz

# Build a-shell with tests
xcodebuild -project a-Shell.xcodeproj -scheme a-Shell

# Run tests (launch app)
xcrun simctl launch booted AsheKube.app.a-Shell

# Retrieve results
cat ~/Library/Developer/CoreSimulator/Devices/.../Documents/test-results/libz-*.json
```

**Manual Testing in App:**
```bash
# In a-shell terminal:
$ run-tests libz
Running libz tests...
✓ example: PASSED
✓ minigzip: PASSED

Results saved to ~/Documents/test-results/libz-20260321-150000.json
```

### UI Integration

**Add to Settings Menu:**
- "Run Package Tests"
- "View Test Results"
- "Export Test Report"

**Test Results View:**
```
┌─────────────────────┐
│ Test Results        │
├─────────────────────┤
│ libz               │
│   ✓ example        │
│   ✓ minigzip       │
│                    │
│ libssl             │
│   ✓ openssl_test   │
│                    │
│ [Export] [Re-run]  │
└─────────────────────┘
```

### Security

- Tests run in a-shell sandbox
- Cannot access files outside Documents/
- No special entitlements needed
- Standard iOS process isolation
- Kernel syscall layer mediates access

### Build System Integration

**scripts/run-tests-in-app.sh:**
```bash
#!/bin/bash
# 1. Build tests for iOS
# 2. Copy to a-shell/Resources/Tests/
# 3. Build a-shell
# 4. Install to Simulator
# 5. Launch test runner
# 6. Wait for completion
# 7. Pull results
# 8. Validate JSON
```

### Next Steps

1. ✅ Document test strategy (DONE)
2. Create TestRunner.swift
3. Add "Run Tests" menu item
4. Create result export UI
5. Integrate with build scripts
6. Test first package (libz)

