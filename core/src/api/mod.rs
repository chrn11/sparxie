//! Public Rust API exposed to iOS via C ABI (see `crate::ios_ffi`).
//!
//! Each call takes a [`MihomoTarget`] (URL + optional secret) so the user can
//! hot-switch between controllers without re-creating any state on the Rust
//! side. JSON payloads are returned as raw strings so Swift can decode them
//! directly. Server-side regex filters stay on the Rust side to keep the wire
//! small for low-bandwidth remote controllers.
//!
//! Endpoints are split into one file per upstream URL prefix, mirroring
//! mihomo's [`hub/route/`](https://github.com/MetaCubeX/mihomo/tree/Alpha/hub/route)
//! layout.

use crate::MihomoError;
use crate::client::MihomoClient;

// Each sub-module is `pub` so downstream callers and the FFI layer can reach
// symbols via `crate::api::*`.
pub(crate) mod backend;
pub mod cache;
pub mod configs;
pub mod connections;
pub mod dns;
pub mod fonts;
pub mod groups;
pub mod icons;
pub mod providers;
pub mod proxies;
pub mod rules;
pub mod storage;
pub mod streams;
pub mod upgrade;
pub mod version;

// Re-export every public fn for convenience.
pub use cache::*;
pub use configs::*;
pub use connections::*;
pub use dns::*;
pub use fonts::*;
pub use groups::*;
pub use icons::*;
pub use providers::*;
pub use proxies::*;
pub use rules::*;
pub use storage::*;
pub use streams::*;
pub use upgrade::*;
pub use version::*;

/// One mihomo external-controller endpoint.
#[derive(Debug, Clone)]
pub struct MihomoTarget {
    pub base_url: String,
    pub secret: Option<String>,
    /// Skip TLS cert validation for https/wss (self-signed backends).
    pub allow_insecure: bool,
}

impl MihomoTarget {
    pub(crate) fn client(&self) -> Result<MihomoClient, MihomoError> {
        MihomoClient::new(&self.base_url, self.secret.clone(), self.allow_insecure)
    }
}

/// Initialize the application (starts the tokio runtime).
/// The runtime is lazily created on first async call, so this is a no-op
/// kept for API compatibility.
pub fn init_app() {
    // Runtime is lazily created via OnceLock in ios_ffi.
}

/// Percent-encode a path segment (we hit several mihomo endpoints with proxy
/// names that contain `/`, spaces, CJK characters, etc.).
pub(crate) fn urlencode(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for ch in s.chars() {
        if ch.is_ascii_alphanumeric() || matches!(ch, '-' | '_' | '.' | '~') {
            out.push(ch);
        } else {
            for byte in ch.to_string().as_bytes() {
                out.push_str(&format!("%{byte:02X}"));
            }
        }
    }
    out
}
