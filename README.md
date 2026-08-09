# 合盖守护 LidGuard

LidGuard 是一个仅面向当前 Mac 的轻量菜单栏应用，用于显式切换：

- 合盖运行：`pmset -a disablesleep 1`
- 正常合盖休眠：`pmset -a disablesleep 0`

它不会创建虚拟显示器、捕获屏幕、阻止显示器休眠，也不会修改 `sleep`、`displaysleep` 等其他电源配置，因此适合与 vivo 远控 PC 和 Codex 等 Agent 配合使用。

## 安全策略

- 严格：必须设置 30 分钟至 8 小时，30% 低电量保护，热状态严重时恢复。
- 平衡：低电量默认 20%，热状态严重时恢复，支持不限时。
- 完全手动：低电量保护默认关闭，热状态严重时警告、临界时强制恢复。

所有策略的定时与保护都由 root helper 独立执行，菜单栏 App 退出后仍有效。

## 构建和安装

```bash
make test
make package
make install
```

安装过程需要一次管理员授权。产物位于 `dist/LidGuard.app`，安装后 CLI 位于 `/usr/local/bin/lidguard`。

## CLI

```bash
lidguard status
lidguard status --json
lidguard start --profile balanced --for 4h
lidguard start --profile manual --unlimited --confirm-risk
lidguard extend --for 2h
lidguard stop
lidguard doctor
```

LidGuard 不安装 Codex hooks。Agent 必须显式调用 CLI。

## 限制

本机 v1 使用临时签名，仅验证 Apple Silicon 和 macOS 15.6.1。`pmset disablesleep` 没有公开文档保证，系统升级后必须重新验证合盖和 vivo 远控行为。
