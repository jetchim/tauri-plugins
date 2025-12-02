use std::os::raw::{c_char, c_int};
use tauri::{plugin::{Builder, TauriPlugin}, AppHandle, Manager, Runtime};

pub use models::*;

#[cfg(desktop)]
pub mod desktop;
#[cfg(mobile)]
mod mobile;

mod commands;
mod error;
mod models;

pub use error::{Error, Result};

#[cfg(desktop)]
use desktop::Storekit2;
#[cfg(mobile)]
use mobile::Storekit2;
use crate::desktop::{set_event_handler, IapPayload};

/// Extensions to [`tauri::App`], [`tauri::AppHandle`] and [`tauri::Window`] to access the storekit2 APIs.
pub trait Storekit2Ext<R: Runtime> {
    fn storekit2(&self) -> &Storekit2<R>;
}

impl<R: Runtime, T: Manager<R>> crate::Storekit2Ext<R> for T {
    fn storekit2(&self) -> &Storekit2<R> {
        self.state::<Storekit2<R>>().inner()
    }
}

/// Initializes the plugin.
pub fn init<R: Runtime, F>(handler: F) -> TauriPlugin<R>
where
    F: Fn(&AppHandle<R>, IapPayload) + Send + Sync + 'static,
{
    Builder::new("storekit2")
        .invoke_handler(tauri::generate_handler![commands::pay, commands::restore_purchase])
        .setup(|app, api| {
            #[cfg(mobile)]
            let storekit2 = mobile::init(app, api)?;
            #[cfg(desktop)]
            let storekit2 = desktop::init(app, api)?;
            storekit2.register_iap_callback();

            let cloned_app = app.clone();
            set_event_handler(move |payload| handler(&cloned_app, payload));
            app.manage(storekit2);
            Ok(())
        })
        .build()
}
