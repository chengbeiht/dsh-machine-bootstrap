#Requires -Version 5.1
<#
.SYNOPSIS
  只安装 DSH 插件（dshmarket、dsh-cost-meter），不碰技能目录。
.DESCRIPTION
  要求 DeepSeek Harness 已完全退出。自动定位 dsh.cmd。
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\install-plugins.ps1
#>
[CmdletBinding()]
param(
    [string]$Profile = 'desktop',
    [string[]]$Packages = @('dshmarket', 'dsh-cost-meter'),
    [string]$DshCli
)

$ErrorActionPreference = 'Stop'

function Find-DshCli {
    param([string]$Explicit)
    if ($Explicit -and (Test-Path $Explicit)) { return $Explicit }
    $candidates = @(
        (Join-Path $env:ProgramFiles 'DSH\resources\runtime\cli\bin\dsh.cmd'),
        (Join-Path ${env:ProgramFiles(x86)} 'DSH\resources\runtime\cli\bin\dsh.cmd'),
        (Join-Path $env:LOCALAPPDATA 'Programs\DSH\resources\runtime\cli\bin\dsh.cmd')
    )
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
    $cmd = Get-Command dsh -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($base in @((Join-Path $env:LOCALAPPDATA 'Programs'), $env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if (-not $base -or -not (Test-Path $base)) { continue }
        $hit = Get-ChildItem $base -Filter dsh.cmd -Recurse -ErrorAction SilentlyContinue |
               Where-Object FullName -like '*\runtime\cli\bin\dsh.cmd' | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

$running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like '*DeepSeek*' })
if ($running.Count -gt 0) {
    throw "DeepSeek Harness 正在运行（$($running[0].ProcessName)）。请完全退出（含托盘）后重试。"
}

$dsh = Find-DshCli -Explicit $DshCli
if (-not $dsh) { throw '找不到 dsh.cmd，请用 -DshCli 指定完整路径。' }

Write-Host "使用 CLI: $dsh" -ForegroundColor Cyan
Write-Host "安装: $($Packages -join ' ')" -ForegroundColor Cyan
& $dsh plugin --profile $Profile add @Packages
if ($LASTEXITCODE -ne 0) { throw "安装失败，退出码 $LASTEXITCODE" }
Write-Host '完成。重新启动 DSH 后到 设置 -> 插件 查看。' -ForegroundColor Green
