# Sparxie iOS 原生化迁移 — 详细执行计划

> 本文档是 `IOS_NATIVE_MIGRATION_PLAN.md` 的可操作版本，列出每个步骤的具体文件变动、代码骨架和验收检查。

---

## 全局前置条件

- macOS 环境（本地或 CI runner）
- Xcode 15+、Swift 5.9+
- Rust stable 工具链 + `aarch64-apple-ios` target
- 无需 Apple 开发者证书（TrollStore 安装）

---

## 步骤 1：清理旧跨平台工程

### 删除目录

| 路径 | 说明 |
|------|------|
| `android/` | Android 工程 |
| `ios/` | Flutter iOS 工程（将被 native-ios/ 替代）|
| `linux/` | Linux 桌面支持 |
| `macos/` | macOS 桌面支持 |
| `web/` | Web 支持 |
| `windows/` | Windows 桌面支持 |
| `lib/` | Flutter/Dart 源码 |
| `test/` | Flutter 测试 |

### 删除文件

| 路径 | 说明 |
|------|------|
| `pubspec.yaml` | Flutter 依赖配置 |
| `pubspec.lock` | Flutter 锁文件 |
| `analysis_options.yaml` | Dart lint 配置 |
| `flutter_rust_bridge.yaml` | FRB 代码生成配置 |
| `.metadata` | Flutter 项目元数据 |

### 保留不动

| 路径 | 说明 |
|------|------|
| `core/` | Rust 核心（将改造）|
| `assets/` | 应用资源（图标等）|
| `scripts/` | 构建脚本（将改造）|
| `.github/` | CI（将改造）|
| `README.md` | 文档（将更新）|
| `LICENSE` | 许可证 |
| `.gitignore` | 忽略规则（将更新）|
| `IOS_NATIVE_MIGRATION_PLAN.md` | 迁移规划文档 |

### 验收

```bash
ls -la | grep -v -E '(core|assets|scripts|\.github|README|LICENSE|\.gitignore|IOS_NATIVE)'
# 不应出现 android/ ios/ lib/ 等目录
```

---

## 步骤 2：改造 Rust Cargo.toml

### 变更内容

```toml
[package]
name = "sparxie"
version = "0.1.0"
edition = "2024"

[lib]
name = "sparxie"
path = "src/lib.rs"
crate-type = ["staticlib"]  # iOS 只需 staticlib，移除 cdylib

[profile.release]
lto = "fat"
codegen-units = 1
strip = true

[dependencies]
# 移除 flutter_rust_bridge
anyhow = "1.0"
blake3 = "1.8"
futures-util = "0.3"
http-body-util = "0.1"
hyper = { version = "1", features = ["client", "http1"] }
hyper-util = { version = "0.1", features = ["tokio"] }
redb = "2"
regex = "1.12"
reqwest = { version = "0.12", default-features = false, features = ["json", "rustls-tls", "stream"] }
rustls = { version = "0.23", default-features = false, features = ["ring"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
tokio = { version = "1.52", features = ["macros", "net", "rt-multi-thread", "sync", "time"] }
tokio-stream = { version = "0.1", features = ["sync"] }
tokio-tungstenite = { version = "0.29", default-features = false, features = ["connect", "rustls-tls-webpki-roots"] }
url = "2.5"

# iOS FFI 需要的 C 兼容类型
libc = "0.2"

# 移除 [target.'cfg(any(target_os = "linux", ...))'.dependencies]
# 因为 iOS 不需要 file-icon/fontdb/png 桌面专有依赖
```

### 关键变更

1. **移除 `flutter_rust_bridge`**：不再依赖 FRB
2. **crate-type 只保留 `staticlib`**：iOS 用静态库，不需要 cdylib
3. **添加 `libc`**：C ABI 类型支持（`c_char`, `c_int` 等）
4. **移除桌面平台条件依赖**：`file-icon`、`fontdb`、`png` 仅桌面端需要

### 验收

```bash
cargo check --manifest-path core/Cargo.toml
# 应无 flutter_rust_bridge 相关错误
```

---

## 步骤 3：新建 `core/src/ios_ffi.rs` — C ABI FFI 层

### 设计原则

1. **所有导出函数使用 `#[no_mangle] extern "C"` 前缀**
2. **字符串传递用 `*const c_char`（入参）和 `*mut c_char`（出参）**
3. **出参字符串通过 `sparxie_free_string` 释放，避免 Swift 侧手动 free**
4. **错误返回通过出参 `*mut *mut c_char`（可选），空指针表示成功**
5. **异步操作通过回调函数指针实现**：`typedef void (*SparxieCallback)(const char* result, const char* error)`
6. **流式数据通过回调指针实现**：`typedef void (*SparxieStreamCallback)(const char* data, bool done)`

### FFI 函数清单（映射自 Rust API）

#### 初始化与缓存

```rust
// 初始化应用（设置缓存目录）
#[no_mangle]
pub extern "C" fn sparxie_init_app(cache_dir: *const c_char);

// 初始化图标缓存
#[no_mangle]
pub extern "C" fn sparxie_init_cache(cache_dir: *const c_char) -> i32;

// 释放 C 字符串
#[no_mangle]
pub extern "C" fn sparxie_free_string(s: *mut c_char);
```

#### 控制器目标

```rust
// 创建 MihomoTarget（返回不透明指针）
#[no_mangle]
pub extern "C" fn sparxie_target_create(
    base_url: *const c_char,
    secret: *const c_char,    // 可空
    allow_insecure: bool,
) -> *mut SparxieTarget;

// 销毁 MihomoTarget
#[no_mangle]
pub extern "C" fn sparxie_target_free(target: *mut SparxieTarget);
```

#### 版本与升级

```rust
// 获取后端版本
#[no_mangle]
pub extern "C" fn sparxie_version(
    target: *const SparxieTarget,
    callback: SparxieCallback,
);

// 获取版本详细信息（JSON）
#[no_mangle]
pub extern "C" fn sparxie_version_info(
    target: *const SparxieTarget,
    callback: SparxieCallback,
);

// 升级核心
#[no_mangle]
pub extern "C" fn sparxie_upgrade_core(
    target: *const SparxieTarget,
    channel: *const c_char, // 可空
    force: bool,
    callback: SparxieCallback,
);

// 升级 UI
#[no_mangle]
pub extern "C" fn sparxie_upgrade_ui(
    target: *const SparxieTarget,
    callback: SparxieCallback,
);

// 升级 Geo 数据
#[no_mangle]
pub extern "C" fn sparxie_upgrade_geo(
    target: *const SparxieTarget,
    callback: SparxieCallback,
);

// 重启核心
#[no_mangle]
pub extern "C" fn sparxie_restart_core(
    target: *const SparxieTarget,
    callback: SparxieCallback,
);
```

#### 代理组与代理

```rust
// 获取代理目录（JSON）
#[no_mangle]
pub extern "C" fn sparxie_proxy_catalog(
    target: *const SparxieTarget,
    include_hidden: bool,
    filter: *const c_char,
    callback: SparxieCallback,
);

// 获取代理组成员（JSON）
#[no_mangle]
pub extern "C" fn sparxie_proxy_group_members(
    target: *const SparxieTarget,
    group: *const c_char,
    offset: u32,
    limit: u32,
    member_sort: i32, // 0=Original, 1=Name, 2=Delay
    callback: SparxieCallback,
);

// 选择代理
#[no_mangle]
pub extern "C" fn sparxie_select_proxy(
    target: *const SparxieTarget,
    group: *const c_char,
    name: *const c_char,
    callback: SparxieCallback,
);

// 取消固定代理
#[no_mangle]
pub extern "C" fn sparxie_unfix_proxy(
    target: *const SparxieTarget,
    name: *const c_char,
    callback: SparxieCallback,
);

// 代理延迟测试
#[no_mangle]
pub extern "C" fn sparxie_proxy_delay(
    target: *const SparxieTarget,
    name: *const c_char,
    test_url: *const c_char,
    timeout_ms: u32,
    expected_status: *const c_char, // 可空
    callback: SparxieCallback,
);

// 批量延迟测试
#[no_mangle]
pub extern "C" fn sparxie_proxy_batch_delay(
    target: *const SparxieTarget,
    names_json: *const c_char, // JSON 数组
    test_url: *const c_char,
    timeout_ms: u32,
    expected_status: *const c_char,
    concurrency: u32,
    callback: SparxieCallback,
);

// 代理组批量延迟
#[no_mangle]
pub extern "C" fn sparxie_proxy_group_delay(
    target: *const SparxieTarget,
    group: *const c_char,
    test_url: *const c_char,
    timeout_ms: u32,
    expected_status: *const c_char,
    concurrency: u32,
    callback: SparxieCallback,
);

// 代理组延迟流式回调
#[no_mangle]
pub extern "C" fn sparxie_proxy_group_delay_stream(
    target: *const SparxieTarget,
    group: *const c_char,
    test_url: *const c_char,
    timeout_ms: u32,
    expected_status: *const c_char,
    concurrency: u32,
    member_sort: i32,
    window_offset: u32,
    window_limit: u32,
    window_members_hash: u32,
    stream_callback: SparxieStreamCallback,
);
```

#### 连接

```rust
// 获取连接列表（JSON）
#[no_mangle]
pub extern "C" fn sparxie_connections(
    target: *const SparxieTarget,
    callback: SparxieCallback,
);

// 关闭单个连接
#[no_mangle]
pub extern "C" fn sparxie_close_connection(
    target: *const SparxieTarget,
    id: *const c_char,
    callback: SparxieCallback,
);

// 关闭所有连接
#[no_mangle]
pub extern "C" fn sparxie_close_all_connections(
    target: *const SparxieTarget,
    callback: SparxieCallback,
);

// 按 chain 关闭连接
#[no_mangle]
pub extern "C" fn sparxie_close_connections_by_chain(
    target: *const SparxieTarget,
    chain: *const c_char,
    callback: SparxieCallback,
);

// 按 group 关闭连接
#[no_mangle]
pub extern "C" fn sparxie_close_connections_by_group(
    target: *const SparxieTarget,
    group: *const c_char,
    callback: SparxieCallback,
);

// 连接数据窗口
#[no_mangle]
pub extern "C" fn sparxie_connection_window(
    target: *const SparxieTarget,
    interval_ms: u32,
    kind: i32, // 0=Active, 1=Closed
    offset: u32,
    limit: u32,
    callback: SparxieCallback,
);

// 连接分组
#[no_mangle]
pub extern "C" fn sparxie_connection_groups(
    target: *const SparxieTarget,
    interval_ms: u32,
    sort: i32,
    asc: bool,
    callback: SparxieCallback,
);

// 连接流式订阅
#[no_mangle]
pub extern "C" fn sparxie_connections_stream(
    target: *const SparxieTarget,
    interval_ms: u32,
    stream_callback: SparxieStreamCallback,
);

// 停止指定目标的流
#[no_mangle]
pub extern "C" fn sparxie_stop_target_streams(target: *const SparxieTarget);
```

#### 规则

```rust
#[no_mangle]
pub extern "C" fn sparxie_rules_count(
    target: *const SparxieTarget,
    callback: SparxieCallback,
);

#[no_mangle]
pub extern "C" fn sparxie_rules_load(
    target: *const SparxieTarget,
    filter: *const c_char,
    callback: SparxieCallback,
);

#[no_mangle]
pub extern "C" fn sparxie_rules_window(
    target: *const SparxieTarget,
    offset: u32,
    limit: u32,
    callback: SparxieCallback,
);

#[no_mangle]
pub extern "C" fn sparxie_rules_disable(
    target: *const SparxieTarget,
    indices_json: *const c_char,
    callback: SparxieCallback,
);
```

#### 配置

```rust
#[no_mangle]
pub extern "C" fn sparxie_configs(
    target: *const SparxieTarget,
    callback: SparxieCallback,
);

#[no_mangle]
pub extern "C" fn sparxie_config_mode(
    target: *const SparxieTarget,
    callback: SparxieCallback,
);

#[no_mangle]
pub extern "C" fn sparxie_patch_configs(
    target: *const SparxieTarget,
    body_json: *const c_char,
    callback: SparxieCallback,
);

#[no_mangle]
pub extern "C" fn sparxie_reload_configs(
    target: *const SparxieTarget,
    path: *const c_char,     // 可空
    payload: *const c_char,  // 可空
    force: bool,
    callback: SparxieCallback,
);

#[no_mangle]
pub extern "C" fn sparxie_update_geo(
    target: *const SparxieTarget,
    callback: SparxieCallback,
);
```

#### 日志

```rust
#[no_mangle]
pub extern "C" fn sparxie_logs_stream(
    target: *const SparxieTarget,
    level: *const c_char,
    stream_callback: SparxieStreamCallback,
);

#[no_mangle]
pub extern "C" fn sparxie_clear_logs(
    target: *const SparxieTarget,
    level: *const c_char,
);
```

#### 流量与内存

```rust
#[no_mangle]
pub extern "C" fn sparxie_traffic_stream(
    target: *const SparxieTarget,
    stream_callback: SparxieStreamCallback,
);

#[no_mangle]
pub extern "C" fn sparxie_memory_stream(
    target: *const SparxieTarget,
    stream_callback: SparxieStreamCallback,
);
```

#### 图标缓存

```rust
#[no_mangle]
pub extern "C" fn sparxie_fetch_icon(
    target: *const SparxieTarget,
    url: *const c_char,
    callback: SparxieCallback,
);

#[no_mangle]
pub extern "C" fn sparxie_icon_cache_size(callback: SparxieCallback);

#[no_mangle]
pub extern "C" fn sparxie_clear_icon_cache(callback: SparxieCallback);
```

#### 缓存与存储

```rust
#[no_mangle]
pub extern "C" fn sparxie_flush_fakeip(
    target: *const SparxieTarget,
    callback: SparxieCallback,
);

#[no_mangle]
pub extern "C" fn sparxie_flush_dns(
    target: *const SparxieTarget,
    callback: SparxieCallback,
);

#[no_mangle]
pub extern "C" fn sparxie_storage_get(
    target: *const SparxieTarget,
    key: *const c_char,
    callback: SparxieCallback,
);

#[no_mangle]
pub extern "C" fn sparxie_storage_set(
    target: *const SparxieTarget,
    key: *const c_char,
    value_json: *const c_char,
    callback: SparxieCallback,
);

#[no_mangle]
pub extern "C" fn sparxie_storage_delete(
    target: *const SparxieTarget,
    key: *const c_char,
    callback: SparxieCallback,
);

#[no_mangle]
pub extern "C" fn sparxie_dns_query(
    target: *const SparxieTarget,
    name: *const c_char,
    record_type: *const c_char, // 可空
    callback: SparxieCallback,
);
```

#### Provider

```rust
#[no_mangle]
pub extern "C" fn sparxie_proxy_providers(
    target: *const SparxieTarget,
    callback: SparxieCallback,
);

#[no_mangle]
pub extern "C" fn sparxie_proxy_provider_catalog(
    target: *const SparxieTarget,
    callback: SparxieCallback,
);

#[no_mangle]
pub extern "C" fn sparxie_proxy_provider_update(
    target: *const SparxieTarget,
    name: *const c_char,
    callback: SparxieCallback,
);

#[no_mangle]
pub extern "C" fn sparxie_rule_providers(
    target: *const SparxieTarget,
    callback: SparxieCallback,
);

#[no_mangle]
pub extern "C" fn sparxie_rule_provider_catalog(
    target: *const SparxieTarget,
    callback: SparxieCallback,
);

#[no_mangle]
pub extern "C" fn sparxie_rule_provider_update(
    target: *const SparxieTarget,
    name: *const c_char,
    callback: SparxieCallback,
);
```

### 验收

```bash
cargo check --manifest-path core/Cargo.toml --target aarch64-apple-ios
# 无编译错误
```

---

## 步骤 4：清理 `core/src/lib.rs`

### 变更内容

```rust
//! mihomo controller backend, exposed to iOS via C ABI.

mod assets;
mod cache;
mod client;
mod state;
mod utils;

pub mod api;
pub mod ios_ffi;

pub use utils::error::MihomoError;

// 删除: mod frb_generated;
```

同时删除 `core/src/frb_generated.rs`（5600+ 行的 FRB 生成胶水代码）。

### 条件编译处理

`core/src/api/` 下的模块可能引用了 `flutter_rust_bridge` 类型（如 `StreamSink`），需要逐一改为回调函数指针或去掉 FRB 依赖。具体策略：

- `StreamSink<T>` → 不再作为参数，改为注册回调方式
- `MihomoTarget` → 保留，但作为 FFI 不透明类型暴露
- 公共 API 函数签名不变，但 `#[no_mangle] extern "C"` 包装在 `ios_ffi.rs` 中

### 验收

```bash
cargo check --manifest-path core/Cargo.toml
# 不应有 flutter_rust_bridge 引用残留
```

---

## 步骤 5：新建 SwiftUI iOS 工程

### 目标目录结构

```text
native-ios/
├── Sparxie.xcodeproj/
│   └── project.pbxproj
├── Sparxie/
│   ├── App/
│   │   ├── SparxieApp.swift          # @main 入口
│   │   └── ContentView.swift         # TabView 主导航
│   ├── Core/
│   │   ├── RustCore.swift            # C ABI 加载与封装
│   │   └── SparxieBridge.h           # C 头文件（桥接头）
│   ├── Models/
│   │   ├── Controller.swift          # 控制器模型
│   │   ├── ControllerStore.swift     # 控制器持久化
│   │   ├── AppPrefs.swift            # 应用偏好
│   │   ├── VersionInfo.swift         # 版本信息
│   │   ├── Connection.swift          # 连接模型
│   │   ├── ProxyGroup.swift          # 代理组模型
│   │   ├── ProxyMember.swift         # 代理节点模型
│   │   ├── RuleEntry.swift           # 规则模型
│   │   ├── LogEntry.swift            # 日志模型
│   │   └── Provider.swift            # Provider 模型
│   ├── Session/
│   │   └── MihomoSession.swift       # 核心会话（ObservableObject）
│   ├── Views/
│   │   ├── DashboardView.swift       # 仪表盘
│   │   ├── ProxiesView.swift         # 代理组
│   │   ├── ConnectionsView.swift      # 连接列表
│   │   ├── RulesView.swift           # 规则列表
│   │   ├── LogsView.swift            # 日志
│   │   ├── ResourcesView.swift       # 资源 Provider
│   │   ├── CoreConfigView.swift      # 核心配置
│   │   ├── CoreActionsView.swift     # 核心操作
│   │   └── SettingsView.swift         # 设置
│   ├── Components/
│   │   ├── DelayBadge.swift          # 延迟徽标
│   │   ├── ProxyNodeTile.swift       # 代理节点卡
│   │   ├── ConnectionTile.swift      # 连接卡片
│   │   ├── SectionPanel.swift        # 通用面板
│   │   └── ProxyAvatar.swift         # 代理头像
│   ├── Assets.xcassets/
│   │   └── AppIcon.appiconset/
│   │       └── Contents.json
│   ├── Info.plist
│   └── Sparxie.entitlements          # TrollStore 最小权限
├── SparxieTests/
│   └── SparxieTests.swift
└── SparxieUITests/
    └── SparxieUITests.swift
```

### Xcodeproj 配置关键点

- **Bundle ID**: `com.sparxie.native`
- **最低部署**: iOS 15.0
- **Swift 版本**: Swift 5.9+
- **接口**: SwiftUI
- **其他链接器标志**: `-lsparxie`（链接 Rust staticlib）
- **库搜索路径**: `$(PROJECT_DIR)/../core/target/aarch64-apple-ios/release/`
- **头搜索路径**: `$(PROJECT_DIR)/Sparxie/Core/`
- **桥接头**: `Sparxie/SparxieBridge.h`
- **Code Signing**: 无签名（TrollStore 安装不需要）

### Info.plist 关键项

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### Sparxie.entitlements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- 最小权限：仅网络 -->
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
</dict>
</plist>
```

**不包含** `platform-application`、`com.apple.private.*`、`com.apple.developer.networking.networkextension` 等高危权限。

### 验收

```bash
# 在 macOS 上打开 Xcode 验证工程结构
xcodebuild -project native-ios/Sparxie.xcodeproj -showBuildSettings
# 无错误输出
```

---

## 步骤 6：Swift 封装层 — RustCore.swift

### 架构设计

```swift
// RustCore.swift — Rust C ABI 封装层

import Foundation

// MARK: - C ABI 类型定义

typealias SparxieCallback = @convention(c) (UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Void
typealias SparxieStreamCallback = @convention(c) (UnsafePointer<CChar>?, Bool) -> Void

// MARK: - 不透明指针包装

class SparxieTarget {
    private var handle: OpaquePointer?

    init(baseUrl: String, secret: String? = nil, allowInsecure: Bool = false) {
        let secretC = secret?.withCString { $0 }
        handle = sparxie_target_create(baseUrl, secretC, allowInsecure)
    }

    deinit {
        sparxie_target_free(handle)
    }
}

// MARK: - RustCore 主接口

actor RustCore {
    static let shared = RustCore()

    private init() {}

    func initialize(cacheDir: String) {
        cacheDir.withCString { sparxie_init_app($0) }
    }

    // MARK: 版本
    func version(target: SparxieTarget) async throws -> String { ... }
    func versionInfo(target: SparxieTarget) async throws -> VersionInfo { ... }

    // MARK: 代理
    func proxyCatalog(target: SparxieTarget, includeHidden: Bool, filter: String) async throws -> ProxyCatalog { ... }
    func selectProxy(target: SparxieTarget, group: String, name: String) async throws { ... }
    func proxyDelay(target: SparxieTarget, name: String, testUrl: String, timeoutMs: UInt32) async throws -> Int64 { ... }
    // ... 其余 API 同理

    // MARK: 内部：异步回调转 async/await
    private func asyncCall(_ block: (SparxieCallback) -> Void) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let boxed = Box(continuation)
            // 回调在 Rust 线程触发，需要 dispatch 到主线程
            let callback: SparxieCallback = { result, error in
                DispatchQueue.main.async {
                    if let error = error {
                        continuation.resume(throwing: RustError.generic(String(cString: error)))
                    } else if let result = result {
                        continuation.resume(returning: String(cString: result))
                    }
                }
            }
            block(callback)
        }
    }
}

// MARK: - 错误类型

enum RustError: Error {
    case generic(String)
    case nullPointer
    case jsonDecodeError(String)
}
```

### 关键设计决策

1. **`actor RustCore`**：确保线程安全，所有 Rust 调用串行化
2. **`SparxieTarget` 为 class**：管理 `OpaquePointer` 生命周期，`deinit` 自动释放
3. **异步模式**：C 回调 → `withCheckedThrowingContinuation` → Swift `async/await`
4. **JSON 传递**：所有复杂数据通过 JSON 字符串在 C ABI 层传递，Swift 侧用 `Codable` 解码
5. **内存安全**：`sparxie_free_string` 被封装在内部，Swift 调用方无感知

### 验收

- 编译通过（需要 Rust staticlib 预构建或 stub）
- 所有 C 函数声明与 `ios_ffi.rs` 导出完全对应

---

## 步骤 7：Swift 数据模型

### 模型清单

| Swift 文件 | 对应 Dart | 关键字段 |
|------------|----------|---------|
| `Controller.swift` | `controller.dart` | `id, name, baseUrl, secret, allowInsecure` |
| `ControllerStore.swift` | `controller.dart (ControllerStore)` | `controllers: [Controller], activeId, add/update/delete/activate` |
| `AppPrefs.swift` | `app_prefs.dart` | `navLayout, proxiesSort, delayTestScope, connectionsSort, closeMode` |
| `VersionInfo.swift` | `api/version.dart` | `version, isCmfa, isStash, supportsCoreConfig/Actions/Management/CacheFlush/Memory` |
| `Connection.swift` | `state/connections/types.dart` | `id, metadata, chains, rule, chains, upload/download/uploadSpeed/downloadSpeed, start, process` |
| `ProxyGroup.swift` | 新模型 | `name, proxyType, icon, memberCount, now, testUrl, fixed` |
| `ProxyMember.swift` | 新模型 | `name, proxyType, delay` |
| `RuleEntry.swift` | 新模型 | `index, ruleType, payload, proxy, disabled, hitCount` |
| `LogEntry.swift` | `state/logs.dart` | `time, level, message` |
| `Provider.swift` | 新模型 | `name, vehicleType, updatable, updatedAt` |

### 持久化方案

| 数据 | 方式 | 路径 |
|------|------|------|
| 控制器列表 | `Codable` + JSON 文件 | `Application Support/sparxie/controllers.json` |
| 应用偏好 | `@AppStorage` / `UserDefaults` | 系统默认 |
| 控制器密钥 | `Keychain` | `kSecClassGenericPassword` |
| 缓存 | `Caches/` 目录 | `FileManager.default.urls(for: .cachesDirectory)` |

### 验收

- 所有模型实现 `Codable`
- `ControllerStore` 为 `ObservableObject`
- `AppPrefs` 为 `ObservableObject`

---

## 步骤 8：SwiftUI 页面（9个）

### 导航结构

```swift
// ContentView.swift — TabView 主导航
TabView(selection: $selectedTab) {
    DashboardView().tabItem { Label("仪表盘", systemImage: "gauge") }.tag(0)
    ProxiesView().tabItem { Label("代理", systemImage: "network") }.tag(1)
    ConnectionsView().tabItem { Label("连接", systemImage: "link") }.tag(2)
    RulesView().tabItem { Label("规则", systemImage: "list.bullet") }.tag(3)
    LogsView().tabItem { Label("日志", systemImage: "text.alignleft") }.tag(4)
    SettingsView().tabItem { Label("设置", systemImage: "gearshape") }.tag(5)
}
```

### 页面与 API 对应

| 页面 | 关键 API | 核心功能 |
|------|---------|---------|
| **DashboardView** | `trafficStream`, `memoryStream`, `connectionsStream`, `versionInfo` | 流量图、内存、连接统计、版本 |
| **ProxiesView** | `proxyCatalog`, `proxyGroupMembers`, `selectProxy`, `unfixProxy`, `proxyDelay`, `proxyGroupDelay` | 代理组网格、搜索、测速、切换 |
| **ConnectionsView** | `connectionsStream`, `connectionWindow`, `connectionGroups`, `closeConnection`, `closeAll` | 活动/已关闭切换、排序、分组、关闭 |
| **RulesView** | `rulesLoad`, `rulesWindow`, `rulesDisable` | 规则筛选、窗口分页、禁用 |
| **LogsView** | `logsStream`, `clearLogs` | 日志过滤、级别、暂停、清空 |
| **ResourcesView** | `proxyProviderCatalog`, `proxyProviderUpdate`, `ruleProviderCatalog`, `ruleProviderUpdate` | 订阅列表、更新 |
| **CoreConfigView** | `configs`, `patchConfigs` | 查看/修改核心配置 |
| **CoreActionsView** | `reloadConfigs`, `updateGeo`, `restartCore`, `upgradeCore`, `upgradeUI`, `upgradeGeo`, `flushDns`, `flushFakeip` | 核心操作按钮 |
| **SettingsView** | `systemFontFamilies`, `iconCacheSize`, `clearIconCache` + ControllerStore 管理 | 后端管理、应用设置 |

### 验收

- 所有 9 个页面至少有骨架代码
- 导航可切换
- 编译通过（无需 Rust 库也能编译 SwiftUI 层）

---

## 步骤 9：`scripts/build-native-ios-ipa.sh`

### 脚本职责

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. 安装 Rust iOS target
rustup target add aarch64-apple-ios

# 2. 编译 Rust staticlib
cargo build --release --target aarch64-apple-ios --manifest-path core/Cargo.toml

# 3. 验证静态库包含必要符号
nm -gU core/target/aarch64-apple-ios/release/libsparxie.a | grep sparxie_

# 4. Xcode 构建 Release（不签名）
xcodebuild build \
    -project native-ios/Sparxie.xcodeproj \
    -scheme Sparxie \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    DEVELOPMENT_TEAM=0000000000

# 5. 打包 IPA
APP_PATH=$(find build -name "Sparxie.app" | head -1)
mkdir -p build/ios/ipa/Payload
cp -R "$APP_PATH" build/ios/ipa/Payload/
cd build/ios/ipa
zip -r "sparxie-trollstore.ipa" Payload/
cd -

# 6. 输出路径
echo "IPA: $(pwd)/build/ios/ipa/sparxie-trollstore.ipa"
```

### 对比现有脚本的关键差异

| 现有 build-ios-ipa.sh | 新 build-native-ios-ipa.sh |
|----------------------|---------------------------|
| `flutter pub get` + `flutter build ios` | `xcodebuild build`（纯原生）|
| 依赖 Flutter SDK | 不依赖 Flutter |
| FRB 符号检查 `_frb_get_rust_content_hash` | FFI 符号检查 `sparxie_` |
| `Release.xcconfig` 追加签名跳过 | Xcodeproj 内配置（不累积追加）|
| 产物 `sparxie-ios.ipa` | 产物 `sparxie-trollstore.ipa` |

### 验收

```bash
./scripts/build-native-ios-ipa.sh
ls -la build/ios/ipa/sparxie-trollstore.ipa
# IPA 存在且 > 0 字节
```

---

## 步骤 10：`.github/workflows/build-native-ios.yml`

### Workflow 设计

```yaml
name: Build Native iOS IPA

on:
  push:
    tags: ['v*']
  workflow_dispatch:

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Rust
        uses: dtolnay/rust-toolchain@stable
        with:
          targets: aarch64-apple-ios

      - name: Build Rust core
        run: cargo build --release --target aarch64-apple-ios --manifest-path core/Cargo.toml

      - name: Verify FFI symbols
        run: nm -gU core/target/aarch64-apple-ios/release/libsparxie.a | grep sparxie_

      - name: Build iOS app
        run: |
          xcodebuild build \
            -project native-ios/Sparxie.xcodeproj \
            -scheme Sparxie \
            -configuration Release \
            -destination 'generic/platform=iOS' \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGNING_REQUIRED=NO

      - name: Package IPA
        run: |
          mkdir -p build/ios/ipa/Payload
          APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Sparxie.app" | head -1)
          cp -R "$APP_PATH" build/ios/ipa/Payload/
          cd build/ios/ipa
          zip -r sparxie-trollstore.ipa Payload/

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: sparxie-trollstore
          path: build/ios/ipa/sparxie-trollstore.ipa

  release:
    needs: build
    runs-on: macos-latest
    if: startsWith(github.ref, 'refs/tags/v')
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: sparxie-trollstore
      - name: Create release
        uses: softprops/action-gh-release@v2
        with:
          files: sparxie-trollstore.ipa
```

### 验收

```bash
# 本地验证 workflow 语法
gh workflow lint .github/workflows/build-native-ios.yml
```

---

## 步骤 11：更新 `.gitignore` 和 `README.md`

### .gitignore 变更

**删除** Flutter 相关忽略项：
```gitignore
# 删除以下内容
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
build/
*.iml
.gradle
local.properties
```

**添加** iOS 原生相关忽略项：
```gitignore
# iOS
native-ios/Sparxie.xcodeproj/xcuserdata/
native-ios/Sparxie.xcodeproj/project.xcworkspace/xcuserdata/
build/
DerivedData/
*.ipa
*.dSYM.zip
```

### README.md 重写要点

1. **标题**: Sparxie — iOS 原生代理控制器
2. **架构图**: SwiftUI → Swift Session → RustCore → C ABI → Rust core → HTTP/WS → mihomo
3. **开发环境**: Xcode 15+, Rust stable, macOS
4. **Rust 编译**: `cargo build --release --target aarch64-apple-ios --manifest-path core/Cargo.toml`
5. **Xcode 构建**: 在 Xcode 中打开 `native-ios/Sparxie.xcodeproj`
6. **IPA 构建**: `./scripts/build-native-ios-ipa.sh`
7. **CI/CD**: 推送 `v*` tag 触发 GitHub Actions 构建
8. **TrollStore 安装**: 传输 IPA 到设备 → TrollStore 安装
9. **删除**: Flutter 相关开发说明、Android/Linux/Windows/macOS/Web 构建说明

---

## 执行顺序与并行度

```
步骤 1（清理）→ 步骤 2（Cargo.toml）→ 步骤 3（ios_ffi.rs）→ 步骤 4（lib.rs）
                                                                    ↓
步骤 5（Xcodeproj）← 可与步骤 3-4 并行
步骤 6（RustCore.swift）→ 依赖步骤 3 的 FFI 函数清单
步骤 7（数据模型）→ 可与步骤 6 并行
步骤 8（页面）→ 依赖步骤 6、7
步骤 9（构建脚本）→ 依赖步骤 2、5
步骤 10（CI）→ 依赖步骤 9
步骤 11（文档）→ 最后执行
```

## 风险点

1. **FRB 内部类型依赖**：Rust API 层广泛使用 `StreamSink`，需要全部改为回调模式
2. **Xcodeproj 手动编写**：.pbxproj 是复杂格式，可能需要用 `xcodegen` 或在 macOS 上用 Xcode 生成
3. **条件编译**：iOS 不需要 `file-icon`/`fontdb`/`png`，需要用 `cfg` 守卫确保编译通过
4. **Rust tokio 运行时**：iOS 需要 `tokio` runtime 在主线程外启动，FFI 层需要管理 runtime 生命周期

---

*[合规验证] 语言(第1条)✅ 中文思考(第1条)✅ 变更验证(第4条)N/A 中断(第5条)✅ 自检声明✅ 累计违规:0*