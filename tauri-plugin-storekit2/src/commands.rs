use tauri::{command, AppHandle, Runtime};

use crate::models::*;
use crate::Result;
use crate::Storekit2Ext;

#[command]
pub(crate) async fn pay<R: Runtime>(
    app: AppHandle<R>,
    payment: PaymentRequest,
) -> Result<PaymentResponse> {
    app.storekit2().pay(payment)
}

#[command]
pub(crate) async fn restore_purchase<R: Runtime>(app: AppHandle<R>) -> Result<()> {
    app.storekit2().restore_purchase()
}
