use serde::{ser::Serializer, Serialize};

pub type Result<T> = std::result::Result<T, Error>;

pub(crate) struct TauriErrorWrapper(pub tauri::Error);

impl From<TauriErrorWrapper> for Error {
  fn from(value: TauriErrorWrapper) -> Self {
    Error::Unknown(value.0.to_string())
  }
}

#[derive(Debug, thiserror::Error)]
pub enum Error {
  #[error(transparent)]
  Io(#[from] std::io::Error),
  #[cfg(mobile)]
  #[error(transparent)]
  PluginInvoke(#[from] tauri::plugin::mobile::PluginInvokeError),

  #[error("unknown error: {0}")]
  Unknown(String),
}

impl Serialize for Error {
  fn serialize<S>(&self, serializer: S) -> std::result::Result<S::Ok, S::Error>
  where
    S: Serializer,
  {
    serializer.serialize_str(self.to_string().as_ref())
  }
}
