use std::ffi::c_char;

extern "C" {
    pub(crate) fn set_user_default(key: *const c_char, value: *const c_char) -> *const c_char;
    pub(crate) fn get_user_default(key: *const c_char) -> *const c_char;

    pub(crate) fn save_keychain(key: *const c_char, value: *const c_char) -> i32;
    pub(crate) fn load_keychain(key: *const c_char) -> *const c_char;

    pub(crate) fn show_hud(window_id: isize);
    pub(crate) fn close_hud(window_id: isize);
}
