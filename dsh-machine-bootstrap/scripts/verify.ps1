#Requires -Version 5.1
<#
.SYNOPSIS
  自检：技能目录、profile 插件登记、工具链版本。
#>
[CmdletBinding()]
param([string]$Profile = 'desktop')

$ok = 0; $bad = 0
function Check($name, $cond, $detail) {
    if ($cond) { Write-Host ("[ OK ] {0} {1}" -f $name, $detail) -ForegroundColor Green; $script:ok++ }
    else       { Write-Host ("[FAIL] {0} {1}" -f $name, $detail) -ForegroundColor Red;   $script:bad++ }
}

$skill = Join-Path $env:USERPROFILE '.dsh\skills\dsh-machine-bootstrap\SKILL.md'
Check '技能文件' (Test-Path $skill) $skill

$manifestPath = Join-Path $env:USERPROFILE ".dsh\profiles\$Profile\package.json"
$bundles = @()
if (Test-Path $manifestPath) {
    $pkg = Get-Content $manifestPath -Raw | ConvertFrom-Json
    $bundles = @($pkg.dsh.profile.bundles)
}
Check 'profile 清单' (Test-Path $manifestPath) $manifestPath
foreach ($p in @('dshmarket', 'dsh-cost-meter')) {
    Check "插件 $p" ($bundles -contains $p) ($bundles -join ', ')
}

$toolProbes = @{
    git  = @((Join-Path $env:LOCALAPPDATA 'dsh-tools\git\cmd\git.exe'))
    node = @((Join-Path $env:LOCALAPPDATA 'dsh-tools\node\node.exe'))
    npm  = @((Join-Path $env:LOCALAPPDATA 'dsh-tools\node\npm.cmd'))
    gh   = @((Join-Path $env:LOCALAPPDATA 'dsh-tools\gh\gh.exe'))
}
foreach ($t in @('git', 'node', 'npm', 'gh')) {
    $c = Get-Command $t -ErrorAction SilentlyContinue
    $detail = if ($c) { $c.Source } else { '' }
    $found = $null -ne $c
    if (-not $found) {
        foreach ($p in $toolProbes[$t]) {
            if (Test-Path $p) { $found = $true; $detail = "$p (未在当前 PATH，新开终端后生效)"; break }
        }
    }
    if (-not $found) { $detail = '未安装' }
    Check "工具 $t" $found $detail
}

$proc = @(Get-Process -ErrorAction SilentlyContinue | Where-Object ProcessName -like '*DeepSeek*')
if ($proc.Count -gt 0) {
    Write-Host "[INFO] DSH 正在运行，插件要重启后才会加载" -ForegroundColor Yellow
} else {
    Write-Host "[INFO] DSH 未运行，下次启动加载插件" -ForegroundColor DarkGray
}

Write-Host ''
Write-Host "通过 $ok 项，失败 $bad 项" -ForegroundColor White
if ($bad -gt 0) { exit 1 }
