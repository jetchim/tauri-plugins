use crate::ApplekitExt;
use crate::Result;
use cocoa::appkit::NSEvent;
use cocoa::base::id;
use tauri::{command, AppHandle, Manager, Runtime};

#[command]
pub(crate) async fn set_user_default<R: Runtime>(
    app: AppHandle<R>,
    key: String,
    value: String,
) -> Result<()> {
    let applekit = app.applekit();
    applekit.set_user_default(key, value)
}

#[command]
pub(crate) async fn get_user_default<R: Runtime>(
    app: AppHandle<R>,
    key: String,
) -> Result<Option<String>> {
    let applekit = app.applekit();
    applekit.get_user_default(key)
}

#[command]
pub(crate) async fn save_keychain<R: Runtime>(
    app: AppHandle<R>,
    key: String,
    value: String,
) -> Result<bool> {
    let applekit = app.applekit();
    applekit.save_keychain(key, value).map(|s| s == 1)
}

#[command]
pub(crate) async fn load_keychain<R: Runtime>(
    app: AppHandle<R>,
    key: String,
) -> Result<Option<String>> {
    let applekit = app.applekit();
    applekit.load_keychain(key)
}

#[command]
pub(crate) async fn set_theme<R: Runtime>(
    app: AppHandle<R>,
    theme: Option<tauri_utils::Theme>,
) -> Result<()> {
    let applekit = app.applekit();
    applekit.set_theme(theme)?;
    Ok(())
}

#[command]
pub(crate) async fn show_hud<R: Runtime>(app: AppHandle<R>, label: String) -> Result<()> {
    let applekit = app.applekit();
    let win = app
        .get_webview_window(&label)
        .expect("unable to get web view window");
    let window_num = unsafe {
        let window_handle: id = win.ns_window().unwrap() as _;
        window_handle.windowNumber()
    };
    applekit.show_hud(window_num as isize)?;
    Ok(())
}

#[command]
pub(crate) async fn close_hud<R: Runtime>(app: AppHandle<R>, label: String) -> Result<()> {
    let applekit = app.applekit();
    let win = app
        .get_webview_window(&label)
        .expect("unable o get web view window");
    let window_num = unsafe {
        let window_handle: id = win.ns_window().unwrap() as _;
        window_handle.windowNumber()
    };
    applekit.close_hud(window_num as isize)?;
    Ok(())
}
