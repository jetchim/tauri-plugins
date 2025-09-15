use tauri::{
    plugin::{Builder, TauriPlugin},
    Manager, Runtime,
};

pub use models::*;

#[cfg(desktop)]
mod desktop;
#[cfg(mobile)]
mod mobile;

mod bridge;
mod commands;
mod error;
mod models;

pub use error::{Error, Result};

#[cfg(desktop)]
use desktop::Applekit;
#[cfg(mobile)]
use mobile::Applekit;

/// Extensions to [`tauri::App`], [`tauri::AppHandle`] and [`tauri::Window`] to access the applekit APIs.
pub trait ApplekitExt<R: Runtime> {
    fn applekit(&self) -> &Applekit<R>;
}

impl<R: Runtime, T: Manager<R>> crate::ApplekitExt<R> for T {
    fn applekit(&self) -> &Applekit<R> {
        self.state::<Applekit<R>>().inner()
    }
}

/// Initializes the plugin.
pub fn init<R: Runtime>() -> TauriPlugin<R> {
    Builder::new("applekit")
        .invoke_handler(tauri::generate_handler![
            commands::set_user_default,
            commands::get_user_default,
            commands::save_keychain,
            commands::load_keychain,
        ])
        .setup(|app, api| {
            #[cfg(mobile)]
            let applekit = mobile::init(app, api)?;
            #[cfg(desktop)]
            let applekit = desktop::init(app, api)?;
            app.manage(applekit);
            Ok(())
        })
        .build()
}
