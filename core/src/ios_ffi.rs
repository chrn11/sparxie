//! C ABI FFI layer for iOS (Swift) integration.
//!
//! All exported functions use `#[no_mangle] extern "C"` for maximum compatibility.
//! String passing: input via `*const c_char`, output via `*mut c_char` (caller
//! must free with `sparxie_free_string`). Async operations use callback function
//! pointers. Stream operations use streaming callbacks with a `done` flag.

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::Arc;

use crate::api::{
    self, MihomoTarget,
};
use crate::state::stop;

// ---------------------------------------------------------------------------
// Callback types
// ---------------------------------------------------------------------------

/// Callback for one-shot async results: (result_json_or_null, error_json_or_null).
pub type SparxieCallback = unsafe extern "C" fn(*const c_char, *const c_char);

/// Callback for streaming results: (data_json, done).
/// When `done` is true, the stream has ended and no more data will arrive.
pub type SparxieStreamCallback = unsafe extern "C" fn(*const c_char, bool);

// ---------------------------------------------------------------------------
// Opaque target handle
// ---------------------------------------------------------------------------

/// Opaque handle wrapping a [`MihomoTarget`].
/// Created by `sparxie_target_create`, destroyed by `sparxie_target_free`.
#[repr(C)]
pub struct SparxieTarget {
    inner: MihomoTarget,
}

// ---------------------------------------------------------------------------
// Helper: run async task on tokio runtime and deliver result via callback
// ---------------------------------------------------------------------------

static RUNTIME: std::sync::OnceLock<tokio::runtime::Runtime> = std::sync::OnceLock::new();

fn runtime() -> &'static tokio::runtime::Runtime {
    RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .expect("failed to create tokio runtime")
    })
}

/// Run a Future on the shared tokio runtime and deliver the result via callback.
fn async_to_callback<F, Fut>(f: F, callback: SparxieCallback)
where
    F: FnOnce() -> Fut,
    Fut: std::future::Future<Output = Result<String, crate::MihomoError>> + Send + 'static,
{
    let future = f();
    runtime().spawn(async move {
        let (result_ptr, error_ptr) = match future.await {
            Ok(json) => {
                let c_result = CString::new(json).unwrap_or_default();
                (c_result.as_ptr(), std::ptr::null())
            }
            Err(err) => {
                let err_json = serde_json::json!({
                    "type": format!("{:?}", err).split_whitespace().next().unwrap_or("Other"),
                    "message": err.to_string(),
                })
                .to_string();
                let c_err = CString::new(err_json).unwrap_or_default();
                (std::ptr::null(), c_err.as_ptr())
            }
        };
        unsafe { callback(result_ptr, error_ptr); }
    });
}

/// Run a Future that returns nothing on success.
fn async_unit_to_callback<F, Fut>(f: F, callback: SparxieCallback)
where
    F: FnOnce() -> Fut,
    Fut: std::future::Future<Output = Result<(), crate::MihomoError>> + Send + 'static,
{
    let future = f();
    runtime().spawn(async move {
        let (result_ptr, error_ptr) = match future.await {
            Ok(()) => {
                let c_result = CString::new("true").unwrap_or_default();
                (c_result.as_ptr(), std::ptr::null())
            }
            Err(err) => {
                let err_json = serde_json::json!({
                    "type": format!("{:?}", err).split_whitespace().next().unwrap_or("Other"),
                    "message": err.to_string(),
                })
                .to_string();
                let c_err = CString::new(err_json).unwrap_or_default();
                (std::ptr::null(), c_err.as_ptr())
            }
        };
        unsafe { callback(result_ptr, error_ptr); }
    });
}

/// Convert optional C string to Option<String>.
fn cstr_to_string(ptr: *const c_char) -> Option<String> {
    if ptr.is_null() {
        None
    } else {
        unsafe { CStr::from_ptr(ptr) }.to_str().ok().map(|s| s.to_owned())
    }
}

/// Convert optional C string to a String, defaulting to empty.
fn cstr_to_string_or_empty(ptr: *const c_char) -> String {
    cstr_to_string(ptr).unwrap_or_default()
}

// ---------------------------------------------------------------------------
// Memory management
// ---------------------------------------------------------------------------

/// Free a string previously returned by any `sparxie_*` function.
/// Passing null is a no-op.
#[no_mangle]
pub extern "C" fn sparxie_free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe { drop(CString::from_raw(s)); }
    }
}

// ---------------------------------------------------------------------------
// Initialization
// ---------------------------------------------------------------------------

/// Initialize the application (starts the tokio runtime).
/// The runtime is lazily created on first async call, so this is a no-op
/// kept for API compatibility.
#[no_mangle]
pub extern "C" fn sparxie_init_app() {
    // Runtime is lazily created via OnceLock.
}

/// Initialize the icon cache directory.
/// Returns 0 on success, -1 on error.
#[no_mangle]
pub extern "C" fn sparxie_init_cache(cache_dir: *const c_char) -> i32 {
    let dir = cstr_to_string_or_empty(cache_dir);
    match crate::api::icons::init_cache(dir) {
        Ok(()) => 0,
        Err(_) => -1,
    }
}

// ---------------------------------------------------------------------------
// Target lifecycle
// ---------------------------------------------------------------------------

/// Create a new target handle.
/// `secret` may be null for unauthenticated backends.
/// Returns an opaque pointer; free with `sparxie_target_free`.
#[no_mangle]
pub extern "C" fn sparxie_target_create(
    base_url: *const c_char,
    secret: *const c_char,
    allow_insecure: bool,
) -> *mut SparxieTarget {
    let base_url = match cstr_to_string(base_url) {
        Some(s) => s,
        None => return std::ptr::null_mut(),
    };
    let target = MihomoTarget {
        base_url,
        secret: cstr_to_string(secret),
        allow_insecure,
    };
    Box::into_raw(Box::new(SparxieTarget { inner: target }))
}

/// Free a target handle.
#[no_mangle]
pub extern "C" fn sparxie_target_free(target: *mut SparxieTarget) {
    if !target.is_null() {
        unsafe { drop(Box::from_raw(target)); }
    }
}

// ---------------------------------------------------------------------------
// Version
// ---------------------------------------------------------------------------

/// Get the mihomo backend version string.
#[no_mangle]
pub extern "C" fn sparxie_version(
    target: *const SparxieTarget,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    async_to_callback(
        || api::version::version(target),
        callback,
    )
}

/// Get detailed version information as JSON.
#[no_mangle]
pub extern "C" fn sparxie_version_info(
    target: *const SparxieTarget,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    async_to_callback(
        || async {
            let info = api::version::version_info(target).await?;
            Ok(serde_json::to_string(&info)?)
        },
        callback,
    )
}

// ---------------------------------------------------------------------------
// Upgrade
// ---------------------------------------------------------------------------

/// Upgrade core.
#[no_mangle]
pub extern "C" fn sparxie_upgrade_core(
    target: *const SparxieTarget,
    channel: *const c_char,
    force: bool,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let channel = cstr_to_string(channel);
    async_unit_to_callback(
        || api::upgrade::upgrade_core(target, channel, force),
        callback,
    )
}

/// Upgrade UI.
#[no_mangle]
pub extern "C" fn sparxie_upgrade_ui(
    target: *const SparxieTarget,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    async_unit_to_callback(
        || api::upgrade::upgrade_ui(target),
        callback,
    )
}

/// Upgrade Geo data.
#[no_mangle]
pub extern "C" fn sparxie_upgrade_geo(
    target: *const SparxieTarget,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    async_unit_to_callback(
        || api::upgrade::upgrade_geo(target),
        callback,
    )
}

/// Restart core.
#[no_mangle]
pub extern "C" fn sparxie_restart_core(
    target: *const SparxieTarget,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    async_unit_to_callback(
        || api::upgrade::restart_core(target),
        callback,
    )
}

// ---------------------------------------------------------------------------
// Proxies
// ---------------------------------------------------------------------------

/// Get proxy catalog as JSON.
#[no_mangle]
pub extern "C" fn sparxie_proxy_catalog(
    target: *const SparxieTarget,
    include_hidden: bool,
    filter: *const c_char,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let filter = cstr_to_string_or_empty(filter);
    async_to_callback(
        || async {
            let catalog = api::proxies::proxy_catalog(target, include_hidden, filter).await?;
            Ok(serde_json::to_string(&catalog)?)
        },
        callback,
    )
}

/// Get proxy group members (paged).
#[no_mangle]
pub extern "C" fn sparxie_proxy_group_members(
    target: *const SparxieTarget,
    group: *const c_char,
    offset: u32,
    limit: u32,
    member_sort: i32,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let group = cstr_to_string_or_empty(group);
    let sort = match member_sort {
        1 => api::proxies::catalog::ProxyMemberSort::Name,
        2 => api::proxies::catalog::ProxyMemberSort::Delay,
        _ => api::proxies::catalog::ProxyMemberSort::Original,
    };
    async_to_callback(
        || async {
            let members = api::proxies::proxy_group_members(target, &group, offset, limit, sort).await?;
            Ok(serde_json::to_string(&members)?)
        },
        callback,
    )
}

/// Select a proxy in a group.
#[no_mangle]
pub extern "C" fn sparxie_select_proxy(
    target: *const SparxieTarget,
    group: *const c_char,
    name: *const c_char,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let group = cstr_to_string_or_empty(group);
    let name = cstr_to_string_or_empty(name);
    async_unit_to_callback(
        || api::proxies::select_proxy(target, group, name),
        callback,
    )
}

/// Unfix (unset sticky) a proxy.
#[no_mangle]
pub extern "C" fn sparxie_unfix_proxy(
    target: *const SparxieTarget,
    name: *const c_char,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let name = cstr_to_string_or_empty(name);
    async_unit_to_callback(
        || api::proxies::unfix_proxy(target, name),
        callback,
    )
}

/// Test delay of a single proxy.
#[no_mangle]
pub extern "C" fn sparxie_proxy_delay(
    target: *const SparxieTarget,
    name: *const c_char,
    test_url: *const c_char,
    timeout_ms: u32,
    expected_status: *const c_char,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let name = cstr_to_string_or_empty(name);
    let test_url = cstr_to_string_or_empty(test_url);
    let expected_status = cstr_to_string(expected_status);
    async_to_callback(
        || api::proxies::delay::proxy_delay(target, name, test_url, timeout_ms, expected_status),
        callback,
    )
}

/// Batch delay test for multiple proxies.
#[no_mangle]
pub extern "C" fn sparxie_proxy_batch_delay(
    target: *const SparxieTarget,
    names_json: *const c_char,
    test_url: *const c_char,
    timeout_ms: u32,
    expected_status: *const c_char,
    concurrency: u32,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let names_json = cstr_to_string_or_empty(names_json);
    let test_url = cstr_to_string_or_empty(test_url);
    let expected_status = cstr_to_string(expected_status);
    let names: Vec<String> = serde_json::from_str(&names_json).unwrap_or_default();
    async_to_callback(
        || api::proxies::delay::proxy_batch_delay(target, names, test_url, timeout_ms, expected_status, concurrency),
        callback,
    )
}

/// Batch delay test for a single group.
#[no_mangle]
pub extern "C" fn sparxie_proxy_group_delay(
    target: *const SparxieTarget,
    group: *const c_char,
    test_url: *const c_char,
    timeout_ms: u32,
    expected_status: *const c_char,
    concurrency: u32,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let group = cstr_to_string_or_empty(group);
    let test_url = cstr_to_string_or_empty(test_url);
    let expected_status = cstr_to_string(expected_status);
    async_to_callback(
        || async {
            let entries = api::proxies::delay::proxy_group_batch_delay(
                target, group, test_url, timeout_ms, expected_status, concurrency,
            ).await?;
            Ok(serde_json::to_string(&entries)?)
        },
        callback,
    )
}

// ---------------------------------------------------------------------------
// Connections
// ---------------------------------------------------------------------------

/// Get all connections as JSON.
#[no_mangle]
pub extern "C" fn sparxie_connections(
    target: *const SparxieTarget,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    async_to_callback(|| api::connections::connections(target), callback)
}

/// Close a single connection.
#[no_mangle]
pub extern "C" fn sparxie_close_connection(
    target: *const SparxieTarget,
    id: *const c_char,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let id = cstr_to_string_or_empty(id);
    async_unit_to_callback(|| api::connections::close_connection(target, id), callback)
}

/// Close all connections.
#[no_mangle]
pub extern "C" fn sparxie_close_all_connections(
    target: *const SparxieTarget,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    async_unit_to_callback(|| api::connections::close_all_connections(target), callback)
}

/// Close connections by chain.
#[no_mangle]
pub extern "C" fn sparxie_close_connections_by_chain(
    target: *const SparxieTarget,
    chain: *const c_char,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let chain = cstr_to_string_or_empty(chain);
    async_to_callback(
        || api::connections::close_connections_by_chain(target, chain),
        callback,
    )
}

/// Close connections by group.
#[no_mangle]
pub extern "C" fn sparxie_close_connections_by_group(
    target: *const SparxieTarget,
    group: *const c_char,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let group = cstr_to_string_or_empty(group);
    async_to_callback(
        || api::connections::close_connections_by_group(target, group),
        callback,
    )
}

// ---------------------------------------------------------------------------
// Stream subscriptions (via callbacks)
// ---------------------------------------------------------------------------

/// Subscribe to traffic updates. Each callback delivers a JSON `TrafficSample`.
#[no_mangle]
pub extern "C" fn sparxie_traffic_stream(
    target: *const SparxieTarget,
    callback: SparxieStreamCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    runtime().spawn(async move {
        match crate::state::traffic::traffic_subscribe(target).await {
            Ok(rx) => {
                use futures_util::StreamExt;
                let mut stream = tokio_stream::wrappers::BroadcastStream::new(rx);
                while let Some(item) = stream.next().await {
                    match item {
                        Ok(sample) => {
                            let json = serde_json::to_string(&sample).unwrap_or_default();
                            let c_json = CString::new(json).unwrap_or_default();
                            unsafe { callback(c_json.as_ptr(), false); }
                        }
                        Err(_) => continue,
                    }
                }
            }
            Err(e) => {
                let err = CString::new(e.to_string()).unwrap_or_default();
                unsafe { callback(std::ptr::null(), true); }
                let _ = err;
            }
        }
    });
}

/// Subscribe to memory usage updates. Each callback delivers a JSON `MemorySample`.
#[no_mangle]
pub extern "C" fn sparxie_memory_stream(
    target: *const SparxieTarget,
    callback: SparxieStreamCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    runtime().spawn(async move {
        match crate::state::traffic::memory_subscribe(target).await {
            Ok(rx) => {
                use futures_util::StreamExt;
                let mut stream = tokio_stream::wrappers::BroadcastStream::new(rx);
                while let Some(item) = stream.next().await {
                    match item {
                        Ok(sample) => {
                            let json = serde_json::to_string(&sample).unwrap_or_default();
                            let c_json = CString::new(json).unwrap_or_default();
                            unsafe { callback(c_json.as_ptr(), false); }
                        }
                        Err(_) => continue,
                    }
                }
            }
            Err(e) => {
                let _ = e;
                unsafe { callback(std::ptr::null(), true); }
            }
        }
    });
}

/// Subscribe to log entries. Each callback delivers a JSON array of `LogEntry`.
#[no_mangle]
pub extern "C" fn sparxie_logs_stream(
    target: *const SparxieTarget,
    level: *const c_char,
    callback: SparxieStreamCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let level = cstr_to_string_or_empty(level);
    runtime().spawn(async move {
        match crate::state::logs::subscribe(target, &level).await {
            Ok((snapshot, rx)) => {
                // Send snapshot first
                if !snapshot.is_empty() {
                    let json = serde_json::to_string(&snapshot).unwrap_or_default();
                    let c_json = CString::new(json).unwrap_or_default();
                    unsafe { callback(c_json.as_ptr(), false); }
                }
                use futures_util::StreamExt;
                let mut stream = tokio_stream::wrappers::BroadcastStream::new(rx);
                while let Some(item) = stream.next().await {
                    match item {
                        Ok(entry) => {
                            let batch = vec![entry];
                            let json = serde_json::to_string(&batch).unwrap_or_default();
                            let c_json = CString::new(json).unwrap_or_default();
                            unsafe { callback(c_json.as_ptr(), false); }
                        }
                        Err(_) => continue,
                    }
                }
            }
            Err(_) => {
                unsafe { callback(std::ptr::null(), true); }
            }
        }
    });
}

/// Clear cached log entries for the given level.
#[no_mangle]
pub extern "C" fn sparxie_clear_logs(
    target: *const SparxieTarget,
    level: *const c_char,
) {
    let target = unsafe { &(*target).inner }.clone();
    let level = cstr_to_string_or_empty(level);
    runtime().spawn(async move {
        crate::state::logs::clear(target, &level).await;
    });
}

/// Subscribe to connection frame updates. Each callback delivers JSON `ConnectionsFrame`.
#[no_mangle]
pub extern "C" fn sparxie_connections_stream(
    target: *const SparxieTarget,
    interval_ms: u32,
    callback: SparxieStreamCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    runtime().spawn(async move {
        match crate::state::connections::subscribe(target, interval_ms).await {
            Ok(rx) => {
                use futures_util::StreamExt;
                let mut stream = tokio_stream::wrappers::BroadcastStream::new(rx);
                while let Some(item) = stream.next().await {
                    match item {
                        Ok(frame) => {
                            let json = serde_json::to_string(&frame).unwrap_or_default();
                            let c_json = CString::new(json).unwrap_or_default();
                            unsafe { callback(c_json.as_ptr(), false); }
                        }
                        Err(_) => continue,
                    }
                }
            }
            Err(_) => {
                unsafe { callback(std::ptr::null(), true); }
            }
        }
    });
}

/// Fetch a window of connections.
#[no_mangle]
pub extern "C" fn sparxie_fetch_connection_window(
    target: *const SparxieTarget,
    interval_ms: u32,
    kind: i32,
    offset: u32,
    limit: u32,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let kind = match kind {
        1 => crate::state::connections::ConnectionsListKind::Closed,
        _ => crate::state::connections::ConnectionsListKind::Active,
    };
    async_to_callback(
        || async {
            let conns = crate::state::connections::fetch_window(target, interval_ms, kind, offset, limit).await;
            Ok(serde_json::to_string(&conns)?)
        },
        callback,
    )
}

/// Fetch connection groups.
#[no_mangle]
pub extern "C" fn sparxie_fetch_connection_groups(
    target: *const SparxieTarget,
    interval_ms: u32,
    sort: i32,
    asc: bool,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let sort = match sort {
        1 => crate::state::connections::ConnectionGroupSort::Name,
        2 => crate::state::connections::ConnectionGroupSort::Count,
        3 => crate::state::connections::ConnectionGroupSort::Upload,
        4 => crate::state::connections::ConnectionGroupSort::Download,
        5 => crate::state::connections::ConnectionGroupSort::UploadSpeed,
        6 => crate::state::connections::ConnectionGroupSort::DownloadSpeed,
        _ => crate::state::connections::ConnectionGroupSort::Name,
    };
    async_to_callback(
        || async {
            let groups = crate::state::connections::fetch_groups(target, interval_ms, sort, asc).await;
            Ok(serde_json::to_string(&groups)?)
        },
        callback,
    )
}

/// Fetch connections in a group.
#[no_mangle]
pub extern "C" fn sparxie_fetch_connection_group_members(
    target: *const SparxieTarget,
    interval_ms: u32,
    group: *const c_char,
    limit: u32,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let group = cstr_to_string_or_empty(group);
    async_to_callback(
        || async {
            let conns = crate::state::connections::fetch_group_connections(target, interval_ms, &group, limit).await;
            Ok(serde_json::to_string(&conns)?)
        },
        callback,
    )
}

/// Set connections sort order.
#[no_mangle]
pub extern "C" fn sparxie_set_connections_sort(
    target: *const SparxieTarget,
    interval_ms: u32,
    sort: i32,
    asc: bool,
) {
    let target = unsafe { &(*target).inner }.clone();
    let sort = match sort {
        1 => crate::state::connections::ConnectionsSort::Upload,
        2 => crate::state::connections::ConnectionsSort::Download,
        3 => crate::state::connections::ConnectionsSort::UploadSpeed,
        4 => crate::state::connections::ConnectionsSort::DownloadSpeed,
        5 => crate::state::connections::ConnectionsSort::Process,
        _ => crate::state::connections::ConnectionsSort::Time,
    };
    runtime().spawn(async move {
        crate::state::connections::set_sort(target, interval_ms, sort, asc).await;
    });
}

/// Clear closed connections.
#[no_mangle]
pub extern "C" fn sparxie_clear_closed_connections(
    target: *const SparxieTarget,
    interval_ms: u32,
) {
    let target = unsafe { &(*target).inner }.clone();
    runtime().spawn(async move {
        crate::state::connections::clear_closed(target, interval_ms).await;
    });
}

/// Stop all streams for a target.
#[no_mangle]
pub extern "C" fn sparxie_stop_target_streams(target: *const SparxieTarget) {
    let target = unsafe { &(*target).inner };
    stop::stop(target);
}

// ---------------------------------------------------------------------------
// Rules
// ---------------------------------------------------------------------------

/// Get total rule count.
#[no_mangle]
pub extern "C" fn sparxie_rules_count(
    target: *const SparxieTarget,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    async_to_callback(
        || async {
            let count = api::rules::rules_count(target).await;
            Ok(count.to_string())
        },
        callback,
    )
}

/// Load rules with a filter string.
#[no_mangle]
pub extern "C" fn sparxie_rules_load(
    target: *const SparxieTarget,
    filter: *const c_char,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let filter = cstr_to_string_or_empty(filter);
    async_to_callback(
        || async {
            let summary = api::rules::rules_load(target, filter).await?;
            Ok(serde_json::to_string(&summary)?)
        },
        callback,
    )
}

/// Set filter and get summary.
#[no_mangle]
pub extern "C" fn sparxie_rules_set_filter(
    target: *const SparxieTarget,
    filter: *const c_char,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let filter = cstr_to_string_or_empty(filter);
    async_to_callback(
        || async {
            let summary = api::rules::rules_set_filter(target, filter).await;
            Ok(serde_json::to_string(&summary)?)
        },
        callback,
    )
}

/// Get a window of rules.
#[no_mangle]
pub extern "C" fn sparxie_rules_window(
    target: *const SparxieTarget,
    offset: u32,
    limit: u32,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    async_to_callback(
        || async {
            let rules = api::rules::rules_window(target, offset, limit).await;
            Ok(serde_json::to_string(&rules)?)
        },
        callback,
    )
}

/// Disable rules by index.
#[no_mangle]
pub extern "C" fn sparxie_rules_disable(
    target: *const SparxieTarget,
    indices_json: *const c_char,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let indices_json = cstr_to_string_or_empty(indices_json);
    async_unit_to_callback(
        || api::rules::rules_disable(target, indices_json),
        callback,
    )
}

// ---------------------------------------------------------------------------
// Configs
// ---------------------------------------------------------------------------

/// Get configs as JSON.
#[no_mangle]
pub extern "C" fn sparxie_configs(
    target: *const SparxieTarget,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    async_to_callback(|| api::configs::configs(target), callback)
}

/// Get config mode.
#[no_mangle]
pub extern "C" fn sparxie_config_mode(
    target: *const SparxieTarget,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    async_to_callback(|| api::configs::config_mode(target), callback)
}

/// Patch configs.
#[no_mangle]
pub extern "C" fn sparxie_patch_configs(
    target: *const SparxieTarget,
    body_json: *const c_char,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let body_json = cstr_to_string_or_empty(body_json);
    async_unit_to_callback(
        || api::configs::patch_configs(target, body_json),
        callback,
    )
}

/// Reload configs.
#[no_mangle]
pub extern "C" fn sparxie_reload_configs(
    target: *const SparxieTarget,
    path: *const c_char,
    payload: *const c_char,
    force: bool,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let path = cstr_to_string(path);
    let payload = cstr_to_string(payload);
    async_unit_to_callback(
        || api::configs::reload_configs(target, path, payload, force),
        callback,
    )
}

/// Update Geo data.
#[no_mangle]
pub extern "C" fn sparxie_update_geo(
    target: *const SparxieTarget,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    async_unit_to_callback(|| api::configs::update_geo(target), callback)
}

// ---------------------------------------------------------------------------
// Storage
// ---------------------------------------------------------------------------

#[no_mangle]
pub extern "C" fn sparxie_storage_get(
    target: *const SparxieTarget,
    key: *const c_char,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let key = cstr_to_string_or_empty(key);
    async_to_callback(|| api::storage::storage_get(target, key), callback)
}

#[no_mangle]
pub extern "C" fn sparxie_storage_set(
    target: *const SparxieTarget,
    key: *const c_char,
    value_json: *const c_char,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let key = cstr_to_string_or_empty(key);
    let value_json = cstr_to_string_or_empty(value_json);
    async_unit_to_callback(
        || api::storage::storage_set(target, key, value_json),
        callback,
    )
}

#[no_mangle]
pub extern "C" fn sparxie_storage_delete(
    target: *const SparxieTarget,
    key: *const c_char,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let key = cstr_to_string_or_empty(key);
    async_unit_to_callback(
        || api::storage::storage_delete(target, key),
        callback,
    )
}

// ---------------------------------------------------------------------------
// DNS
// ---------------------------------------------------------------------------

#[no_mangle]
pub extern "C" fn sparxie_dns_query(
    target: *const SparxieTarget,
    name: *const c_char,
    record_type: *const c_char,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let name = cstr_to_string_or_empty(name);
    let record_type = cstr_to_string(record_type);
    async_to_callback(
        || api::dns::dns_query(target, name, record_type),
        callback,
    )
}

// ---------------------------------------------------------------------------
// Cache
// ---------------------------------------------------------------------------

#[no_mangle]
pub extern "C" fn sparxie_flush_fakeip(
    target: *const SparxieTarget,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    async_unit_to_callback(|| api::cache::flush_fakeip(target), callback)
}

#[no_mangle]
pub extern "C" fn sparxie_flush_dns(
    target: *const SparxieTarget,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    async_unit_to_callback(|| api::cache::flush_dns(target), callback)
}

// ---------------------------------------------------------------------------
// Groups
// ---------------------------------------------------------------------------

#[no_mangle]
pub extern "C" fn sparxie_groups(
    target: *const SparxieTarget,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    async_to_callback(|| api::groups::groups(target), callback)
}

#[no_mangle]
pub extern "C" fn sparxie_group_delay(
    target: *const SparxieTarget,
    group: *const c_char,
    test_url: *const c_char,
    timeout_ms: u32,
    expected_status: *const c_char,
    concurrency: u32,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let group = cstr_to_string_or_empty(group);
    let test_url = cstr_to_string_or_empty(test_url);
    let expected_status = cstr_to_string(expected_status);
    async_to_callback(
        || async {
            let entries = api::groups::group_delay(target, group, test_url, timeout_ms, expected_status, concurrency).await?;
            Ok(serde_json::to_string(&entries)?)
        },
        callback,
    )
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

#[no_mangle]
pub extern "C" fn sparxie_proxy_providers(
    target: *const SparxieTarget,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    async_to_callback(|| api::providers::proxy_providers(target), callback)
}

#[no_mangle]
pub extern "C" fn sparxie_proxy_provider_catalog(
    target: *const SparxieTarget,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    async_to_callback(
        || async {
            let catalog = api::providers::proxy_provider_catalog(target).await?;
            Ok(serde_json::to_string(&catalog)?)
        },
        callback,
    )
}

#[no_mangle]
pub extern "C" fn sparxie_proxy_provider_update(
    target: *const SparxieTarget,
    name: *const c_char,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let name = cstr_to_string_or_empty(name);
    async_unit_to_callback(
        || api::providers::proxy_provider_update(target, name),
        callback,
    )
}

#[no_mangle]
pub extern "C" fn sparxie_proxy_provider_healthcheck(
    target: *const SparxieTarget,
    name: *const c_char,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let name = cstr_to_string_or_empty(name);
    async_unit_to_callback(
        || api::providers::proxy_provider_healthcheck(target, name),
        callback,
    )
}

#[no_mangle]
pub extern "C" fn sparxie_rule_providers(
    target: *const SparxieTarget,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    async_to_callback(|| api::providers::rule_providers(target), callback)
}

#[no_mangle]
pub extern "C" fn sparxie_rule_provider_catalog(
    target: *const SparxieTarget,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    async_to_callback(
        || async {
            let catalog = api::providers::rule_provider_catalog(target).await?;
            Ok(serde_json::to_string(&catalog)?)
        },
        callback,
    )
}

#[no_mangle]
pub extern "C" fn sparxie_rule_provider_update(
    target: *const SparxieTarget,
    name: *const c_char,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let name = cstr_to_string_or_empty(name);
    async_unit_to_callback(
        || api::providers::rule_provider_update(target, name),
        callback,
    )
}

// ---------------------------------------------------------------------------
// Proxies (raw JSON)
// ---------------------------------------------------------------------------

#[no_mangle]
pub extern "C" fn sparxie_proxies(
    target: *const SparxieTarget,
    name_pattern: *const c_char,
    type_pattern: *const c_char,
    groups_only: bool,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let name_pattern = cstr_to_string(name_pattern);
    let type_pattern = cstr_to_string(type_pattern);
    async_to_callback(
        || api::proxies::proxies(target, name_pattern, type_pattern, groups_only),
        callback,
    )
}

#[no_mangle]
pub extern "C" fn sparxie_proxy_detail(
    target: *const SparxieTarget,
    name: *const c_char,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let name = cstr_to_string_or_empty(name);
    async_to_callback(
        || api::proxies::proxy_detail(target, name),
        callback,
    )
}

// ---------------------------------------------------------------------------
// Icons
// ---------------------------------------------------------------------------

#[no_mangle]
pub extern "C" fn sparxie_fetch_icon(
    target: *const SparxieTarget,
    url: *const c_char,
    callback: SparxieCallback,
) {
    let target = unsafe { &(*target).inner }.clone();
    let url = cstr_to_string_or_empty(url);
    async_to_callback(
        || api::icons::fetch_icon(target, url),
        callback,
    )
}

#[no_mangle]
pub extern "C" fn sparxie_icon_cache_size(callback: SparxieCallback) {
    runtime().spawn(async move {
        match api::icons::icon_cache_size().await {
            Ok(size) => {
                let result = CString::new(size.to_string()).unwrap_or_default();
                unsafe { callback(result.as_ptr(), std::ptr::null()); }
            }
            Err(e) => {
                let err = CString::new(e.to_string()).unwrap_or_default();
                unsafe { callback(std::ptr::null(), err.as_ptr()); }
            }
        }
    });
}

#[no_mangle]
pub extern "C" fn sparxie_clear_icon_cache(callback: SparxieCallback) {
    async_unit_to_callback(|| api::icons::clear_icon_cache(), callback)
}

// ---------------------------------------------------------------------------
// Fonts
// ---------------------------------------------------------------------------

#[no_mangle]
pub extern "C" fn sparxie_system_font_families(callback: SparxieCallback) {
    async_to_callback(
        || async {
            let fonts = api::fonts::system_font_families().await?;
            Ok(serde_json::to_string(&fonts)?)
        },
        callback,
    )
}