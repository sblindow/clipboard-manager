
// ClipboardManager-Swift/ClipboardManager/RustBindings.swift

import Foundation

// Structure to represent a clipboard register in Swift
struct ClipboardRegister: Codable, Identifiable {
    var id: String { name }
    let name: String
    var content: String
    var shortcut: String
}

// C function declarations for the Rust FFI
private class RustBindings {
    static func loadLibrary() {
        // In a real application, you would embed the dylib in the app bundle
        // This is just for development purposes
        let libraryPath = "/path/to/libclipboard_manager.dylib"
        dlopen(libraryPath, RTLD_LAZY)
    }
    
    static let shared = RustBindings()
    
    private init() {
        RustBindings.loadLibrary()
    }
}

// ClipboardManagerFFI.swift
import Foundation

// FFI bindings to Rust functions
class ClipboardManagerFFI {
    private var handle: UnsafeMutableRawPointer
    
    init() {
        handle = clipboard_manager_new()
    }
    
    deinit {
        clipboard_manager_destroy(handle)
    }
    
    func addRegister(name: String, shortcut: String) -> Bool {
        let cName = name.cString(using: .utf8)!
        let cShortcut = shortcut.cString(using: .utf8)!
        
        return clipboard_manager_add_register(handle, cName, cShortcut) != 0
    }
    
    func updateRegisterContent(name: String, content: String) -> Bool {
        let cName = name.cString(using: .utf8)!
        let cContent = content.cString(using: .utf8)!
        
        return clipboard_manager_update_register_content(handle, cName, cContent) != 0
    }
    
    func getRegisterContent(name: String) -> String? {
        let cName = name.cString(using: .utf8)!
        
        guard let cContent = clipboard_manager_get_register_content(handle, cName) else {
            return nil
        }
        
        defer { clipboard_manager_free_string(cContent) }
        return String(cString: cContent)
    }
    
    func removeRegister(name: String) -> Bool {
        let cName = name.cString(using: .utf8)!
        
        return clipboard_manager_remove_register(handle, cName) != 0
    }
    
    func updateShortcut(name: String, shortcut: String) -> Bool {
        let cName = name.cString(using: .utf8)!
        let cShortcut = shortcut.cString(using: .utf8)!
        
        return clipboard_manager_update_shortcut(handle, cName, cShortcut) != 0
    }
    
    func getAllRegisters() -> [ClipboardRegister] {
        guard let cJson = clipboard_manager_get_all_registers(handle) else {
            return []
        }
        
        defer { clipboard_manager_free_string(cJson) }
        let jsonString = String(cString: cJson)
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            return []
        }
        
        // The JSON is an array of tuples (name, register)
        // We need to transform this into ClipboardRegister objects
        do {
            let jsonArray = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [[Any]]
            
            return jsonArray?.compactMap { item -> ClipboardRegister? in
                guard let name = item[0] as? String,
                      let registerDict = item[1] as? [String: Any],
                      let content = registerDict["content"] as? String,
                      let shortcut = registerDict["shortcut"] as? String
                else {
                    return nil
                }
                
                return ClipboardRegister(name: name, content: content, shortcut: shortcut)
            } ?? []
        } catch {
            print("Error parsing JSON: \(error)")
            return []
        }
    }
}

// Foreign function interface declarations
@_cdecl("clipboard_manager_new")
func clipboard_manager_new() -> UnsafeMutableRawPointer

@_cdecl("clipboard_manager_destroy")
func clipboard_manager_destroy(_ manager: UnsafeMutableRawPointer)

@_cdecl("clipboard_manager_add_register")
func clipboard_manager_add_register(_ manager: UnsafeMutableRawPointer, _ name: UnsafePointer<CChar>, _ shortcut: UnsafePointer<CChar>) -> Int32

@_cdecl("clipboard_manager_update_register_content")
func clipboard_manager_update_register_content(_ manager: UnsafeMutableRawPointer, _ name: UnsafePointer<CChar>, _ content: UnsafePointer<CChar>) -> Int32

@_cdecl("clipboard_manager_get_register_content")
func clipboard_manager_get_register_content(_ manager: UnsafeMutableRawPointer, _ name: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?

@_cdecl("clipboard_manager_remove_register")
func clipboard_manager_remove_register(_ manager: UnsafeMutableRawPointer, _ name: UnsafePointer<CChar>) -> Int32

@_cdecl("clipboard_manager_update_shortcut")
func clipboard_manager_update_shortcut(_ manager: UnsafeMutableRawPointer, _ name: UnsafePointer<CChar>, _ shortcut: UnsafePointer<CChar>) -> Int32

@_cdecl("clipboard_manager_get_all_registers")
func clipboard_manager_get_all_registers(_ manager: UnsafeMutableRawPointer) -> UnsafeMutablePointer<CChar>?

@_cdecl("clipboard_manager_free_string")
func clipboard_manager_free_string(_ s: UnsafeMutablePointer<CChar>?)

// ClipboardManager.swift
import SwiftUI
import Combine
import Carbon

class ClipboardManager: ObservableObject {
    @Published var registers: [ClipboardRegister] = []
    private let ffi = ClipboardManagerFFI()
    private let pasteboard = NSPasteboard.general
    private var lastPasteboardCount = 0
    private var monitorTimer: Timer?
    private var hotkeys: [UInt: String] = [:]
    
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
            registerHotkey(for: name, shortcut: shortcut)
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
            registerHotkey(for: name, shortcut: shortcut)
        }
    }
    
    private func setupClipboardMonitoring() {
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
    
    private func setupGlobalHotkeys() {
        for register in registers {
            registerHotkey(for: register.name, shortcut: register.shortcut)
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
                // In a real app, this would need to dispatch back to our Swift code
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
            
            // In a real app, you would need to store eventHotKeyRef and eventHandler to unregister later
        }
    }
    
    private func unregisterHotkey(for shortcut: String) {
        // This is a placeholder - in a real app you would need to find the eventHotKeyRef
        // that corresponds to this shortcut and call UnregisterEventHotKey
    }
}

// ClipboardManagerApp.swift
import SwiftUI

@main
struct ClipboardManagerApp: App {
    @StateObject private var clipboardManager = ClipboardManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(clipboardManager)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) {
                // Custom menu items
                Button("Add Register") {
                    NSApp.sendAction(#selector(ContentView.addRegister), to: nil, from: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
    }
}

// ContentView.swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var clipboardManager: ClipboardManager
    @State private var showingAddRegister = false
    @State private var newRegisterName = ""
    @State private var newRegisterShortcut = ""
    @State private var editingRegisterName: String?
    
    var body: some View {
        VStack {
            HStack {
                Text("Clipboard Manager")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { showingAddRegister = true }) {
                    Image(systemName: "plus")
                        .font(.title2)
                }
                .keyboardShortcut("n", modifiers: [.command])
                .buttonStyle(.borderless)
            }
            .padding()
            
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
                    }
                }
            }
            .listStyle(InsetListStyle())
        }
        .frame(minWidth: 500, minHeight: 400)
        .sheet(isPresented: $showingAddRegister) {
            AddRegisterView(isPresented: $showingAddRegister) { name, shortcut in
                clipboardManager.addRegister(name: name, shortcut: shortcut)
            }
        }
    }
    
    @objc func addRegister() {
        showingAddRegister = true
    }
}

struct RegisterRow: View {
    let register: ClipboardRegister
    let isEditing: Bool
    let onShortcutChange: (String) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onCopy: () -> Void
    
    @State private var editedShortcut: String = ""
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(register.name)
                    .font(.headline)
                
                Text(register.content.prefix(50) + (register.content.count > 50 ? "..." : ""))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if isEditing {
                TextField("Shortcut", text: $editedShortcut)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
                    .onAppear {
                        editedShortcut = register.shortcut
                    }
                
                Button("Save") {
                    onShortcutChange(editedShortcut)
                }
                .buttonStyle(.borderedProminent)
                
            } else {
                Text(register.shortcut)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddRegisterView: View {
    @Binding var isPresented: Bool
    let onAdd: (String, String) -> Void
    
    @State private var registerName = ""
    @State private var shortcut = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add New Register")
                .font(.headline)
            
            TextField("Register Name", text: $registerName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("Shortcut (e.g., cmd+shift+1)", text: $shortcut)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add") {
                    if !registerName.isEmpty && !shortcut.Button("Add") {
                    if !registerName.isEmpty && !shortcut.isEmpty {
                        onAdd(registerName, shortcut)
                        isPresented = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(registerName.isEmpty || shortcut.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let clipboardManager = ClipboardManager()
        ContentView()
            .environmentObject(clipboardManager)
    }
}
