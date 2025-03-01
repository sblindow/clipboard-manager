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
                Button("Add Register") {
                    NSApp.sendAction(#selector(ContentView.addRegister), to: nil, from: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
            
            CommandMenu("Registers") {
                ForEach(clipboardManager.registers) { register in
                    Button(register.name) {
                        clipboardManager.copyToClipboard(content: register.content)
                    }
                    .disabled(register.content.isEmpty)
                    if !register.shortcut.isEmpty {
                        Text(register.shortcut)
                    }
                }
            }
        }
    }
}

// Status bar menu for quick access
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var clipboardManager: ClipboardManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarItem()
    }
    
    func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "📋"
        
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Open Clipboard Manager", action: #selector(openApp), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        
        if let registers = clipboardManager?.registers, !registers.isEmpty {
            for register in registers {
                let item = NSMenuItem(title: register.name, action: #selector(copyFromRegister(_:)), keyEquivalent: "")
                item.representedObject = register.name
                menu.addItem(item)
            }
            menu.addItem(NSMenuItem.separator())
        }
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func openApp() {
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func copyFromRegister(_ sender: NSMenuItem) {
        if let name = sender.representedObject as? String {
            clipboardManager?.copyFromRegister(name: name)
        }
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

// Extension to ClipboardManager to easily access register content
extension ClipboardManager {
    func copyFromRegister(name: String) {
        if let content = ffi.getRegisterContent(name: name) {
            copyToClipboard(content: content)
        }
    }
}
