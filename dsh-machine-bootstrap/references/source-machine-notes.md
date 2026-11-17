# 源机器操作记录（2026-11-17）

本文件记录把「装 git / npm / gh + 装 DSH 插件」这件事在源机器上真实走通的顺序，
供另一台电脑复现时对照。

## 环境

- Windows，DSH Desktop `0.2.2-rc.1`
- `%DSH_HOME%` = `C:\Users\<user>\.dsh`
- profile = `desktop`
- DSH 安装目录 `D:\Program Files (x86)\DSH`
- CLI：`D:\Program Files (x86)\DSH\resources\runtime\cli\bin\dsh.cmd`

## 实际顺序

1. **发现网络限制**：`Invoke-WebRequest`、`curl.exe` 访问 https 全部报
   `SEC_E_NO_CREDENTIALS`（schannel 取不到凭据），但 `node -e "fetch(...)"` 正常。
   → 所有下载改用 Node 的 `fetch`。
2. **winget 不可用**：`winget --version` 退出码 `-1978335231`，无任何输出。
   → 放弃 winget，全部走便携版。
3. **Git**：`MinGit-2.56.1-64-bit.zip`（38 MB），
   来自 `registry.npmmirror.com/-/binary/git-for-windows/`，解压后 `cmd\git.exe` 可用。
4. **Node/npm**：`node-v24.21.0-win-x64.zip`（36 MB），
   来自 `registry.npmmirror.com/-/binary/node/`，自带 npm 11.19.0。
   （DSH 自带的 Node 在 `%USERPROFILE%\.dsh\dsh-runtimes\...\node.exe`，但不带 npm。）
5. **gh**：`gh_2.104.0_windows_amd64.zip`（15 MB）。
   GitHub 直连超时，走 `https://ghfast.top/<原始 github 地址>` 成功；
   `gh-proxy.com` 同样可用，`ghproxy.net` 超时。
6. **插件**：`dsh plugin --profile desktop add dshmarket dsh-cost-meter`。
   该命令是 pnpm 的包装，成功后自动把两个包写进
   `profiles\desktop\package.json` 的 `dsh.profile.bundles`。
   执行前必须退出 DSH，否则报 `EPERM ... package.json.lock`。
7. **技能**：复制到 `%USERPROFILE%\.dsh\skills\dsh-machine-bootstrap\`，
   DSH 的文件监听会立刻刷新技能目录，不需要重启。

## 结论

- 目标机如果同样处于受限网络，**优先用 npmmirror 与 ghfast.top 镜像**，不要死磕 GitHub 直连。
- 只有插件安装需要 DSH 退出；技能安装可以热装。
- 全程不需要管理员权限，装到 `%LOCALAPPDATA%\dsh-tools\` 并加入用户 PATH 即可。
