
# macOS Clipboard Manager - Setup & Usage Instructions

This project creates a macOS clipboard manager using Rust for the core logic and Swift for the native UI. The application lets you define multiple clipboard "registers" and assign keyboard shortcuts to quickly copy stored content.

## Project Structure

- **Rust Backend**: Handles the data management and persistence
- **Swift Frontend**: Creates a native macOS application with proper UI

## Setup Instructions

### 1. Set up the Rust Library

First, create a new Rust library project:

```bash
cargo new --lib clipboard_manager
cd clipboard_manager
```

Replace the `Cargo.toml` file with the provided one and the contents of `src/lib.rs` with the Rust code.

Build the Rust library:

```bash
cargo build --release
```

The compiled library will be in `target/release/libclipboard_manager.dylib`.

### 2. Set up the Swift Application

Create a new macOS SwiftUI application in Xcode:

```bash
# Using Xcode UI or command line
mkdir -p ClipboardManager-Swift
cd ClipboardManager-Swift
xcodegen generate  # If you have XcodeGen installed
# Or create manually via Xcode
```

Create the Swift files as shown in the provided code. Important files:

- `RustBindings.swift` - FFI interfaces to Rust
- `ClipboardManager.swift` - Core clipboard management logic
- `ContentView.swift` - Main UI
- `RegisterRow.swift` - UI components for registers
- `AddRegisterView.swift` - UI for adding new registers

### 3. Link Rust Library to Swift

Update your Xcode project settings:

1. Add the path to the Rust library (`libclipboard_manager.dylib`) in "Build Phases" > "Link Binary With Libraries"
2. Add a "Copy Files" build phase to include the dylib in your app bundle:
   - Destination: Frameworks
   - Add the dylib file

### 4. Build and Run

Build the Swift application in Xcode and run it.

## Usage Guide

### First-time Setup

1. Launch the application
2. Click the "+" button or use Cmd+N to add a new register
3. Give the register a name (e.g., "Code Snippets")
4. Assign a shortcut (e.g., "cmd+shift+1")

### Adding Content to Registers

There are two ways to populate registers:

1. **Manual**: Select a register and paste content directly
2. **From Clipboard**: Copy content normally, then use the app to save it to a specific register

### Using Registers

Once configured, you can:

1. Press your assigned keyboard shortcut to copy the register's content to the clipboard
2. Click the "Copy" button next to any register in the app to copy its content

### Editing and Managing Registers

- Click the pencil icon to edit a register's shortcut
- Click the trash icon to delete a register

## Advanced Features

- The "default" register (if you create one) automatically updates with the system clipboard
- Multiple registers can be created for different types of content
- All registers persist across application restarts

## Troubleshooting

- If shortcuts don't work, check System Preferences > Security & Privacy > Privacy > Accessibility and add the application
- If the app fails to start, verify that the Rust library is correctly linked and included in the app bundle
