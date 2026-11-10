# POC Skills 一键安装脚本（Windows PowerShell，跨平台：TRAE / OpenCode / Claude / Agents / DSH）
param(
  [string]$Platform = "all",
  [switch]$Symlink
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SrcDir = Join-Path $ScriptDir "skills"

# ---- 各平台 skills 目录（全局）。可用同名环境变量覆盖 ----
$TRAE_DIR    = if ($env:TRAE_DIR)    { $env:TRAE_DIR }    else { Join-Path $env:USERPROFILE ".trae-cn\skills" }
$OPENCODE_DIR = if ($env:OPENCODE_DIR) { $env:OPENCODE_DIR } else { Join-Path $env:USERPROFILE ".config\opencode\skills" }
$CLAUDE_DIR  = if ($env:CLAUDE_DIR)  { $env:CLAUDE_DIR }  else { Join-Path $env:USERPROFILE ".claude\skills" }
$AGENTS_DIR  = if ($env:AGENTS_DIR)  { $env:AGENTS_DIR }  else { Join-Path $env:USERPROFILE ".agents\skills" }
$DSH_DIR     = ""
if ($env:DSH_HOME) { $DSH_DIR = Join-Path $env:DSH_HOME "skills" }

function Write-Usage {
  @"
用法: .\install.ps1 [-Platform <名称>] [-Symlink]

把本仓库的 skills 安装到指定平台的 skills 目录（默认 all = 全部可用平台）。

平台: trae, opencode, claude, agents, dsh, all

选项:
  -Platform <name>  只安装指定平台（可用逗号分隔多个，如 trae,opencode）
  -Symlink          用目录符号链接代替复制（更新仓库后自动生效，需管理员权限）

各平台目标目录（同名环境变量可覆盖）:
  trae     -> $TRAE_DIR
  opencode -> $OPENCODE_DIR
  claude   -> $CLAUDE_DIR
  agents   -> $AGENTS_DIR     (.agents 通用规范，OpenCode / Claude 均兼容)
  dsh      -> $DSH_DIR        (需设置 DSH_HOME 环境变量，否则跳过)
"@
}

if (-not (Test-Path $SrcDir)) {
  Write-Error "找不到 skills 目录: $SrcDir"
  exit 1
}

# ---- 本地数据文件保护：更新时不覆盖这些路径，保留用户本地改动 ----
# 相对 skills/<skill>/ 的路径；PreserveDirs 整目录跳过，PreserveFiles 单文件跳过。
$PreserveDirs  = @("poc-capability\deployments", "poc-case\cases")
$PreserveFiles = @("poc-capability\capabilities.yaml")

function Test-Preserve {
  param([string]$Rel)
  foreach ($d in $PreserveDirs) {
    if ($Rel -eq $d -or $Rel.StartsWith($d + "\")) { return $true }
  }
  foreach ($f in $PreserveFiles) {
    if ($Rel -eq $f) { return $true }
  }
  return $false
}

function Copy-SkillIncremental {
  param([string]$Src, [string]$Dst)
  New-Item -ItemType Directory -Force -Path $Dst | Out-Null
  Get-ChildItem $Src -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($Src.Length).TrimStart('\', '/')
    $dstFile = Join-Path $Dst $rel
    if ((Test-Preserve $rel) -and (Test-Path $dstFile)) {
      Write-Host "  保留本地文件: $rel"
      return
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $dstFile -Parent) | Out-Null
    Copy-Item $_.FullName $dstFile -Force
  }
}

function Install-To {
  param([string]$Dest, [string]$Name)
  if ([string]::IsNullOrEmpty($Dest)) {
    Write-Host "跳过 [$Name]：目标目录未配置"
    return
  }
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
  $count = 0
  Get-ChildItem $SrcDir -Directory | ForEach-Object {
    $skillName = $_.Name
    $target = Join-Path $Dest $skillName
    if ($Symlink) {
      if (Test-Path $target) { Remove-Item $target -Recurse -Force }
      New-Item -ItemType SymbolicLink -Path $target -Target $_.FullName | Out-Null
    } elseif (Test-Path $target) {
      # 更新：逐文件覆盖，命中「不覆盖清单」的本地文件保留
      Copy-SkillIncremental $_.FullName $target
    } else {
      # 首次安装：整目录复制（含清单模板，供首次填写）
      Copy-Item -Path $_.FullName -Destination $target -Recurse -Force
    }
    $count++
  }
  Write-Host "已安装 [$Name] $count 个 skill -> $Dest"
}

function Install-Platform {
  param([string]$P)
  switch ($P) {
    "trae"    { Install-To $TRAE_DIR "trae" }
    "opencode" { Install-To $OPENCODE_DIR "opencode" }
    "claude"  { Install-To $CLAUDE_DIR "claude" }
    "agents"  { Install-To $AGENTS_DIR "agents" }
    "dsh"     { Install-To $DSH_DIR "dsh" }
    default   { Write-Error "未知平台: $P"; exit 1 }
  }
}

if ($Platform -eq "all") {
  foreach ($p in @("trae","opencode","claude","agents","dsh")) { Install-Platform $p }
} else {
  foreach ($p in ($Platform -split ",")) { Install-Platform $p.Trim() }
}

Write-Host ""
Write-Host "完成。卸载只需删除上述目标目录中对应的 poc-* 目录。"