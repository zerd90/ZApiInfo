# ZApiInfo

[English](README.md) · [中文](README.zh-CN.md)

A macOS menu bar app that polls a usage JSON endpoint you configure, and shows remaining quota, daily spend, upload / download tokens, and other fields in the status bar and a dropdown.

It is not tied to a single vendor. Provide a URL and API Key; common fields get default display names, which you can rename.

On first launch the app uses Simplified Chinese if the system language is Chinese, otherwise English. You can change this later in Settings → General.

## Requirements

- macOS 14 or later
- Apple Silicon (the Release package is built for `arm64`)

## Install

Recommended (Apple Silicon / macOS 14+):

```bash
./scripts/package.sh --build
open dist/ZApiInfo-1.0.0-arm64.dmg
```

Drag **ZApiInfo** into **Applications**, then open it from Launchpad or the Applications folder. There is no Dock icon; look on the right side of the menu bar.

If macOS refuses to open it: System Settings → Privacy & Security → **Open Anyway**. The package is ad-hoc signed.

Quit: click the menu bar item → **Quit**.

Launch at login: Settings → General → **Launch at login**.

## First-time setup

1. Click the menu bar item → **Settings…**
2. Pick a preset (this rewrites the URL path and suggested fields, **without overwriting the Key**):
   - **New API token usage**: `/api/usage/token`
   - **New API user info**: `/api/user/self` (optional extra header `New-Api-User`)
   - **OpenAI-compatible Usage / Subscription**
   - **Custom**
3. Change the host to your site, e.g. `https://api.example.com/api/usage/token`
4. Paste the API Key (default `Authorization: Bearer …`, stored in the local Keychain)
5. **Test connection**, then **Save**. Testing does not write the URL and does not start polling.

Only fields checked for **Status bar** appear in the menu bar; **Menu** fields appear in the dropdown. Display names, formats, and scale factors can be changed under **Fields**.

If the API nests totals and today under one path (e.g. `usage.today.output_tokens` / `usage.total.input_tokens`, or a `"102400/1234"` string), they are split into “today …” and “total …” names.

Quota / cost fields follow a `unit` value in the JSON when present (e.g. `USD` → `$598.53`).

## Build from source

```bash
brew install xcodegen
chmod +x scripts/build.sh
./scripts/build.sh
open dist/ZApiInfo.app
```

Xcode command-line tools are required. The script generates the project, builds Release, and copies `dist/ZApiInfo.app`.

Create installers:

```bash
./scripts/package.sh --build
```

Outputs in `dist/`:

- `ZApiInfo.app`
- `ZApiInfo-1.0.0-arm64.zip`
- `ZApiInfo-1.0.0-arm64.dmg`

After changing the icon:

```bash
swift scripts/generate_icon.swift
./scripts/package.sh --build
```

## Where data lives

| What | Where |
| --- | --- |
| API Key | Local Keychain |
| URL, field checks, display names, daily snapshots | Sandboxed UserDefaults |

Nothing is uploaded. To wipe local data: Settings → General → **Clear local data…**.

## License

[MIT](LICENSE)
