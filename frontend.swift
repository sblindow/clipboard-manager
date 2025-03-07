import SwiftUI
import Combine
import Carbon

// MARK: - Main View
struct ContentView: View {
    @EnvironmentObject private var clipboardManager: ClipboardManager
    @State private var showingAddRegister = false
    @State private var editingRegisterName: String?
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with title and buttons
            HStack {
                Text("Clipboard Manager")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                Button(action: { showSettings = true }) {
                    Image(systemName: "gear")
                        .font(.title2)
                }
                .buttonStyle(.borderless)

                Button(action: { showingAddRegister = true }) {
                    Image(systemName: "plus")
                        .font(.title2)
                }
                .keyboardShortcut("n", modifiers: [.command])
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            // Registers list
            List {
                ForEach(clipboardManager.registers) { register in
                    RegisterRow(register: register, isEditing: editingRegisterName == register.name) { newShortcut in
                        clipboardManager.updateShortcut(name: register.name, shortcut: newShortcut)
                        editingRegisterName = nil
                    } onEdit: {
                        editingRegisterName = register.name
                    } onDelete: {
                        clipboardManager.removeRegister(name: register.name)
                    } onCopy: {
                        clipboardManager.copyToClipboard(content: register.content)
                    } onContentEdit: { newContent in
                        clipboardManager.updateRegisterContent(name: register.name, content: newContent)
                    }
                }
            }
            .listStyle(InsetListStyle())

            // Status bar at bottom
            HStack {
                Text("\(clipboardManager.registers.count) registers")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("Default register: \(clipboardManager.hasDefaultRegister ? "Active" : "Not set")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 600, minHeight: 400)
        .sheet(isPresented: $showingAddRegister) {
            AddRegisterView(isPresented: $showingAddRegister) { name, shortcut in
                clipboardManager.addRegister(name: name, shortcut: shortcut)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(isPresented: $showSettings)
        }
    }

    @objc func addRegister() {
        showingAddRegister = true
    }
}

// MARK: - Register Row
struct RegisterRow: View {
    let register: ClipboardRegister
    let isEditing: Bool
    let onShortcutChange: (String) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onCopy: () -> Void
    let onContentEdit: (String) -> Void

    @State private var editedShortcut: String = ""
    @State private var showContentEditor = false
    @State private var editedContent: String = ""

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(register.name)
                        .font(.headline)

                    Text("Shortcut: \(register.shortcut)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isEditing {
                    TextField("Shortcut", text: $editedShortcut)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 150)
                        .onAppear {
                            editedShortcut = register.shortcut
                        }

                    Button("Save") {
                        onShortcutChange(editedShortcut)
                    }
                    .buttonStyle(.borderedProminent)

                } else {
                    Button(action: onCopy) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)

                    Button(action: {
                        editedContent = register.content
                        showContentEditor = true
                    }) {
                        Image(systemName: "text.quote")
                    }
                    .buttonStyle(.borderless)

                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }

            Text(register.content.isEmpty ? "Empty register" : String(register.content.prefix(100) + (register.content.count > 100 ? "..." : "")))
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showContentEditor) {
            VStack(spacing: 16) {
                Text("Edit Content for '\(register.name)'")
                    .font(.headline)

                TextEditor(text: $editedContent)
                    .font(.body)
                    .frame(minHeight: 200)
                    .border(Color.gray.opacity(0.2))

                HStack {
                    Button("Cancel") {
                        showContentEditor = false
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button("Save") {
                        onContentEdit(editedContent)
                        showContentEditor = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .frame(width: 500, height: 300)
        }
    }
}

// MARK: - Add Register View
struct AddRegisterView: View {
    @Binding var isPresented: Bool
    let onAdd: (String, String) -> Void

    @State private var registerName = ""
    @State private var shortcut = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Add New Register")
                .font(.headline)

            TextField("Register Name", text: $registerName)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("Shortcut (e.g., cmd+shift+1)", text: $shortcut)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    if !registerName.isEmpty && !shortcut.isEmpty {
                        // Validate shortcut format
                        if shortcut.lowercased().contains("cmd") ||
                           shortcut.lowercased().contains("command") ||
                           shortcut.lowercased().contains("shift") ||
                           shortcut.lowercased().contains("alt") ||
                           shortcut.lowercased().contains("ctrl") {
                            onAdd(registerName, shortcut)
                            isPresented = false
                        } else {
                            errorMessage = "Shortcut must include at least one modifier key (cmd, shift, alt, ctrl)"
                        }
                    } else {
                        errorMessage = "Both fields are required"
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(registerName.isEmpty || shortcut.isEmpty)
            }
        }
        .padding()
        .frame(width: 350)
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var clipboardManager: ClipboardManager
    @State private var monitorClipboard: Bool = true
    @State private var useDefaultRegister: Bool = true

    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.title)
                .fontWeight(.bold)

            Form {
                Section(header: Text("General")) {
                    Toggle("Monitor system clipboard", isOn: $monitorClipboard)
                        .onChange(of: monitorClipboard) { newValue in
                            clipboardManager.setClipboardMonitoring(enabled: newValue)
                        }

                    Toggle("Use default register for system clipboard", isOn: $useDefaultRegister)
                        .disabled(!monitorClipboard)
                        .onChange(of: useDefaultRegister) { newValue in
                            if newValue && !clipboardManager.hasDefaultRegister {
                                clipboardManager.addRegister(name: "default", shortcut: "")
                            } else if !newValue && clipboardManager.hasDefaultRegister {
                                clipboardManager.removeRegister(name: "default")
                            }
                        }
                }

                Section(header: Text("Shortcuts")) {
                    VStack(alignment: .leading) {
                        Text("Global Menu Shortcut")
                        Text("cmd+shift+V")
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading) {
                        Text("Add New Register")
                        Text("cmd+N")
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("About")) {
                    VStack(alignment: .leading) {
                        Text("Clipboard Manager v0.1.0")
                        Text("A native macOS clipboard manager with multiple registers")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Button("Close") {
                isPresented = false
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
        .frame(width: 400, height: 400)
        .onAppear {
            monitorClipboard = clipboardManager.isMonitoringClipboard
            useDefaultRegister = clipboardManager.hasDefaultRegister
        }
    }
}

// MARK: - Enhanced Clipboard Manager
class ClipboardManager: ObservableObject {
    @Published var registers: [ClipboardRegister] = []
    private let ffi = ClipboardManagerFFI()
    private let pasteboard = NSPasteboard.general
    private var lastPasteboardCount = 0
    private var monitorTimer: Timer?
    private var hotkeys: [UInt: String] = [:]
    private var isMonitoringEnabled = true

    var isMonitoringClipboard: Bool {
        return isMonitoringEnabled
    }

    var hasDefaultRegister: Bool {
        return registers.contains { $0.name == "default" }
    }

    init() {
        loadRegisters()
        setupClipboardMonitoring()
        setupGlobalHotkeys()
    }

    private func loadRegisters() {
        registers = ffi.getAllRegisters()
    }

    func addRegister(name: String, shortcut: String) {
        if ffi.addRegister(name: name, shortcut: shortcut) {
            loadRegisters()
            if !shortcut.isEmpty {
                registerHotkey(for: name, shortcut: shortcut)
            }
        }
    }

    func updateRegisterContent(name: String, content: String) {
        if ffi.updateRegisterContent(name: name, content: content) {
            loadRegisters()
        }
    }

    func removeRegister(name: String) {
        if ffi.removeRegister(name: name) {
            // Find and unregister hotkey if it exists
            if let index = registers.firstIndex(where: { $0.name == name }) {
                unregisterHotkey(for: registers[index].shortcut)
            }
            loadRegisters()
        }
    }

    func updateShortcut(name: String, shortcut: String) {
        // Find old shortcut to unregister
        if let index = registers.firstIndex(where: { $0.name == name }) {
            unregisterHotkey(for: registers[index].shortcut)
        }

        if ffi.updateShortcut(name: name, shortcut: shortcut) {
            loadRegisters()
            if !shortcut.isEmpty {
                registerHotkey(for: name, shortcut: shortcut)
            }
        }
    }

    func setClipboardMonitoring(enabled: Bool) {
        isMonitoringEnabled = enabled

        if enabled {
            setupClipboardMonitoring()
        } else if let timer = monitorTimer {
            timer.invalidate()
            monitorTimer = nil
        }
    }

    private func setupClipboardMonitoring() {
        // Invalidate existing timer if any
        if let timer = monitorTimer {
            timer.invalidate()
        }

        guard isMonitoringEnabled else { return }

        lastPasteboardCount = pasteboard.changeCount

        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let currentCount = self.pasteboard.changeCount
            if currentCount != self.lastPasteboardCount {
                self.lastPasteboardCount = currentCount

                // Get the current clipboard content
                if let clipboardString = self.pasteboard.string(forType: .string) {
                    // Store in a register named "default" if it exists
                    if self.registers.contains(where: { $0.name == "default" }) {
                        self.updateRegisterContent(name: "default", content: clipboardString)
                    }
                }
            }
        }
    }

    func copyToClipboard(content: String) {
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }

    // MARK: - Hotkey Management
    // (Implementation remains the same as your original code)

    private func setupGlobalHotkeys() {
        for register in registers {
            if !register.shortcut.isEmpty {
                registerHotkey(for: register.name, shortcut: register.shortcut)
            }
        }
    }

    private func registerHotkey(for registerName: String, shortcut: String) {
        // Parse shortcut string (e.g., "cmd+shift+1")
        let components = shortcut.lowercased().split(separator: "+")

        var keyCode: UInt = 0
        var modifiers: UInt = 0

        for component in components {
            let comp = String(component)

            switch comp {
            case "cmd", "command":
                modifiers |= UInt(cmdKey)
            case "shift":
                modifiers |= UInt(shiftKey)
            case "alt", "option":
                modifiers |= UInt(optionKey)
            case "ctrl", "control":
                modifiers |= UInt(controlKey)
            default:
                // Assign key code based on the character
                if comp.count == 1, let firstChar = comp.first {
                    // Simple mapping for single characters and numbers
                    if let asciiValue = firstChar.asciiValue {
                        // Very simplified mapping - in a real app would use a proper key code mapping
                        if firstChar.isNumber {
                            // Number keys 0-9 (ASCII 48-57)
                            keyCode = UInt(asciiValue - 48 + 18)  // Approximate mapping to virtual key codes
                        } else if firstChar.isLetter {
                            // Letter keys (ASCII 97-122 for lowercase)
                            keyCode = UInt(asciiValue - 97 + 0)  // Approximate mapping to virtual key codes
                        }
                    }
                } else if let functionKeyNumber = Int(comp.replacingOccurrences(of: "f", with: "")) {
                    // Function keys F1-F12
                    keyCode = UInt(functionKeyNumber + 122 - 1)  // F1 is typically 122
                }
            }
        }

        if keyCode > 0 {
            // Create a unique ID for this hotkey
            let hotkeyID = (keyCode << 16) | modifiers
            hotkeys[hotkeyID] = registerName

            // Register for the hotkey using Carbon API
            var eventHotKeyRef: EventHotKeyRef?
            var gMyHotKeyID = EventHotKeyID()
            gMyHotKeyID.signature = OSType(keyCode)
            gMyHotKeyID.id = UInt32(modifiers)

            // Register the hotkey
            let hotKeyFunction: EventHandlerProcPtr = { (nextHandler, theEvent, userData) -> OSStatus in
                // This would be a callback when the hotkey is pressed
                let hotkeyManager = Unmanaged<ClipboardManager>.fromOpaque(userData!).takeUnretainedValue()

                var eventHotKeyID = EventHotKeyID()
                GetEventParameter(theEvent,
                                EventParamName(kEventParamDirectObject),
                                EventParamType(typeEventHotKeyID),
                                nil,
                                MemoryLayout<EventHotKeyID>.size,
                                nil,
                                &eventHotKeyID)

                let hotkeyID = (UInt(eventHotKeyID.signature) << 16) | UInt(eventHotKeyID.id)

                if let registerName = hotkeyManager.hotkeys[hotkeyID],
                let content = hotkeyManager.ffi.getRegisterContent(name: registerName) {
                    DispatchQueue.main.async {
                        hotkeyManager.copyToClipboard(content: content)
                    }
                }

                return noErr
            }

            var eventType = EventTypeSpec()
            eventType.eventClass = OSType(kEventClassKeyboard)
            eventType.eventKind = OSType(kEventHotKeyPressed)

            var eventHandler: EventHandlerRef?
            InstallEventHandler(GetApplicationEventTarget(),
                                hotKeyFunction,
                                1,
                                &eventType,
                                Unmanaged.passUnretained(self).toOpaque(),
                                &eventHandler)

            RegisterEventHotKey(UInt32(keyCode),
                                UInt32(modifiers),
                                gMyHotKeyID,
                                GetApplicationEventTarget(),
                                0,
                                &eventHotKeyRef)
        }
    }

    private func unregisterHotkey(for shortcut: String) {
        // In a real app, you would need to store eventHotKeyRef and eventHandler
    // for each registered hotkey and unregister them here.
    // This is a simplified version that just removes it from our tracking map

    // Parse shortcut string to get keyCode and modifiers
    let components = shortcut.lowercased().split(separator: "+")

    var keyCode: UInt = 0
    var modifiers: UInt = 0

    // Parse the same way as in registerHotkey
    for component in components {
        let comp = String(component)

        switch comp {
        case "cmd", "command":
            modifiers |= UInt(cmdKey)
        case "shift":
            modifiers |= UInt(shiftKey)
        case "alt", "option":
            modifiers |= UInt(optionKey)
        case "ctrl", "control":
            modifiers |= UInt(controlKey)
        default:
            if comp.count == 1, let firstChar = comp.first {
                if let asciiValue = firstChar.asciiValue {
                    if firstChar.isNumber {
                        keyCode = UInt(asciiValue - 48 + 18)
                    } else if firstChar.isLetter {
                        keyCode = UInt(asciiValue - 97 + 0)
                    }
                }
            } else if let functionKeyNumber = Int(comp.replacingOccurrences(of: "f", with: "")) {
                keyCode = UInt(functionKeyNumber + 122 - 1)
            }
        }
    }

    if keyCode > 0 {
        // Find and remove from our tracking map
        let hotkeyID = (keyCode << 16) | modifiers
        hotkeys.removeValue(forKey: hotkeyID)

        // In a complete implementation, you would also call UnregisterEventHotKey here
    }
}
