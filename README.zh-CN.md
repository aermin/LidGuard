<div align="center">

**简体中文** · [English](README.md)

# LidGuard · 合盖守护

**放心合盖不中断任务，并可在会话期间按需防止无人值守时自动锁屏。**

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-111111?logo=apple)](https://github.com/aermin/LidGuard)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-0A84FF)](https://github.com/aermin/LidGuard)
[![Swift 5.10](https://img.shields.io/badge/Swift-5.10-F05138?logo=swift&logoColor=white)](https://github.com/aermin/LidGuard)
[![Tests 22 passing](https://img.shields.io/badge/tests-22%20passing-22C55E)](https://github.com/aermin/LidGuard)
[![License MIT](https://img.shields.io/badge/license-MIT-2EA44F)](LICENSE)

合盖持续运行 · 可选防自动锁屏 · 定时、低电量和热状态保护 · CLI

</div>

<p align="center">
  <img src="docs/assets/lidguard-open-laptop-candid.jpg" alt="为了让编程任务继续运行，开发者只能在街上端着一台留有缝隙的开盖电脑" width="560">
</p>

<p align="center"><sub>为了不让任务停掉，你也曾这样端着开盖电脑出门吗？LidGuard 让你放心合盖、持续运行任务，并可按需防止无人值守时自动锁屏。</sub></p>

macOS 默认会在合盖后进入睡眠，正在运行的 Codex 任务、构建、下载等后台工作，以及手机远控会随之中断。即使 Mac 保持唤醒，自动锁屏也可能中断无人值守的远程访问。LidGuard 分别管理这两个边界：会话期间的合盖运行，以及按需开启的防自动锁屏。

- **合盖运行**：合盖后继续运行 Codex 任务和其他后台工作，并让受支持的远程控制软件保持可用。
- **正常休眠**：恢复 macOS 默认行为，合盖后正常进入睡眠。

LidGuard 管理合盖休眠行为，并可在会话期间按需防止自动锁屏。它不会创建虚拟显示器、捕获屏幕或覆盖其他无关睡眠设置。

> [!WARNING]
> 在保护套、背包或其他密闭空间内运行 MacBook 可能积热。LidGuard 可以响应 macOS 报告的热压力，但无法保证温度或通风一定安全。完全手动且不限时运行需要二次确认。

## 快速开始

### 安装

1. 下载 [`LidGuard-1.1.0-arm64.dmg`](https://github.com/aermin/LidGuard/releases/download/v1.1.0/LidGuard-1.1.0-arm64.dmg)。
2. 打开 DMG，将 **LidGuard** 拖入 **Applications（应用程序）**。
3. 在“应用程序”中尝试打开 LidGuard。由于当前版本使用临时签名，macOS 可能会阻止启动。
4. 打开 **“系统设置 → 隐私与安全性”**，向下找到“安全性”，点击 **“仍要打开”**，验证身份并再次确认 **“打开”**。
5. 进入 LidGuard，点击 **“安装 Helper”**，并完成一次管理员授权。

安装 Helper 时会同时安装 LaunchDaemon 和 `lidguard` CLI。完成首次授权后，日常切换“合盖运行 / 正常休眠”不再需要管理员密码。

### 日常使用

1. 点击菜单栏中的 LidGuard 图标。
2. 选择 **“合盖运行”**，设置保护策略和运行时长，按需开启 **“防止自动锁屏”**，然后点击 **“开始合盖运行”**。
3. 不再需要持续运行时，选择 **“正常休眠”**，恢复 macOS 默认行为。

运行期间可以随时查看剩余时间、电量、供电方式、热状态和自动锁屏保护，也可以调整当前会话的保护策略。

### 环境

- Apple Silicon Mac
- macOS 13 或更高版本

### 从源码构建

源码构建需要 Xcode Command Line Tools 和 Swift 5.10。

```bash
git clone https://github.com/aermin/LidGuard.git
cd LidGuard

make test
make package
make install
```

`make install` 会：

1. 构建 `dist/LidGuard.app`。
2. 请求一次管理员授权。
3. 安装特权 helper、LaunchDaemon 和 `/usr/local/bin/lidguard`。
4. 打开 LidGuard 菜单栏 App。

完成首次安装后，日常切换模式不再需要管理员授权。

开发版本使用临时签名，每次重新构建都会改变 App 的代码签名。因此执行 `make install` 更新开发版本时，系统会再次请求管理员授权。如果已安装的 helper 不再识别重新构建的 App，LidGuard 会显示 **“重新授权 Helper”**，而不是误报 helper 丢失。

生成本机测试 DMG：

```bash
make dmg
```

产物为 `dist/LidGuard-1.1.0-arm64.dmg`，本机测试 DMG 使用临时签名。

## 界面

<p align="center">
  <img src="docs/assets/lidguard-expanded.png" alt="从菜单栏打开并展开保护策略的 LidGuard" width="560">
</p>

<p align="center"><sub>在一个界面中查看合盖会话、防自动锁屏开关与断言状态、时长、电量、供电和热状态保护。</sub></p>

低电量阈值可直接在保护策略面板中调整：严格模式固定为 30%，平衡模式可在 10%–50% 间选择，完全手动模式开启低电量保护后使用同一阈值控件。“防止自动锁屏”是独立的会话开关，需要主动开启，默认关闭。

<table>
  <tr>
    <td align="center"><strong>合盖运行</strong></td>
    <td align="center"><strong>正常合盖休眠</strong></td>
  </tr>
  <tr>
    <td><img src="docs/assets/lidguard-active.png" alt="菜单栏 LidGuard 的合盖运行界面" width="360"></td>
    <td><img src="docs/assets/lidguard-normal.png" alt="菜单栏 LidGuard 的正常合盖休眠界面" width="360"></td>
  </tr>
  <tr>
    <td>显示当前策略、时长、低电量阈值、热状态、供电方式和实时防自动锁屏状态。</td>
    <td>保持简洁的待机状态，只在需要时展开会话配置。</td>
  </tr>
</table>

## 三种保护策略

| 策略 | 时长 | 低电量保护 | 热状态保护 | 适合场景 |
| --- | --- | --- | --- | --- |
| **严格** | 必须设置：30 分钟至 8 小时 | 固定 30% | `serious` / `critical` 时恢复正常休眠 | 临时离开，安全优先 |
| **平衡** | 预设、自定义或不限时 | 默认 20%，可调 10%–50% | `serious` / `critical` 时恢复正常休眠 | 日常远控和 Agent 任务 |
| **完全手动** | 预设、自定义或不限时 | 默认关闭，可手动启用 | `serious` 时警告，`critical` 时始终恢复休眠 | 希望直接控制策略的高级用户 |

定时会话最长 7 天；结束前 5 分钟发送通知。低电量保护只在电池供电且未充电时生效。

开启 **“防止自动锁屏”** 后，helper 会保持显示器唤醒，并每 30 秒刷新一次 macOS 用户活跃状态。运行期间可随时切换；定时结束、低电量、温度保护、外部覆盖、手动停止或卸载时都会释放相关断言。该选项会增加耗电，也不会阻止用户主动锁屏或其他安全操作。

## CLI

### 安装 CLI

在 App 中点击 **“安装 Helper”** 时会自动安装 CLI。源码构建也可以通过以下命令安装相同组件：

```bash
git clone https://github.com/aermin/LidGuard.git
cd LidGuard
make install
```

`make install` 会同时安装菜单栏 App、特权 helper 和 CLI，并将 CLI 放到：

```text
/usr/local/bin/lidguard
```

安装完成后可以这样确认：

```bash
command -v lidguard
lidguard doctor
lidguard status
```

如果终端提示 `command not found`，先直接执行 `/usr/local/bin/lidguard doctor`。若直接执行可用，请确认 shell 的 `PATH` 包含 `/usr/local/bin`。

> [!NOTE]
> 不要单独从构建目录复制 CLI。它必须与 helper 一同安装，安装器才能登记 CLI 的代码签名要求；更新源码版本时也应重新执行 `make install`。

### 使用

```bash
# 查看当前模式、供电、热状态和保护策略
lidguard status
lidguard status --json

# 启动 4 小时的平衡模式会话
lidguard start --profile balanced --for 4h

# 启动相同会话并防止自动锁屏
lidguard start --profile balanced --for 4h --prevent-auto-lock

# 启动在指定时间结束的严格模式会话
lidguard start --profile strict --until 2026-08-10T23:30:00+08:00

# 启动不限时的完全手动会话，并显式确认风险
lidguard start --profile manual --unlimited --confirm-risk

# 在当前结束时间基础上延长 2 小时
lidguard extend --for 2h

# 不结束当前会话，仅关闭防自动锁屏
lidguard extend --unlimited --allow-auto-lock

# 立即恢复正常合盖休眠
lidguard stop

# 检查 helper、协议、CLI 和 SleepDisabled
lidguard doctor
```

LidGuard 有意不安装 Codex hooks。Agent 可以显式调用 CLI，但任务开始或结束绝不会自动改变整台 Mac 的系统级睡眠行为。

## 为什么做 LidGuard

通用防休眠工具通常会同时阻止显示器休眠、系统空闲休眠，或两者都阻止。远程控制和 Agent 场景更适合边界更窄、恢复行为可预期的控制方式：

| 目标 | LidGuard 的处理 |
| --- | --- |
| 合盖后任务继续执行 | 切换系统 `SleepDisabled` 状态 |
| 按需防止无人值守时自动锁屏 | 持有原生显示器断言并刷新用户活跃状态 |
| 避免干扰远程桌面输出 | 不创建虚拟显示器，也不捕获屏幕内容 |
| App 退出后保护仍生效 | LaunchDaemon helper 持久化会话及其策略 |
| 不想每次输入管理员密码 | 首次安装 helper 时授权一次，之后使用受限 XPC 接口 |
| 发生低电量或热压力 | 恢复 `disablesleep=0` 并记录原因 |
| 尊重其他工具的状态修改 | 不反复覆盖；结束会话或标记为外部管理状态 |

## 安全边界

- Helper 运行于 root，但只暴露一组固定的结构化操作。
- Helper 校验调用者的 UID 和安装时记录的代码签名要求。
- App、CLI 和 helper 重启后，会话状态、截止时间、保护策略和防自动锁屏选择仍可恢复。
- “恢复正常休眠”只执行 `disablesleep=0`，不会覆盖其他 `pmset` 设置。
- 防自动锁屏默认关闭，其 IOKit 断言会在受管会话停止时一并释放。
- 外部程序清除 `SleepDisabled` 时，LidGuard 结束当前会话，不会反复重新设置。
- 外部程序设置 `SleepDisabled` 时，界面会提示当前状态不由 LidGuard 管理。
- 卸载 helper 前会先恢复正常休眠。

## 验证

自动测试覆盖策略矩阵、定时解析、低电量、macOS 四级热状态、状态恢复、外部覆盖和 `pmset` 验证失败。测试使用模拟的电源控制器与传感器，不会修改真实系统电源状态。

```text
Tests: 22 passed, 0 failed
```

当前开发机已验证：

- 合盖运行时，vivo 远控保持可见、可操作，本地编程 Agent 继续执行。
- 正常休眠时，合盖后远控不可操作，macOS 按默认行为进入睡眠。
- App 退出后，helper 仍能执行定时、低电量、热状态和防自动锁屏保护。
- 开发机已连续一晚验证防自动锁屏生效，期间没有启动 `caffeinate` 进程。

## 卸载

在 App 设置中选择 **“恢复休眠并卸载 Helper”**。该操作会先恢复 `disablesleep=0`，再删除 LaunchDaemon、helper 和 CLI；App 本体和源码目录会保留。

## 已知限制

> [!IMPORTANT]
> Apple 没有将 `pmset disablesleep` 作为稳定的公开接口提供文档。每次升级 macOS 后，都应重新验证合盖、唤醒和远程控制行为。

- LidGuard 读取 `ProcessInfo.thermalState` 报告的系统热压力等级，不读取私有 SMC 摄氏温度。
- 防自动锁屏会保持显示器唤醒并增加耗电；用户主动锁屏及其他安全操作不会被阻止。

## 项目结构

```text
LidGuardCore       共享模型、策略、时间解析和 XPC 协议
LidGuardApp        SwiftUI 菜单栏 App 与设置页
LidGuardHelper     特权 helper 可执行程序
LidGuardHelperKit  电源控制、传感器、状态持久化和策略引擎
LidGuardCLI        lidguard 命令行工具
LidGuardTests      无副作用的策略与 helper 测试
```

## 工作原理

```mermaid
flowchart LR
    App["菜单栏 App"] -->|"start / stop / update / status"| XPC["受限 XPC 接口"]
    CLI["lidguard CLI"] -->|"固定结构请求"| XPC
    XPC --> Helper["特权 Helper · LaunchDaemon"]
    Helper --> Policy["定时 / 电量 / 热状态策略"]
    Helper --> PM["pmset -a disablesleep 1 / 0"]
    Helper --> IOKit["可选显示器断言 / 用户活跃刷新"]
    PM --> Verify["读取 pmset -g 验证 SleepDisabled"]
    Verify --> State["持久化会话状态与停止原因"]
```

## 开源许可

LidGuard 使用 [MIT License](LICENSE) 开源。
