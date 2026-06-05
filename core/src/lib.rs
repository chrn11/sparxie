//! mihomo controller backend, exposed to iOS via C ABI.

mod assets;
mod cache;
mod client;
mod state;
mod utils;

pub mod api;
pub mod ios_ffi;

pub use utils::error::MihomoError;
