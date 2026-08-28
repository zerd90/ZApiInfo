# ZApiInfo

[English](README.md) · [中文](README.zh-CN.md)

常驻 macOS 菜单栏，定时请求你配置的用量 JSON 接口，把剩余额度、日费、上传 / 下载 token 等显示在状态栏和下拉明细里。

不绑定单一厂商。给 URL 和 API Key 即可；常见字段会自动起中文名，也可自己改。

## 要求

- macOS 14 或更高
- Apple Silicon（当前 Release 按 `arm64` 打包）

## 安装

推荐用安装包（Apple Silicon / macOS 14+）：

```bash
./scripts/package.sh --build
open dist/ZApiInfo-1.0.0-arm64.dmg
```

把 **ZApiInfo** 拖进 **Applications**，再从启动台或「应用程序」打开。没有 Dock 图标，看菜单栏右侧。

若提示无法打开：系统设置 → 隐私与安全性 → **仍要打开**。安装包为本机 ad-hoc 签名。

退出：点菜单栏图标 → **退出**。

登录时启动：设置 → 通用 → **登录时启动**。

## 第一次使用

1. 点菜单栏图标 → **设置…**
2. 选一个预设（会改 URL 路径和推荐字段，**不会覆盖 Key**）：
   - **New API 令牌用量**：`/api/usage/token`
   - **New API 用户信息**：`/api/user/self`（可填额外头 `New-Api-User`）
   - **OpenAI 兼容 Usage / Subscription**
   - **自定义**
3. 把主机名改成你的站点，例如 `https://api.example.com/api/usage/token`
4. 填入 API Key（默认 `Authorization: Bearer …`，保存在本机钥匙串）
5. **测试连接**成功后再点 **保存**。测连不会写入 URL，也不会开始轮询。

状态栏只显示勾了「状态栏」的字段；勾了「明细」的会出现在下拉列表。显示名、格式、换算系数可在「展示字段」里改。

接口若把累计和今日写在一条路径里（如 `usage.today.output_tokens` / `usage.total.input_tokens`，或 `"102400/1234"` 这种字符串），会拆成「今日…」和「累计…」。响应里若有 `unit`（例如 `USD`），额度 / 费用会按该单位显示。

## 从源码编译

```bash
brew install xcodegen
chmod +x scripts/build.sh
./scripts/build.sh
open dist/ZApiInfo.app
```

需要 Xcode 命令行工具。脚本会生成工程、编 Release，并复制到 `dist/ZApiInfo.app`。

打安装包：

```bash
./scripts/package.sh --build
```

产物在 `dist/`：

- `ZApiInfo.app`
- `ZApiInfo-1.0.0-arm64.zip`
- `ZApiInfo-1.0.0-arm64.dmg`

改图标后可再跑一次：

```bash
swift scripts/generate_icon.swift
./scripts/package.sh --build
```

## 数据存在哪

| 内容 | 位置 |
| --- | --- |
| API Key | 本机钥匙串 |
| URL、字段勾选、显示名、日切快照 | 沙盒内 UserDefaults |

不会上传用量或密钥。清除方式：设置 → 通用 → **清除本地数据**。

## 许可

[MIT](LICENSE)
