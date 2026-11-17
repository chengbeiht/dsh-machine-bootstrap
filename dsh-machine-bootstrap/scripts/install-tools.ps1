#Requires -Version 5.1
<#
.SYNOPSIS
  便携安装 git / Node+npm / GitHub CLI 到 %LOCALAPPDATA%\dsh-tools，并写入用户 PATH。
.DESCRIPTION
  不写系统目录、不需要管理员权限。所有下载走国内可达的镜像。
  已存在的目录默认跳过，-Force 覆盖重装。
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\install-tools.ps1
#>
[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Stop'
$tools = Join-Path $env:LOCALAPPDATA 'dsh-tools'
New-Item -ItemType Directory -Force -Path $tools | Out-Null

$downloads = @(
    @{ Name = 'node'; Url = 'https://registry.npmmirror.com/-/binary/node/v24.21.0/node-v24.21.0-win-x64.zip'; Inner = 'node-v24.21.0-win-x64'; Probe = 'node.exe' },
    @{ Name = 'git';  Url = 'https://registry.npmmirror.com/-/binary/git-for-windows/v2.56.1.windows.1/MinGit-2.56.1-64-bit.zip'; Inner = '.'; Probe = 'cmd\git.exe' },
    @{ Name = 'gh';   Url = 'https://ghfast.top/https://github.com/cli/cli/releases/download/v2.104.0/gh_2.104.0_windows_amd64.zip'; Inner = 'bin'; Probe = 'gh.exe' }
)

foreach ($d in $downloads) {
    $dest = Join-Path $tools $d.Name
    if ((Test-Path (Join-Path $dest $d.Probe)) -and -not $Force) {
        Write-Host "skip $($d.Name) (already installed)" -ForegroundColor DarkGray
        continue
    }
    Write-Host "downloading $($d.Name) ..." -ForegroundColor Cyan
    $zip = Join-Path $env:TEMP ("dsh-tools-" + $d.Name + ".zip")
    $tmp = Join-Path $env:TEMP ("dsh-tools-" + $d.Name)
    if (Test-Path $zip) { Remove-Item $zip -Force }
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $d.Url -OutFile $zip -UseBasicParsing
    Expand-Archive $zip $tmp -Force
    $src = Join-Path $tmp $d.Inner
    if (-not (Test-Path $src)) { $src = $tmp }
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item (Join-Path $src '*') $dest -Recurse -Force
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "installed $dest" -ForegroundColor Green
}

# 用户 PATH：直接写注册表，避免 SetEnvironmentVariable 丢掉分隔符
$entries = @(
    (Join-Path $tools 'node'),
    (Join-Path $tools 'git\cmd'),
    (Join-Path $tools 'gh')
)
$key = 'HKCU:\Environment'
$current = (Get-ItemProperty -Path $key -Name Path -ErrorAction SilentlyContinue).Path
if (-not $current) { $current = '' }
$parts = @($current -split ';' | Where-Object { $_ -ne '' })
$added = @()
foreach ($e in $entries) { if ($parts -notcontains $e) { $parts += $e; $added += $e } }
if ($added.Count -gt 0) {
    Set-ItemProperty -Path $key -Name Path -Value ($parts -join ';') -Type ExpandString
    Write-Host ("PATH updated: " + ($added -join '; ')) -ForegroundColor Green
    Write-Host '新开终端后生效（当前窗口不会自动刷新）。' -ForegroundColor Yellow
}

# npm.ps1 会被 PowerShell 执行策略拦截，删掉让 npm.cmd 生效
foreach ($shim in @('npm.ps1', 'npx.ps1')) {
    $p = Join-Path $tools "node\$shim"
    if (Test-Path $p) { Remove-Item $p -Force; Write-Host "removed $shim (execution policy)" -ForegroundColor DarkGray }
}

Write-Host ''
Write-Host '验证（新终端）：' -ForegroundColor White
Write-Host '  git --version; node --version; npm --version; gh --version'
Write-Host 'GitHub CLI 还需你本人执行: gh auth login'
