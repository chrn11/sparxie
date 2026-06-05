# Sparxie

iOS 原生代理控制器。SwiftUI UI + Rust 后端，通过 C ABI 在进程内直连。

## 支持的后端

| 后端 | 状态 | 说明 |
|---|---|---|
| mihomo | ✅ 完整支持 | 代理组、节点、规则、连接、日志、流量、配置、缓存、内存、升级 / 重启 |
| Clash Meta for Android (CMFA) | ✅ 基础支持 | 代理组、连接、日志、流量可用；核心管理和部分配置操作不可用 |
| Stash | ✅ 基础支持 | 代理组、Provider 节点、连接、日志、流量、基础配置可用；内存、缓存、核心管理不可用 |

## 平台

| 平台 | 状态 |
|---|---|
| iOS 15+ (arm64) | ✅ TrollStore IPA |

## 架构

```
SwiftUI UI
    ↓
Swift Session / Store / ViewModel
    ↓
RustCore Swift 封装层
    ↓
C ABI FFI
    ↓
Rust core (staticlib)
    ↓
HTTP / WebSocket
    ↓
mihomo / Stash / CMFA 后端
```

所有后端通信、代理组解析、连接排序 / 分页、图标缓存都在 Rust 端；Swift 只做渲染和状态管理。

## 开发环境

- Xcode 15+
- Rust stable 工具链 + `aarch64-apple-ios` target
- macOS（构建 IPA 必需）

## 本地开发

### 1. 编译 Rust 静态库

```bash
rustup target add aarch64-apple-ios
cargo build --release --target aarch64-apple-ios --manifest-path core/Cargo.toml
```

产物在 `core/target/aarch64-apple-ios/release/libsparxie.a`。

### 2. 用 Xcode 打开项目

```bash
open native-ios/Sparxie.xcodeproj
```

在 Xcode 中选择 Sparxie scheme 和 iOS device 目标，直接运行。

### 3. 构建 IPA（TrollStore）

```bash
./scripts/build-native-ios-ipa.sh
```

产物输出到 `build/ios/ipa/sparxie-trollstore.ipa`。

## GitHub Actions 自动构建

推送 `v*` tag 触发 GitHub Actions macOS runner 自动构建并上传 IPA：

```bash
git tag v1.0.0
git push origin v1.0.0
```

或手动触发 workflow：`.github/workflows/build-native-ios.yml`。

## TrollStore 安装

1. 将 IPA 传输到 iOS 设备
2. 用 TrollStore 安装
3. 启动后添加 mihomo / Stash / CMFA 后端地址

## 项目结构

```
sparxie-build/
├── core/                   # Rust 核心逻辑
│   ├── Cargo.toml
│   ├── build.rs
│   └── src/
│       ├── lib.rs          # 库入口
│       ├── ios_ffi.rs      # C ABI FFI 层（iOS Swift 调用入口）
│       ├── api/            # HTTP/WS API 封装
│       ├── client/         # HTTP/WS 客户端
│       ├── state/          # 流量/连接/日志状态管理
│       ├── cache/          # 缓存管理
│       └── utils/          # 工具函数
├── native-ios/             # iOS 原生工程
│   ├── Sparxie.xcodeproj
│   └── Sparxie/
│       ├── App/            # @main 入口与导航
│       ├── Core/           # RustCore 封装 + C 桥接头
│       ├── Models/         # 数据模型（Codable）
│       ├── Session/        # MihomoSession（ObservableObject）
│       ├── Views/          # SwiftUI 页面
│       └── Components/     # 可复用组件
├── assets/                 # 应用资源（图标等）
├── scripts/                # 构建脚本
│   └── build-native-ios-ipa.sh
├── .github/workflows/
│   └── build-native-ios.yml
├── README.md
└── LICENSE
```

## 权限说明

Sparxie 仅使用最小 entitlements（网络权限），不默认添加 `platform-application`、`com.apple.private.*` 或 `com.apple.developer.networking.networkextension` 等高权限。