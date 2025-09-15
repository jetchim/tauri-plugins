use crate::bridge;
use serde::de::DeserializeOwned;
use std::ffi::{c_char, CStr, CString};
use tauri::{plugin::PluginApi, AppHandle, Runtime};

pub fn init<R: Runtime, C: DeserializeOwned>(
    app: &AppHandle<R>,
    _api: PluginApi<R, C>,
) -> crate::Result<Applekit<R>> {
    Ok(Applekit(app.clone()))
}

/// Access to the applekit APIs.
pub struct Applekit<R: Runtime>(AppHandle<R>);

impl<R: Runtime> Applekit<R> {
    pub fn set_user_default(&self, key: String, value: String) -> crate::Result<()> {
        unsafe {
            let key = CString::new(key.as_str()).unwrap();
            let value = CString::new(value.as_str()).unwrap();
            bridge::set_user_default(key.as_ptr(), value.as_ptr());
        };
        Ok(())
    }

    pub fn get_user_default(&self, key: String) -> crate::Result<Option<String>> {
        let result: Option<String> = unsafe {
            let key = CString::new(key.as_str()).unwrap();
            let result_ptr = bridge::get_user_default(key.as_ptr());
            if result_ptr.is_null() {
                None
            } else {
                Some(take_string(result_ptr))
            }
        };
        Ok(result)
    }

    pub fn save_keychain(&self, key: String, value: String) -> crate::Result<i32> {
        let status = unsafe {
            let key = CString::new(key.as_str()).unwrap();
            let value = CString::new(value.as_str()).unwrap();
            bridge::save_keychain(key.as_ptr(), value.as_ptr())
        };
        Ok(status)
    }

    pub fn load_keychain(&self, key: String) -> crate::Result<Option<String>> {
        let result = unsafe {
            let key = CString::new(key.as_str()).unwrap();
            let result_ptr = bridge::load_keychain(key.as_ptr());
            if result_ptr.is_null() {
                None
            } else {
                Some(take_string(result_ptr))
            }
        };
        Ok(result)
    }
}

unsafe fn take_string(ptr: *const c_char) -> String {
    if ptr.is_null() {
        return String::new();
    }
    // 只读取，不接管所有权
    CStr::from_ptr(ptr).to_string_lossy().into_owned()
}
