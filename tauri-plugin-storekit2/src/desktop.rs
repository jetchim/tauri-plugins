use crate::models::*;
use once_cell::sync::OnceCell;
use serde::de::DeserializeOwned;
use serde_json::Value;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use tauri::{plugin::PluginApi, AppHandle, Runtime};

#[derive(Debug)]
pub struct IapPayload {
    pub event: String,
    pub data: Option<String>,
    pub error: Option<String>,
}

type CalendarEventHandler = Box<dyn Fn(IapPayload) + Send + Sync + 'static>;
static GLOBAL_IAP_HANDLER: OnceCell<Option<CalendarEventHandler>> = OnceCell::new();

pub type IapCallback = extern "C" fn(callback: *const c_char);

extern "C" {
    fn native_purchase(account_token: *const c_char, product_id: *const c_char) -> *const c_char;
    fn native_restore_purchase();
    fn native_register_iap_callback(callback: IapCallback);
}

pub fn init<R: Runtime, C: DeserializeOwned>(
    app: &AppHandle<R>,
    _api: PluginApi<R, C>,
) -> crate::Result<Storekit2<R>> {
    Ok(Storekit2(app.clone()))
}

pub fn set_event_handler<F: Fn(IapPayload) + Send + Sync + 'static>(f: F) {
    let _ = GLOBAL_IAP_HANDLER.set(Some(Box::new(f)));
}

/// Access to the storekit2 APIs.
pub struct Storekit2<R: Runtime>(AppHandle<R>);

impl<R: Runtime> Storekit2<R> {
    pub fn pay(&self, payment_request: PaymentRequest) -> crate::Result<PaymentResponse> {
        unsafe {
            let product_id = CString::new(payment_request.product_id.as_str()).unwrap();
            let account_token = CString::new(payment_request.app_account_token.as_str()).unwrap();
            let swift_msg_ptr = native_purchase(account_token.as_ptr(), product_id.as_ptr());
            let swift_msg = CStr::from_ptr(swift_msg_ptr).to_str().unwrap();

            if let Some(Some(handler)) = GLOBAL_IAP_HANDLER.get() {
                if let Ok(val) = serde_json::from_str::<Value>(&swift_msg) {
                    let event = val["type"].as_str().unwrap_or("UNKNOWN").to_string();
                    let data = val["data"].as_str().map(String::from);
                    let error = val["error"].as_str().map(String::from);
                    handler(IapPayload { event, data, error });
                }
            }
        }
        Ok(PaymentResponse {})
    }

    pub(crate) fn register_iap_callback(&self) {
        unsafe {
            native_register_iap_callback(on_iap_callback);
        }
    }
    pub fn restore_purchase(&self) -> crate::Result<()> {
        unsafe {
            native_restore_purchase();
        }
        Ok(())
    }
}
extern "C" fn on_iap_callback(callback: *const c_char) {
    unsafe {
        if callback.is_null() {
            eprint!("callback is null");
            return;
        }
        let data_str = CStr::from_ptr(callback).to_string_lossy();
        if let Some(Some(handler)) = GLOBAL_IAP_HANDLER.get() {
            if let Ok(val) = serde_json::from_str::<Value>(&data_str) {
                let event = val["event"].as_str().unwrap_or("UNKNOWN").to_string();
                let data = val["data"].as_str().map(String::from);
                let error = val["error"].as_str().map(String::from);
                handler(IapPayload { event, data, error });
            }
        }
    }
}
