use crate::state::connections::{
    clear_closed, fetch_group_connections, fetch_groups, fetch_window, set_sort, subscribe,
};
use crate::MihomoError;
pub use crate::state::connections::{
    Connection, ConnectionGroup, ConnectionGroupSort, ConnectionsFrame, ConnectionsListKind,
    ConnectionsSort, ConnectionsTotals,
};
pub use crate::state::logs::LogEntry;
use crate::state::logs::{clear as logs_clear, subscribe as logs_subscribe};

use super::MihomoTarget;

/// Drop the cached log buffer for `(target, level)`. The upstream stream
/// keeps running so new lines flow normally.
pub async fn clear_logs(target: MihomoTarget, level: String) {
    logs_clear(target, &level).await
}

/// Page a slice of the sorted connections list. `kind` picks active vs
/// closed; `offset`/`limit` are bounds-checked.
pub async fn fetch_connection_window(
    target: MihomoTarget,
    interval_ms: u32,
    kind: ConnectionsListKind,
    offset: u32,
    limit: u32,
) -> Vec<Connection> {
    fetch_window(target, interval_ms, kind, offset, limit).await
}

/// Aggregate active connections into per-process groups, ordered by `sort`.
pub async fn fetch_connection_groups(
    target: MihomoTarget,
    interval_ms: u32,
    sort: ConnectionGroupSort,
    asc: bool,
) -> Vec<ConnectionGroup> {
    fetch_groups(target, interval_ms, sort, asc).await
}

/// Active connections belonging to `group`, sorted and capped at `limit`.
pub async fn fetch_connection_group_members(
    target: MihomoTarget,
    interval_ms: u32,
    group: String,
    limit: u32,
) -> Vec<Connection> {
    fetch_group_connections(target, interval_ms, group, limit).await
}

/// Update the per-target sort key. Effective from the next emitted frame.
pub async fn set_connections_sort(
    target: MihomoTarget,
    interval_ms: u32,
    sort: ConnectionsSort,
    asc: bool,
) {
    set_sort(target, interval_ms, sort, asc).await
}

/// Drop the closed-connections FIFO buffer for the given target/interval.
pub async fn clear_closed_connections(target: MihomoTarget, interval_ms: u32) {
    clear_closed(target, interval_ms).await
}

/// Signal every background stream for `target` to tear down.
pub fn stop_target_streams(target: MihomoTarget) {
    crate::state::stop::stop(&target);
}