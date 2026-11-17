---
name: dsh-machine-bootstrap
description: 在新电脑上一次性复刻当前 DSH 工作环境：安装 git / Node+npm / GitHub CLI，给 desktop profile 装上 dshmarket 与 dsh-cost-meter 插件，并验证技能目录与插件都已生效。当用户说「新机器部署 DSH」「一键装插件」「迁移 DSH 环境」时加载。
whenToUse: 用户要在另一台电脑上把 DSH 弄成和当前一致（含插件），或要求「一键安装」时。
---

# DSH 新机一键部署

目标：一台装了 DeepSeek Harness Desktop 的 Windows 电脑，执行一条命令后得到
「git + npm + gh + dshmarket + dsh-cost-meter + 本技能」，并能在 UI 里看到结果。

## 0. 先确认环境

```powershell
[Environment]::OSVersion.Version      # 需要 Windows 10/11
Test-Path "$env:USERPROFILE\.dsh"     # DSH 至少要启动过一次
Get-Process | Where-Object ProcessName -like '*DeepSeek*'  # 装插件期间应为空
```

DSH 关键路径（Desktop 版）：

| 用途 | 路径 |
|---|---|
| 配置根 | `%USERPROFILE%\.dsh` |
| profile | `%USERPROFILE%\.dsh\profiles\desktop` |
| CLI | `%ProgramFiles(x86)%\DSH\resources\runtime\cli\bin\dsh.cmd`（安装目录可能不同，见下方定位） |
| 用户技能根 | `%USERPROFILE%\.dsh\skills\<技能名>\SKILL.md` |

用户技能根是 DSH 内置 `@deepseek-ai/dsh-skill-filesystem` 的 `user-dsh` 扫描目录，
并且**带文件监听**：放进新技能不需要重启 DSH，下一次对话就会出现在技能目录里。

## 1. 一键路径（推荐）

把整个包拷到目标机，右键 PowerShell 运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Tools -Plugins
```

它会做三件事：

1. 把 `skill\dsh-machine-bootstrap` 复制到 `%USERPROFILE%\.dsh\skills\`；
2. `-Tools` 时把 git / Node+npm / gh 便携安装到 `%LOCALAPPDATA%\dsh-tools` 并写入用户 PATH；
3. `-Plugins` 时（要求 DSH 已完全退出）自动定位 `dsh.cmd` 并执行
   `dsh plugin --profile desktop add dshmarket dsh-cost-meter`，最后打印验证结果。

之后重新打开 DSH，在「设置 → 插件」里应能看到两个插件，技能列表里应出现
`dsh-machine-bootstrap`。

## 2. 手动分步（脚本不可用时逐条执行）

### 2.1 定位 DSH CLI

```powershell
$candidates = @(
  "$env:ProgramFiles\DSH\resources\runtime\cli\bin\dsh.cmd",
  "${env:ProgramFiles(x86)}\DSH\resources\runtime\cli\bin\dsh.cmd",
  "$env:LOCALAPPDATA\Programs\DSH\resources\runtime\cli\bin\dsh.cmd"
)
$dsh = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $dsh) { $dsh = (Get-ChildItem "$env:LOCALAPPDATA\Programs" -Filter dsh.cmd -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1).FullName }
$dsh
```

### 2.2 装 git

优先 winget（需要网络与可能的 UAC）：

```powershell
winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
```

winget 不可用 / 无管理员权限时用便携版 MinGit（解压即用，不需要管理员）：

```powershell
# 用 Node 下载（见 2.5：schannel 坏掉时 Invoke-WebRequest 会失败）
$rel = Invoke-RestMethod https://api.github.com/repos/git-for-windows/git/releases/latest
$asset = $rel.assets | Where-Object name -like 'MinGit-*-64-bit.zip' | Select-Object -First 1
Invoke-WebRequest $asset.browser_download_url -OutFile "$env:TEMP\mingit.zip"
Expand-Archive "$env:TEMP\mingit.zip" "$env:LOCALAPPDATA\dsh-tools\git" -Force
# 把 $env:LOCALAPPDATA\dsh-tools\git\cmd 加进用户 PATH 后重开终端
```

### 2.3 装 Node.js 与 npm

DSH Desktop 自带 Node 24 与 pnpm，但**不自带 npm**，也不在 PATH 上：

```powershell
# 方案 A：winget
winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements

# 方案 B：直接复用 DSH 自带的 Node（零安装，够 npm 发布用）
$node = (Get-ChildItem "$env:USERPROFILE\.dsh\dsh-runtimes" -Filter node.exe -Recurse |
         Where-Object FullName -like '*\bin\node.exe' | Select-Object -First 1).FullName
& $node --version
# npm 包体从 registry 拉取后解压，用 node 直接跑 npm-cli.js
```

### 2.4 装 GitHub CLI

```powershell
winget install --id GitHub.cli -e --accept-package-agreements --accept-source-agreements
# 或便携版：解压 gh_*_windows_amd64.zip 到 %LOCALAPPDATA%\dsh-tools\gh
```

装完 `gh auth status` 应为已登录；未登录时 `gh auth login`（会开浏览器）——**这一步必须由用户本人完成**，不要代替用户登录。

### 2.5 装 DSH 插件（核心步骤）

**先完全退出 DSH（含托盘常驻）**，否则 profile 目录被占用、pnpm 改动不安全：

```powershell
Get-Process | Where-Object ProcessName -like '*DeepSeek*' | Stop-Process
& $dsh plugin --profile desktop add dshmarket dsh-cost-meter
```

`dsh plugin add` 等价于在 profile 目录里跑 pnpm，并**自动**把带 `dsh.bundle.patch` 的包
写进 `profiles\desktop\package.json` 的 `dsh.profile.bundles`，不需要手动编辑。

验证：

```powershell
Get-Content "$env:USERPROFILE\.dsh\profiles\desktop\package.json" -Raw |
  ConvertFrom-Json | ForEach-Object { $_.dsh.profile.bundles; $_.dependencies }
```

应看到 `dshmarket`、`dsh-cost-meter` 同时出现在 `bundles` 与 `dependencies` 里。

### 2.6 装本技能

```powershell
$root = "$env:USERPROFILE\.dsh\skills"
New-Item -ItemType Directory -Force -Path $root | Out-Null
Copy-Item .\skill\dsh-machine-bootstrap $root -Recurse -Force
```

DSH 正在运行也可以，watcher 会自动刷新；否则下次启动生效。

## 3. 验证清单

- [ ] `git --version`、`node --version`、`npm --version`、`gh --version` 都能输出
- [ ] `%USERPROFILE%\.dsh\profiles\desktop\package.json` 的 `bundles` 含两个插件
- [ ] `%USERPROFILE%\.dsh\skills\dsh-machine-bootstrap\SKILL.md` 存在
- [ ] 打开 DSH：设置 → 插件 能看到 dshmarket / dsh-cost-meter，且无兼容性警告
- [ ] 新会话里模型能列出 `dsh-machine-bootstrap` 技能

## 4. 回滚

```powershell
& $dsh plugin --profile desktop remove dsh-cost-meter dshmarket
Remove-Item "$env:USERPROFILE\.dsh\skills\dsh-machine-bootstrap" -Recurse -Force
```

## 5. 已知坑（源机器实测）

- **TLS 被 schannel 挡住**：本机 `Invoke-WebRequest` / `curl.exe` 访问 https 报
  `SEC_E_NO_CREDENTIALS`，但 `node -e "fetch(...)"` 正常。下载一律走 Node 的 fetch，
  不要依赖 PowerShell 的 `Invoke-WebRequest`。
- **`dsh plugin` 写 profile 会加锁**：DSH 开着时可能报
  `EPERM ... package.json.lock`，先退出 DSH。
- **git 托管的插件**会触发 pnpm 的 `prepare` 构建拦截，需要把 pnpm 打印的 key 写进
  `profiles\desktop\pnpm-workspace.yaml` 的 `allowBuilds` 再重跑。
- **技能发现只有一层**：只认 `<root>\<name>\SKILL.md` 和 `<root>\<name>.md`，
  嵌套目录里的 `SKILL.md` 不会被发现。
- **`npm` 被解析成 `npm.ps1` 时会被执行策略拦**：`Get-Command npm` 指向 `npm.ps1`
  会报「禁止运行脚本」。删掉 `%LOCALAPPDATA%\dsh-tools\node\npm.ps1`（和 `npx.ps1`），
  让 PowerShell 回落到 `npm.cmd`；或直接 `npm.cmd --version`。
- **写用户 PATH 时 `[Environment]::SetEnvironmentVariable` 在本机会把 `;` 吃掉**，
  导致多个路径粘成一条。改用
  `Set-ItemProperty HKCU:\Environment -Name Path -Value (...) -Type ExpandString`。
  改完必须新开终端才生效。
