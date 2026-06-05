# Sparxie iOS 原生化迁移计划

## 目标

将当前 Sparxie 项目从“Flutter UI + Rust 核心”的跨平台项目，迁移为“iOS 15+ 原生 SwiftUI 应用 + Rust 核心”的 iOS 原生项目。最终通过 GitHub Actions 构建可供 TrollStore 安装的 IPA。

## 已确认决策

- iOS 最低版本：iOS 15
- 旧平台代码：删除 Flutter、Android、Linux、Windows、macOS、Web 等跨平台工程
- 安装方式：TrollStore
- 权限策略：先使用最小 entitlements，不默认添加高危私有权限
- 构建方式：GitHub Actions macOS runner 自动构建 IPA

## 迁移范围

### 包含

- 原生 SwiftUI iOS 工程
- Rust 核心逻辑复用
- Swift 可调用的 C ABI FFI 层
- TrollStore IPA 打包脚本
- GitHub Actions 自动构建
- README 与构建文档更新

### 不包含

- App Store 发布
- Android、Linux、Windows、macOS、Web 继续维护
- Flutter UI 保留
- 系统级 VPN/NetworkExtension 能力
- 默认添加 TrollStore 私有高权限

## 目标目录结构

```text
sparxie-build/
├── native-ios/
│   ├── Sparxie.xcodeproj
│   ├── Sparxie/
│   ├── SparxieTests/
│   └── SparxieUITests/
├── core/
│   ├── Cargo.toml
│   └── src/
├── assets/
├── scripts/
│   └── build-native-ios-ipa.sh
├── .github/
│   └── workflows/
│       └── build-native-ios.yml
├── README.md
└── LICENSE
```

## 核心架构

```text
SwiftUI UI
   ↓
Swift Session / Store / ViewModel
   ↓
RustCore Swift 封装层
   ↓
C ABI FFI
   ↓
Rust core
   ↓
HTTP / WebSocket
   ↓
mihomo / Stash / CMFA 后端
```

## 实施步骤

### 1. 清理旧工程

删除以下跨平台工程与 Flutter 相关文件：

```text
android/
ios/
linux/
macos/
web/
windows/
lib/
test/
pubspec.yaml
pubspec.lock
analysis_options.yaml
flutter_rust_bridge.yaml
```

保留：

```text
core/
assets/
scripts/
.github/
README.md
LICENSE
```

### 2. 新建 iOS 原生工程

新增 `native-ios/`，创建 SwiftUI iOS 工程：

- 应用名：Sparxie
- 最低系统：iOS 15
- 语言：Swift
- UI 框架：SwiftUI
- Bundle ID：可暂定 `com.sparxie.native`

### 3. 改造 Rust FFI

保留 `core/` 中现有业务逻辑，但新增 Swift 可调用的 FFI 层。

建议新增：

```text
core/src/ios_ffi.rs
```

FFI 需要覆盖：

- 初始化缓存目录
- 设置控制器目标
- 获取版本信息
- 获取代理组
- 切换代理
- 获取连接列表
- 获取规则
- 获取日志
- 获取资源 Provider
- 获取核心配置
- 执行核心操作
- 错误返回
- 字符串内存释放

不要让 Swift 直接依赖 `flutter_rust_bridge` 或 Dart 生成代码。

### 4. Swift 侧封装 RustCore

在 Swift 中新增统一封装层：

```text
native-ios/Sparxie/Core/RustCore.swift
```

职责：

- 加载 Rust staticlib
- 调用 C ABI
- JSON 编解码
- 错误转换
- 内存释放
- 异步任务封装
- 防止 UI 层直接接触裸指针

### 5. 迁移数据模型与持久化

将 Dart 中的控制器配置和偏好设置迁移为 Swift 模型。

需要迁移的概念：

- Controller
- ControllerStore
- AppPrefs
- ConfigStore
- MihomoSession

持久化方案：

- 普通配置：`Codable` + Application Support
- 敏感字段：Keychain
- 缓存文件：Caches 目录

### 6. 迁移会话层

将原 `MihomoSession` 改为 Swift 会话对象：

```text
native-ios/Sparxie/Session/MihomoSession.swift
```

建议使用：

- `ObservableObject`
- `@Published`
- `Task`
- `actor`
- `AsyncStream`

需要支持：

- 控制器切换
- 自动刷新流量
- 自动刷新连接
- 自动刷新代理组
- 日志订阅或轮询
- 前后台恢复重连
- 错误状态展示

### 7. 迁移页面

按以下顺序迁移 UI：

1. 设置页
2. 控制器管理
3. 仪表盘
4. 代理组
5. 连接列表
6. 规则列表
7. 日志
8. 资源 Provider
9. 核心配置
10. 核心操作

对应原 Flutter 页面：

```text
dashboard_screen.dart
proxies_screen.dart
connections_screen.dart
rules_screen.dart
logs_screen.dart
resources_screen.dart
core_config_screen.dart
core_actions_screen.dart
settings_screen.dart
```

### 8. iOS 权限与 TrollStore 配置

`Info.plist` 至少需要包含网络权限说明。

建议先只使用普通最小权限，不添加：

```text
platform-application
com.apple.private.*
com.apple.developer.networking.networkextension
```

除非后续明确需要系统级代理、后台常驻或私有 API 能力。

### 9. 新增 IPA 构建脚本

新增：

```text
scripts/build-native-ios-ipa.sh
```

脚本职责：

1. 安装 Rust iOS target
2. 构建 Rust staticlib
3. 执行 `xcodebuild`
4. 生成 `.app`
5. 打包为：

```text
Payload/Sparxie.app
```

6. 输出：

```text
build/ios/ipa/sparxie-trollstore.ipa
```

### 10. 新增 GitHub Actions

新增：

```text
.github/workflows/build-native-ios.yml
```

要求：

- 使用 macOS runner
- 安装 Rust stable
- 添加 `aarch64-apple-ios`
- 构建 Rust core
- 构建 Swift iOS app
- 打包 IPA
- 上传 artifact

产物名：

```text
sparxie-trollstore.ipa
```

## 验收标准

### 构建验证

必须通过：

```bash
cargo test --manifest-path core/Cargo.toml
cargo build --release --target aarch64-apple-ios --manifest-path core/Cargo.toml
```

必须通过：

```bash
xcodebuild build
```

GitHub Actions 必须上传：

```text
sparxie-trollstore.ipa
```

IPA 结构必须是：

```text
Payload/Sparxie.app
```

### 真机验证

使用 TrollStore 安装后验证：

- 应用能启动
- 能添加控制器
- 能连接 mihomo / Stash / CMFA
- 仪表盘数据显示正常
- 代理组加载正常
- 代理切换可用
- 连接列表可用
- 规则列表可用
- 日志显示可用
- 资源 Provider 显示可用
- 设置保存后重启仍生效
- 前后台切换后能恢复连接

## 交给 GLM5.1 的执行提示词

```markdown
你需要把当前 Sparxie 项目迁移为 iOS 15+ 原生 SwiftUI 项目，并删除 Flutter、Android、Linux、Windows、macOS、Web 等跨平台工程，只保留 iOS 原生应用和 Rust 核心。

核心要求：

1. 删除旧跨平台工程，只保留：
   - native-ios/
   - core/
   - assets/
   - scripts/
   - .github/workflows/
   - README.md
   - LICENSE

2. 新建 iOS 15+ SwiftUI 原生工程，应用名 Sparxie。

3. 保留 Rust core，但移除对 Flutter/Dart/flutter_rust_bridge 的运行时依赖，新增 Swift 可调用的 C ABI FFI 层。

4. Swift 侧新增 RustCore 封装层，禁止 UI 直接调用裸 FFI 指针。

5. 使用 SwiftUI 重建现有功能页面：
   - 仪表盘
   - 代理组
   - 连接列表
   - 规则列表
   - 日志
   - 资源 Provider
   - 核心配置
   - 核心操作
   - 设置

6. 配置持久化改为 Codable + Application Support，secret 存 Keychain。

7. 新增 scripts/build-native-ios-ipa.sh，用于构建 TrollStore 可安装 IPA。

8. 新增 .github/workflows/build-native-ios.yml，用 GitHub Actions macOS runner 自动构建并上传 sparxie-trollstore.ipa。

9. TrollStore 权限先使用最小 entitlements，不要默认添加 platform-application 或 com.apple.private.* 等高危私有权限。

10. 更新 README，只保留 iOS 原生构建、GitHub Actions 构建和 TrollStore 安装说明。

验收标准：

1. cargo test --manifest-path core/Cargo.toml 通过。
2. cargo build --release --target aarch64-apple-ios --manifest-path core/Cargo.toml 通过。
3. xcodebuild 能构建 Release app。
4. GitHub Actions 能上传 sparxie-trollstore.ipa。
5. IPA 结构为 Payload/Sparxie.app。
6. TrollStore 真机安装后能启动。
7. 能添加控制器并连接 mihomo/Stash/CMFA。
8. 代理切换、连接列表、规则、日志、资源、设置保存均可用。
```
