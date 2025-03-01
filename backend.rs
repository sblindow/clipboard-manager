
// clipboard_manager/src/main.rs
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use serde::{Serialize, Deserialize};
use std::fs;
use std::path::PathBuf;
use dirs;

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct ClipboardRegister {
    pub content: String,
    pub shortcut: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct ClipboardState {
    registers: HashMap<String, ClipboardRegister>,
}

impl ClipboardState {
    pub fn new() -> Self {
        ClipboardState {
            registers: HashMap::new(),
        }
    }
    
    pub fn add_register(&mut self, name: String, shortcut: String) -> bool {
        if self.registers.contains_key(&name) {
            return false;
        }
        
        self.registers.insert(name, ClipboardRegister {
            content: String::new(),
            shortcut,
        });
        
        self.save_to_disk().unwrap_or_else(|e| {
            eprintln!("Failed to save config: {}", e);
        });
        
        true
    }
    
    pub fn update_register_content(&mut self, name: &str, content: String) -> bool {
        if let Some(register) = self.registers.get_mut(name) {
            register.content = content;
            
            self.save_to_disk().unwrap_or_else(|e| {
                eprintln!("Failed to save config: {}", e);
            });
            
            return true;
        }
        false
    }
    
    pub fn get_register_content(&self, name: &str) -> Option<String> {
        self.registers.get(name).map(|r| r.content.clone())
    }
    
    pub fn remove_register(&mut self, name: &str) -> bool {
        if self.registers.remove(name).is_some() {
            self.save_to_disk().unwrap_or_else(|e| {
                eprintln!("Failed to save config: {}", e);
            });
            return true;
        }
        false
    }
    
    pub fn update_shortcut(&mut self, name: &str, shortcut: String) -> bool {
        if let Some(register) = self.registers.get_mut(name) {
            register.shortcut = shortcut;
            
            self.save_to_disk().unwrap_or_else(|e| {
                eprintln!("Failed to save config: {}", e);
            });
            
            return true;
        }
        false
    }
    
    pub fn get_all_registers(&self) -> Vec<(String, ClipboardRegister)> {
        self.registers.iter()
            .map(|(name, register)| (name.clone(), register.clone()))
            .collect()
    }
    
    fn get_config_path() -> PathBuf {
        let mut path = dirs::home_dir().unwrap_or_default();
        path.push(".clipboard_manager_config.json");
        path
    }
    
    pub fn load_from_disk() -> Result<Self, String> {
        let path = Self::get_config_path();
        
        match fs::read_to_string(&path) {
            Ok(contents) => {
                match serde_json::from_str::<ClipboardState>(&contents) {
                    Ok(state) => Ok(state),
                    Err(e) => Err(format!("Failed to parse config: {}", e))
                }
            },
            Err(_) => Ok(ClipboardState::new())
        }
    }
    
    pub fn save_to_disk(&self) -> Result<(), String> {
        let path = Self::get_config_path();
        
        match serde_json::to_string_pretty(self) {
            Ok(json) => {
                if let Err(e) = fs::write(&path, json) {
                    return Err(format!("Failed to write config: {}", e));
                }
                Ok(())
            },
            Err(e) => Err(format!("Failed to serialize config: {}", e))
        }
    }
}

// This object will be shared with Swift via FFI
pub struct ClipboardManager {
    state: Arc<Mutex<ClipboardState>>,
}

impl ClipboardManager {
    pub fn new() -> Self {
        let state = match ClipboardState::load_from_disk() {
            Ok(state) => state,
            Err(e) => {
                eprintln!("Failed to load config: {}", e);
                ClipboardState::new()
            }
        };
        
        ClipboardManager {
            state: Arc::new(Mutex::new(state)),
        }
    }
    
    // Core functions that will be exposed to Swift
    pub fn add_register(&self, name: &str, shortcut: &str) -> bool {
        let mut state = self.state.lock().unwrap();
        state.add_register(name.to_string(), shortcut.to_string())
    }
    
    pub fn update_register_content(&self, name: &str, content: &str) -> bool {
        let mut state = self.state.lock().unwrap();
        state.update_register_content(name, content.to_string())
    }
    
    pub fn get_register_content(&self, name: &str) -> Option<String> {
        let state = self.state.lock().unwrap();
        state.get_register_content(name)
    }
    
    pub fn remove_register(&self, name: &str) -> bool {
        let mut state = self.state.lock().unwrap();
        state.remove_register(name)
    }
    
    pub fn update_shortcut(&self, name: &str, shortcut: &str) -> bool {
        let mut state = self.state.lock().unwrap();
        state.update_shortcut(name, shortcut.to_string())
    }
    
    pub fn get_all_registers(&self) -> String {
        let state = self.state.lock().unwrap();
        let registers = state.get_all_registers();
        
        match serde_json::to_string(&registers) {
            Ok(json) => json,
            Err(_) => "[]".to_string()
        }
    }
}

// C-compatible FFI functions to expose to Swift
use std::os::raw::{c_char, c_int};
use std::ffi::{CStr, CString};

#[no_mangle]
pub extern "C" fn clipboard_manager_new() -> *mut ClipboardManager {
    Box::into_raw(Box::new(ClipboardManager::new()))
}

#[no_mangle]
pub extern "C" fn clipboard_manager_destroy(manager: *mut ClipboardManager) {
    if !manager.is_null() {
        unsafe { Box::from_raw(manager); }
    }
}

#[no_mangle]
pub extern "C" fn clipboard_manager_add_register(
    manager: *mut ClipboardManager,
    name: *const c_char,
    shortcut: *const c_char
) -> c_int {
    let manager = unsafe {
        assert!(!manager.is_null());
        &*manager
    };
    
    let name = unsafe {
        assert!(!name.is_null());
        CStr::from_ptr(name).to_str().unwrap_or("")
    };
    
    let shortcut = unsafe {
        assert!(!shortcut.is_null());
        CStr::from_ptr(shortcut).to_str().unwrap_or("")
    };
    
    if manager.add_register(name, shortcut) { 1 } else { 0 }
}

#[no_mangle]
pub extern "C" fn clipboard_manager_update_register_content(
    manager: *mut ClipboardManager,
    name: *const c_char,
    content: *const c_char
) -> c_int {
    let manager = unsafe {
        assert!(!manager.is_null());
        &*manager
    };
    
    let name = unsafe {
        assert!(!name.is_null());
        CStr::from_ptr(name).to_str().unwrap_or("")
    };
    
    let content = unsafe {
        assert!(!content.is_null());
        CStr::from_ptr(content).to_str().unwrap_or("")
    };
    
    if manager.update_register_content(name, content) { 1 } else { 0 }
}

#[no_mangle]
pub extern "C" fn clipboard_manager_get_register_content(
    manager: *mut ClipboardManager,
    name: *const c_char
) -> *mut c_char {
    let manager = unsafe {
        assert!(!manager.is_null());
        &*manager
    };
    
    let name = unsafe {
        assert!(!name.is_null());
        CStr::from_ptr(name).to_str().unwrap_or("")
    };
    
    match manager.get_register_content(name) {
        Some(content) => {
            match CString::new(content) {
                Ok(c_str) => c_str.into_raw(),
                Err(_) => std::ptr::null_mut()
            }
        },
        None => std::ptr::null_mut()
    }
}

#[no_mangle]
pub extern "C" fn clipboard_manager_remove_register(
    manager: *mut ClipboardManager,
    name: *const c_char
) -> c_int {
    let manager = unsafe {
        assert!(!manager.is_null());
        &*manager
    };
    
    let name = unsafe {
        assert!(!name.is_null());
        CStr::from_ptr(name).to_str().unwrap_or("")
    };
    
    if manager.remove_register(name) { 1 } else { 0 }
}

#[no_mangle]
pub extern "C" fn clipboard_manager_update_shortcut(
    manager: *mut ClipboardManager,
    name: *const c_char,
    shortcut: *const c_char
) -> c_int {
    let manager = unsafe {
        assert!(!manager.is_null());
        &*manager
    };
    
    let name = unsafe {
        assert!(!name.is_null());
        CStr::from_ptr(name).to_str().unwrap_or("")
    };
    
    let shortcut = unsafe {
        assert!(!shortcut.is_null());
        CStr::from_ptr(shortcut).to_str().unwrap_or("")
    };
    
    if manager.update_shortcut(name, shortcut) { 1 } else { 0 }
}

#[no_mangle]
pub extern "C" fn clipboard_manager_get_all_registers(
    manager: *mut ClipboardManager
) -> *mut c_char {
    let manager = unsafe {
        assert!(!manager.is_null());
        &*manager
    };
    
    let json = manager.get_all_registers();
    
    match CString::new(json) {
        Ok(c_str) => c_str.into_raw(),
        Err(_) => std::ptr::null_mut()
    }
}

#[no_mangle]
pub extern "C" fn clipboard_manager_free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe { CString::from_raw(s); }
    }
}

fn main() {
    println!("Clipboard Manager Library loaded");
    // This is just a placeholder for testing
    // The actual functionality will be used from Swift via FFI
}
