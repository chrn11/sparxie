#ifndef SparxieBridge_h
#define SparxieBridge_h

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// ---------------------------------------------------------------------------
// Callback types
// ---------------------------------------------------------------------------

/// Callback for one-shot async results: (result_json_or_null, error_json_or_null).
typedef void (*SparxieCallback)(const char* result, const char* error);

/// Callback for streaming results: (data_json, done).
typedef void (*SparxieStreamCallback)(const char* data, bool done);

// ---------------------------------------------------------------------------
// Opaque target handle
// ---------------------------------------------------------------------------

typedef struct SparxieTarget SparxieTarget;

// ---------------------------------------------------------------------------
// Memory management
// ---------------------------------------------------------------------------

void sparxie_free_string(char* s);

// ---------------------------------------------------------------------------
// Initialization
// ---------------------------------------------------------------------------

void sparxie_init_app(void);
int32_t sparxie_init_cache(const char* cache_dir);

// ---------------------------------------------------------------------------
// Target lifecycle
// ---------------------------------------------------------------------------

SparxieTarget* sparxie_target_create(const char* base_url, const char* secret, bool allow_insecure);
void sparxie_target_free(SparxieTarget* target);

// ---------------------------------------------------------------------------
// Version
// ---------------------------------------------------------------------------

void sparxie_version(const SparxieTarget* target, SparxieCallback callback);
void sparxie_version_info(const SparxieTarget* target, SparxieCallback callback);

// ---------------------------------------------------------------------------
// Upgrade
// ---------------------------------------------------------------------------

void sparxie_upgrade_core(const SparxieTarget* target, const char* channel, bool force, SparxieCallback callback);
void sparxie_upgrade_ui(const SparxieTarget* target, SparxieCallback callback);
void sparxie_upgrade_geo(const SparxieTarget* target, SparxieCallback callback);
void sparxie_restart_core(const SparxieTarget* target, SparxieCallback callback);

// ---------------------------------------------------------------------------
// Proxies
// ---------------------------------------------------------------------------

void sparxie_proxy_catalog(const SparxieTarget* target, bool include_hidden, const char* filter, SparxieCallback callback);
void sparxie_proxy_group_members(const SparxieTarget* target, const char* group, uint32_t offset, uint32_t limit, int32_t member_sort, SparxieCallback callback);
void sparxie_select_proxy(const SparxieTarget* target, const char* group, const char* name, SparxieCallback callback);
void sparxie_unfix_proxy(const SparxieTarget* target, const char* name, SparxieCallback callback);
void sparxie_proxy_delay(const SparxieTarget* target, const char* name, const char* test_url, uint32_t timeout_ms, const char* expected_status, SparxieCallback callback);
void sparxie_proxy_batch_delay(const SparxieTarget* target, const char* names_json, const char* test_url, uint32_t timeout_ms, const char* expected_status, uint32_t concurrency, SparxieCallback callback);
void sparxie_proxy_group_delay(const SparxieTarget* target, const char* group, const char* test_url, uint32_t timeout_ms, const char* expected_status, uint32_t concurrency, SparxieCallback callback);

// ---------------------------------------------------------------------------
// Connections
// ---------------------------------------------------------------------------

void sparxie_connections(const SparxieTarget* target, SparxieCallback callback);
void sparxie_close_connection(const SparxieTarget* target, const char* id, SparxieCallback callback);
void sparxie_close_all_connections(const SparxieTarget* target, SparxieCallback callback);
void sparxie_close_connections_by_chain(const SparxieTarget* target, const char* chain, SparxieCallback callback);
void sparxie_close_connections_by_group(const SparxieTarget* target, const char* group, SparxieCallback callback);
void sparxie_fetch_connection_window(const SparxieTarget* target, uint32_t interval_ms, int32_t kind, uint32_t offset, uint32_t limit, SparxieCallback callback);
void sparxie_fetch_connection_groups(const SparxieTarget* target, uint32_t interval_ms, int32_t sort, bool asc, SparxieCallback callback);
void sparxie_fetch_connection_group_members(const SparxieTarget* target, uint32_t interval_ms, const char* group, uint32_t limit, SparxieCallback callback);
void sparxie_set_connections_sort(const SparxieTarget* target, uint32_t interval_ms, int32_t sort, bool asc);
void sparxie_clear_closed_connections(const SparxieTarget* target, uint32_t interval_ms);
void sparxie_connections_stream(const SparxieTarget* target, uint32_t interval_ms, SparxieStreamCallback callback);

// ---------------------------------------------------------------------------
// Streams (traffic, memory, logs)
// ---------------------------------------------------------------------------

void sparxie_traffic_stream(const SparxieTarget* target, SparxieStreamCallback callback);
void sparxie_memory_stream(const SparxieTarget* target, SparxieStreamCallback callback);
void sparxie_logs_stream(const SparxieTarget* target, const char* level, SparxieStreamCallback callback);
void sparxie_clear_logs(const SparxieTarget* target, const char* level);

// ---------------------------------------------------------------------------
// Rules
// ---------------------------------------------------------------------------

void sparxie_rules_count(const SparxieTarget* target, SparxieCallback callback);
void sparxie_rules_load(const SparxieTarget* target, const char* filter, SparxieCallback callback);
void sparxie_rules_set_filter(const SparxieTarget* target, const char* filter, SparxieCallback callback);
void sparxie_rules_window(const SparxieTarget* target, uint32_t offset, uint32_t limit, SparxieCallback callback);
void sparxie_rules_disable(const SparxieTarget* target, const char* indices_json, SparxieCallback callback);

// ---------------------------------------------------------------------------
// Configs
// ---------------------------------------------------------------------------

void sparxie_configs(const SparxieTarget* target, SparxieCallback callback);
void sparxie_config_mode(const SparxieTarget* target, SparxieCallback callback);
void sparxie_patch_configs(const SparxieTarget* target, const char* body_json, SparxieCallback callback);
void sparxie_reload_configs(const SparxieTarget* target, const char* path, const char* payload, bool force, SparxieCallback callback);
void sparxie_update_geo(const SparxieTarget* target, SparxieCallback callback);

// ---------------------------------------------------------------------------
// Storage
// ---------------------------------------------------------------------------

void sparxie_storage_get(const SparxieTarget* target, const char* key, SparxieCallback callback);
void sparxie_storage_set(const SparxieTarget* target, const char* key, const char* value_json, SparxieCallback callback);
void sparxie_storage_delete(const SparxieTarget* target, const char* key, SparxieCallback callback);

// ---------------------------------------------------------------------------
// DNS
// ---------------------------------------------------------------------------

void sparxie_dns_query(const SparxieTarget* target, const char* name, const char* record_type, SparxieCallback callback);

// ---------------------------------------------------------------------------
// Cache
// ---------------------------------------------------------------------------

void sparxie_flush_fakeip(const SparxieTarget* target, SparxieCallback callback);
void sparxie_flush_dns(const SparxieTarget* target, SparxieCallback callback);

// ---------------------------------------------------------------------------
// Groups
// ---------------------------------------------------------------------------

void sparxie_groups(const SparxieTarget* target, SparxieCallback callback);
void sparxie_group_delay(const SparxieTarget* target, const char* group, const char* test_url, uint32_t timeout_ms, const char* expected_status, uint32_t concurrency, SparxieCallback callback);

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

void sparxie_proxy_providers(const SparxieTarget* target, SparxieCallback callback);
void sparxie_proxy_provider_catalog(const SparxieTarget* target, SparxieCallback callback);
void sparxie_proxy_provider_update(const SparxieTarget* target, const char* name, SparxieCallback callback);
void sparxie_proxy_provider_healthcheck(const SparxieTarget* target, const char* name, SparxieCallback callback);
void sparxie_rule_providers(const SparxieTarget* target, SparxieCallback callback);
void sparxie_rule_provider_catalog(const SparxieTarget* target, SparxieCallback callback);
void sparxie_rule_provider_update(const SparxieTarget* target, const char* name, SparxieCallback callback);

// ---------------------------------------------------------------------------
// Proxies (raw JSON)
// ---------------------------------------------------------------------------

void sparxie_proxies(const SparxieTarget* target, const char* name_pattern, const char* type_pattern, bool groups_only, SparxieCallback callback);
void sparxie_proxy_detail(const SparxieTarget* target, const char* name, SparxieCallback callback);

// ---------------------------------------------------------------------------
// Icons
// ---------------------------------------------------------------------------

void sparxie_fetch_icon(const SparxieTarget* target, const char* url, SparxieCallback callback);
void sparxie_icon_cache_size(SparxieCallback callback);
void sparxie_clear_icon_cache(SparxieCallback callback);

// ---------------------------------------------------------------------------
// Fonts
// ---------------------------------------------------------------------------

void sparxie_system_font_families(SparxieCallback callback);

// ---------------------------------------------------------------------------
// Stop streams
// ---------------------------------------------------------------------------

void sparxie_stop_target_streams(const SparxieTarget* target);

#ifdef __cplusplus
}
#endif

#endif /* SparxieBridge_h */