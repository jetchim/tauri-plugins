use crate::ApplekitExt;
use crate::Result;
use tauri::{command, AppHandle, Runtime};

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
