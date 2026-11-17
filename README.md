# DSH 新机一键部署

把一台新 Windows 电脑的 DSH 环境一次装好：**git / Node+npm / GitHub CLI** +
**dshmarket / dsh-cost-meter 插件** + 一个可复用的技能（技能热装，不用重启）。

## 快速开始

```powershell
# 下载 zip 解压后，在解压目录执行
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Tools -Plugins
```

装插件那一步要求 DSH 完全退出（脚本会检测并拒绝往下走）；只装技能可以热装。

## 包里有什么

| 路径 | 作用 |
|---|---|
| `install.ps1` | 一键安装：技能 → 工具 → 插件 → 验证 |
| `dsh-machine-bootstrap/SKILL.md` | 技能本体，给 AI 看的完整步骤 |
| `dsh-machine-bootstrap/references/` | 版本快照、源机器踩坑记录 |
| `dsh-machine-bootstrap/scripts/` | 分步脚本：install-tools / install-plugins / verify |
| `dist/dsh-machine-bootstrap-skill.zip` | 打包好的分发件 |

## 原理

- DSH 的 `dsh-skill-filesystem` 扫描 `%USERPROFILE%\.dsh\skills\<名字>\SKILL.md`，并监听目录，**新技能无需重启**。
- 插件用官方 CLI：`dsh plugin --profile desktop add <包>`，pnpm 安装后自动登记到 `profiles\desktop\package.json` 的 `dsh.profile.bundles`。
- 全程不需要管理员权限，工具装在 `%LOCALAPPDATA%\dsh-tools`。

## 注意

- 目标机必须先装好 DeepSeek Harness Desktop，并至少启动过一次。
- `gh auth login` 必须由用户本人完成，脚本不会代登录。
