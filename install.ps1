#Requires -Version 5.1
<#
.SYNOPSIS
  在新电脑上一键安装 DSH 技能与插件。

.DESCRIPTION
  1. 把 skill\dsh-machine-bootstrap 复制到 %USERPROFILE%\.dsh\skills\
  2. 可选：便携安装 git / Node+npm / GitHub CLI 到 %LOCALAPPDATA%\dsh-tools
  3. 可选：调用 DSH CLI 安装 dshmarket 与 dsh-cost-meter 插件（需要 DSH 已退出）
  4. 输出验证结果

.PARAMETER Tools
  同时安装 git / Node+npm / gh（不需要管理员权限）。

.PARAMETER Plugins
  同时安装 DSH 插件。执行前必须完全退出 DeepSeek Harness。

.PARAMETER Profile
  DSH profile 名称，默认 desktop。

.PARAMETER DshCli
  手动指定 dsh.cmd 路径（自动定位失败时用）。

.PARAMETER DryRun
  只打印将要执行的动作，不落盘。

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Plugins
#>
[CmdletBinding()]
param(
    [switch]$Plugins,
    [switch]$Tools,
    [string]$Profile = 'desktop',
    [string]$DshCli,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$SkillName = 'dsh-machine-bootstrap'
$SkillRoot = Join-Path $env:USERPROFILE '.dsh\skills'
$Source    = Join-Path (Split-Path $PSScriptRoot) $SkillName
if (-not (Test-Path (Join-Path $Source 'SKILL.md'))) { $Source = Join-Path $PSScriptRoot "skill\$SkillName" }
if (-not (Test-Path (Join-Path $Source 'SKILL.md'))) { $Source = Join-Path $PSScriptRoot $SkillName }

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    OK  $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "    !!  $msg" -ForegroundColor Yellow }

function Find-DshCli {
    param([string]$Explicit)
    if ($Explicit -and (Test-Path $Explicit)) { return $Explicit }
    if ($env:DSH_CLI -and (Test-Path $env:DSH_CLI)) { return $env:DSH_CLI }

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
               Where-Object FullName -like '*\runtime\cli\bin\dsh.cmd' |
               Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

function Test-DshRunning {
    return @(Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -like '*DeepSeek*' -or $_.ProcessName -eq 'dsh' }).Count -gt 0
}

Write-Host ''
Write-Host "DSH 技能一键安装 - $SkillName" -ForegroundColor White
Write-Host ''

# --- 1. 预检 -------------------------------------------------------------
Write-Step '检查环境'
if (-not (Test-Path (Join-Path $env:USERPROFILE '.dsh'))) {
    Write-Warn2 '未找到 %USERPROFILE%\.dsh —— 请先启动一次 DeepSeek Harness Desktop'
}
if (-not (Test-Path $Source)) {
    throw "包不完整：找不到 $Source（请解压整个 zip 后再运行）"
}
Write-Ok "源技能目录 $Source"

# --- 2. 安装技能 ---------------------------------------------------------
Write-Step "安装技能到 $SkillRoot\$SkillName"
if ($DryRun) {
    Write-Warn2 'DryRun：跳过写入'
} else {
    New-Item -ItemType Directory -Force -Path $SkillRoot | Out-Null
    $dest = Join-Path $SkillRoot $SkillName
    $existing = Get-Item $dest -Force -ErrorAction SilentlyContinue
    if ($existing -and $existing.LinkType) {
        Write-Ok "已是指向 $($existing.Target) 的链接，跳过复制"
    } else {
        if ($existing) {
            Write-Warn2 '已存在，覆盖更新'
            Remove-Item $dest -Recurse -Force
        }
        Copy-Item $Source $dest -Recurse -Force
    }
    if (Test-Path (Join-Path $dest 'SKILL.md')) { Write-Ok 'SKILL.md 已就位' }
    else { throw '复制后缺少 SKILL.md，安装失败' }
}

# --- 3. 安装工具链 -------------------------------------------------------
if ($Tools) {
    Write-Step '安装 git / Node+npm / GitHub CLI（便携版）'
    $toolScript = Join-Path $Source 'scripts\install-tools.ps1'
    if (-not (Test-Path $toolScript)) { throw "包不完整：缺少 $toolScript" }
    if ($DryRun) { Write-Warn2 "DryRun：& `"$toolScript`"" }
    else { & $toolScript }
}

# --- 4. 安装插件 ---------------------------------------------------------
if ($Plugins) {
    Write-Step '安装 DSH 插件 dshmarket / dsh-cost-meter'
    if (Test-DshRunning) {
        throw '检测到 DeepSeek Harness 正在运行。请完全退出（含托盘图标）后重新运行，或去掉 -Plugins 只装技能。'
    }
    $dsh = Find-DshCli -Explicit $DshCli
    if (-not $dsh) {
        throw '找不到 dsh.cmd。请用 -DshCli "<DSH安装目录>\resources\runtime\cli\bin\dsh.cmd" 指定。'
    }
    Write-Ok "DSH CLI: $dsh"
    if ($DryRun) {
        Write-Warn2 "DryRun：& `"$dsh`" plugin --profile $Profile add dshmarket dsh-cost-meter"
    } else {
        & $dsh plugin --profile $Profile add dshmarket dsh-cost-meter
        if ($LASTEXITCODE -ne 0) { throw "dsh plugin add 失败，退出码 $LASTEXITCODE" }
        Write-Ok '插件安装命令执行完成'
    }
}

# --- 5. 验证 -------------------------------------------------------------
Write-Step '验证'
$manifest = Join-Path $env:USERPROFILE ".dsh\profiles\$Profile\package.json"
if (Test-Path $manifest) {
    $pkg = Get-Content $manifest -Raw | ConvertFrom-Json
    $bundles = @($pkg.dsh.profile.bundles)
    Write-Host ("    bundles: " + ($bundles -join ', '))
    foreach ($p in @('dshmarket', 'dsh-cost-meter')) {
        if ($bundles -contains $p) { Write-Ok "$p 已登记" } else { Write-Warn2 "$p 未登记（未装插件时正常）" }
    }
} else {
    Write-Warn2 "未找到 profile 清单 $manifest"
}

$skillFile = Join-Path $SkillRoot "$SkillName\SKILL.md"
if (Test-Path $skillFile) { Write-Ok "技能文件 $skillFile" } else { Write-Warn2 "技能文件缺失 $skillFile" }

Write-Host ''
Write-Host '完成。重新启动 DSH 后：' -ForegroundColor White
Write-Host '  1) 设置 -> 插件，应看到 dshmarket 与 dsh-cost-meter'
Write-Host '  2) 新会话里技能列表应出现 dsh-machine-bootstrap'
Write-Host ''
