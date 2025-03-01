import Foundation

// Structure to represent a clipboard register in Swift
struct ClipboardRegister: Codable, Identifiable {
    var id: String { name }
    let name: String
    var content: String
    var shortcut: String
}

// FFI bindings to Rust functions
class ClipboardManagerFFI {
    private var handle: UnsafeMutableRawPointer
    
    init() {
        // Load the library and create a new manager instance
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
        
        do {
            // First attempt to parse as an array of tuples
            if let jsonArray = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [[Any]] {
                return jsonArray.compactMap { item -> ClipboardRegister? in
                    guard let name = item[0] as? String,
                          let registerDict = item[1] as? [String: Any],
                          let content = registerDict["content"] as? String,
                          let shortcut = registerDict["shortcut"] as? String
                    else {
                        return nil
                    }
                    
                    return ClipboardRegister(name: name, content: content, shortcut: shortcut)
                }
            }
            
            // If that fails, try direct decoding (for future compatibility)
            return try JSONDecoder().decode([ClipboardRegister].self, from: jsonData)
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
