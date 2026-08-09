<div align="center">

# LidGuard · 合盖守护

**出门要合上 Mac，但 Codex 等本地 Agent 和手机远控不该被迫中断。LidGuard 让它在保护策略下继续工作。**

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-111111?logo=apple)](https://github.com/aermin/LidGuard)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-0A84FF)](https://github.com/aermin/LidGuard)
[![Swift 5.10](https://img.shields.io/badge/Swift-5.10-F05138?logo=swift&logoColor=white)](https://github.com/aermin/LidGuard)
[![Tests 16 passing](https://img.shields.io/badge/tests-16%20passing-22C55E)](https://github.com/aermin/LidGuard)

轻量菜单栏 App · 受限 root helper · CLI · 不接管显示器 · 不安装 Agent hooks

</div>

准备出门时，你可能必须合上 Mac 放进保护套或背包，但 **Codex 等本地 Agent、下载或构建任务仍在执行**；也可能把 Mac 留在家里或工位，希望继续通过手机远程查看和操作。macOS 默认会在合盖后进入睡眠，这些任务和远程连接也会随之停止。

LidGuard 让你主动选择 Mac 合盖后的行为：需要继续工作时保持运行，并通过定时、低电量和系统热状态保护，在触发条件后自动恢复正常休眠。它提供两个明确状态：

- **合盖运行**：合上屏幕后，Agent、任务和远程连接继续运行，同时启用你选择的保护策略。
- **正常休眠**：恢复 Mac 默认行为，合盖后正常进入睡眠。

LidGuard 只管理“合盖后是否继续运行”，不接管屏幕或改动其他睡眠设置。

> [!WARNING]
> 在保护套、背包或其他密闭空间内运行 Mac 可能积热。LidGuard 提供热状态保护，但不能消除物理散热风险；完全手动且不限时运行需要二次确认。

## 界面

<p align="center">
  <img src="docs/assets/lidguard-expanded.png" alt="LidGuard 完整展开控制面板" width="560">
</p>

<p align="center"><sub>完整展开面板：模式切换、设备状态、当前会话、保护策略、运行时长和低电量阈值集中在一个菜单中。</sub></p>

低电量阈值可直接在保护策略中调整：严格模式固定为 30%，平衡模式可在 10%–50% 间选择，完全手动模式开启低电量保护后使用同一阈值控件。

<table>
  <tr>
    <td align="center"><strong>合盖运行</strong></td>
    <td align="center"><strong>正常合盖休眠</strong></td>
  </tr>
  <tr>
    <td><img src="docs/assets/lidguard-active.png" alt="LidGuard 合盖运行界面" width="360"></td>
    <td><img src="docs/assets/lidguard-normal.png" alt="LidGuard 正常合盖休眠界面" width="360"></td>
  </tr>
  <tr>
    <td>显示当前策略、时长、低电量阈值、热状态和供电方式。</td>
    <td>不显示无意义的保护倒计时，需要时再展开合盖运行配置。</td>
  </tr>
</table>

## 为什么做 LidGuard

通用防休眠工具通常同时影响显示器、系统空闲休眠或其他电源行为。对于远程控制和 Agent 场景，真正需要的是一个边界清晰、容易恢复的开关：

| 目标 | LidGuard 的处理 |
| --- | --- |
| 合盖后任务继续执行 | 只切换系统 `SleepDisabled` 状态 |
| 远程桌面继续可见、可控 | 不创建显示器防休眠断言或虚拟显示器 |
| App 退出后保护仍生效 | 定时和保护策略由 LaunchDaemon helper 持久执行 |
| 不想每次输入管理员密码 | 首次安装 helper 时授权一次，之后通过受限 XPC 调用 |
| 发生低电量或过热 | 自动恢复 `disablesleep=0` 并记录停止原因 |
| 外部工具修改电源状态 | 不反复争抢；结束会话或标记为外部管理状态 |

## 三种保护策略

| 策略 | 时长 | 低电量保护 | 热状态保护 | 适合场景 |
| --- | --- | --- | --- | --- |
| **严格** | 必须设置 30 分钟至 8 小时 | 固定 30% | `serious` / `critical` 自动恢复 | 临时离开、风险优先 |
| **平衡** | 预设、自定义或不限时 | 默认 20%，可调 10%–50% | `serious` / `critical` 自动恢复 | 日常远控和 Agent 任务 |
| **完全手动** | 预设、自定义或不限时 | 默认关闭，可手动启用 | `serious` 警告，`critical` 强制恢复 | 用户明确接管风险 |

定时任务最长 7 天；到期前 5 分钟发送通知。低电量保护只在电池供电且未充电时触发。

## 工作原理

```mermaid
flowchart LR
    App["菜单栏 App"] -->|"start / stop / update / status"| XPC["受限 XPC 接口"]
    CLI["lidguard CLI"] -->|"固定结构请求"| XPC
    XPC --> Helper["root helper · LaunchDaemon"]
    Helper --> Policy["定时 / 电量 / 热状态策略"]
    Helper --> PM["pmset -a disablesleep 1 / 0"]
    PM --> Verify["读取 pmset -g 验证 SleepDisabled"]
    Verify --> State["持久化状态与最后停止原因"]
```

Helper 只接受固定的 `start`、`stop`、`update` 和 `status` 操作，不接受任意命令字符串或文件路径。每次修改后都会读取 `pmset -g` 验证结果，失败时不会虚假显示“合盖运行中”。

技术上，“合盖运行”和“正常休眠”分别执行 `pmset -a disablesleep 1` 和 `pmset -a disablesleep 0`。LidGuard 不创建虚拟显示器、不捕获屏幕、不修改 `sleep` / `displaysleep`，也不通过 `caffeinate` 添加额外睡眠断言。

## 快速开始

### 环境

- Apple Silicon Mac
- macOS 13 或更高版本
- Xcode Command Line Tools / Swift 5.10
- 当前本机版本仅使用临时签名，不是可分发安装包

### 构建、测试与安装

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
3. 安装受限 helper、LaunchDaemon 和 `/usr/local/bin/lidguard`。
4. 打开 LidGuard 菜单栏 App。

安装后，日常切换模式不应再次要求管理员授权。

本机 v1 使用临时签名，每次重新构建 App 都会产生新的代码哈希，因此执行 `make install` 更新开发版本时需要重新授权一次。LidGuard 会识别这种签名失配，并在主面板显示“重新授权 Helper”，不会把它误报为 helper 丢失。

## CLI

### 安装 CLI

CLI 不需要单独安装。完成上面的源码安装即可：

```bash
git clone https://github.com/aermin/LidGuard.git
cd LidGuard
make install
```

`make install` 会同时安装菜单栏 App、受限 helper 和 CLI，并将 CLI 放到：

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
> 不建议只从构建目录复制 CLI。CLI 需要与 helper 一同安装，并由安装流程登记代码签名要求；更新源码版本时也应重新执行 `make install`。

### 使用

```bash
# 查看当前模式、供电、热状态和保护策略
lidguard status
lidguard status --json

# 平衡模式运行 4 小时
lidguard start --profile balanced --for 4h

# 严格模式运行至指定时间
lidguard start --profile strict --until 2026-08-10T23:30:00+08:00

# 完全手动、不限时，需要显式确认风险
lidguard start --profile manual --unlimited --confirm-risk

# 在当前结束时间基础上延长 2 小时
lidguard extend --for 2h

# 立即恢复正常合盖休眠
lidguard stop

# 检查 helper、协议、CLI 和 SleepDisabled
lidguard doctor
```

LidGuard 不安装 Codex hooks。Agent 需要显式调用 CLI，不会因为任务开始或结束自动改变整台 Mac 的电源状态。

## 安全边界

- Helper 运行于 root，但只暴露四类结构化操作。
- Helper 校验调用者 UID 和安装时记录的代码签名要求。
- App、CLI 或 helper 重启后，会话、截止时间和保护策略仍可恢复。
- “恢复正常休眠”只执行 `disablesleep=0`，不会覆盖其他 `pmset` 设置。
- 外部程序关闭 `SleepDisabled` 时，LidGuard 结束当前会话，不会循环重开。
- 外部程序开启 `SleepDisabled` 时，界面标记为非 LidGuard 管理状态。
- 卸载 helper 前会先恢复正常休眠。

## 验证

自动测试覆盖策略矩阵、定时解析、低电量、四级热状态、状态恢复、外部覆盖和 `pmset` 回读错误，测试使用假的电源控制器与传感器，不会在测试期间真实修改系统电源状态。

```text
Tests: 16 passed, 0 failed
```

当前实机已验证：

- 合盖运行时，vivo 远控保持可见、可操作，Agent 继续执行。
- 正常休眠时，合盖后远控不可操作，系统恢复默认睡眠行为。
- App 退出后，helper 仍能执行定时、低电量和热状态保护。
- LidGuard 不新增 `caffeinate` 或显示器防休眠断言。

## 卸载

在 App 设置中选择 **“恢复休眠并卸载 Helper”**。该操作会先恢复 `disablesleep=0`，再删除 LaunchDaemon、helper 和 CLI；App 和源码会保留。

## 已知限制

> [!IMPORTANT]
> `pmset disablesleep` 没有 Apple 公开文档提供稳定性保证。系统升级后，应重新验证合盖、唤醒和远程控制行为。

- 当前只在 Apple Silicon、macOS 15.6.1 上完成实机验收。
- 本机 v1 使用临时签名，尚未完成 Developer ID 签名、公证和公开分发。
- LidGuard 使用 `ProcessInfo.thermalState` 的系统等级，不读取私有 SMC 摄氏温度。
- LidGuard 不能保证所有远程控制软件都能在合盖状态下保持图像输出。
- 即使软件未报告 `critical`，也不代表保护套或背包内运行是安全的。

## 项目结构

```text
LidGuardCore       共享模型、策略、时间解析和 XPC 协议
LidGuardApp        SwiftUI 菜单栏 App 与设置页
LidGuardHelper     特权 helper 入口
LidGuardHelperKit  电源控制、传感器、状态持久化和策略引擎
LidGuardCLI        lidguard 命令行工具
LidGuardTests      无副作用的策略与 helper 测试
```
