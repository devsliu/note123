# 发布脚本: 推送 tag -> 等待 CI 构建 -> 下载产物到 $ServerVersionDir\{version}\ -> 生成 version.json/changelog.txt/version.ini
# 用法: powershell -ExecutionPolicy Bypass -File pack\publish_release.ps1 -Version 1.0.10
param(
    [Parameter(Mandatory=$true)]
    [string]$Version,            # e.g. 1.0.5 (no 'v'), tag will be v$Version
    [string]$ServerVersionDir = 'Y:\note123\version'
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$tag = "v$Version"

Set-Location $ProjectRoot

# 1. 推送 tag 触发 CI
git tag -a $tag -m "Release $tag"
git push origin $tag
if ($LASTEXITCODE -ne 0) { throw "push tag failed" }

# 2. 等待 CI run 出现并构建完成
$runId = $null
for ($i = 0; $i -lt 30; $i++) {
    $runs = gh run list --branch $tag --limit 1 --json databaseId | ConvertFrom-Json
    if ($runs.Count -gt 0) { $runId = $runs[0].databaseId; break }
    Start-Sleep -Seconds 5
}
if (-not $runId) { throw "CI run for $tag not found" }
Write-Host "Watching CI run $runId ..."
gh run watch $runId --exit-status --interval 60
if ($LASTEXITCODE -ne 0) { throw "CI build failed, see: gh run view $runId" }

# 3. 下载 Release 产物到服务端 version 目录下的版本子目录
$artDir = Join-Path $ServerVersionDir $Version
if (-not (Test-Path $artDir)) { New-Item -ItemType Directory -Path $artDir | Out-Null }
gh release download $tag --dir $artDir --clobber
if ($LASTEXITCODE -ne 0) { throw "release download failed" }

# 4. 生成版本元数据 (version.json / changelog.txt / version.ini)

chcp 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Map platform → filename (docker 不进 version.json)
$map = @{
    'windows' = "note123-client-windows-x64-v$Version.zip"
    'android' = "note123-android-arm64-v8a-v$Version.apk"
    'macos'   = "note123-client-macos-silicon-v$Version.zip"
    'linux'   = (Get-ChildItem "$artDir\note123-client-linux-x64-v*.tar.gz" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Name)
}

# Changelog: 直接从 GitHub Release 的 body 获取
try {
    $changelog = (gh release view $tag --json body --jq '.body' 2>$null)
    if (-not $changelog) { $changelog = '' }
} catch { $changelog = '' }
if (-not $changelog) { $changelog = 'init release' }

$updatedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')

# version.json (只含 updatedAt + 各平台 md5/file)
$data = [PSCustomObject]@{ updatedAt = $updatedAt }

foreach ($plat in $map.Keys) {
    $fname = $map[$plat]
    if (-not $fname) { continue }
    $fpath = Join-Path $artDir $fname
    if (-not (Test-Path $fpath)) { continue }

    $md5 = (Get-FileHash $fpath -Algorithm MD5).Hash.ToUpper()
    $entry = [PSCustomObject]@{ md5 = $md5; file = $fname }
    Add-Member -InputObject $data -NotePropertyName $plat -NotePropertyValue $entry -Force
    Write-Host "  [$plat] $Version md5=$md5"
}

# 生成格式化 JSON 并还原 unicode 转义
$json = $data | ConvertTo-Json -Depth 10
$matches = [regex]::Matches($json, '\\u([0-9a-fA-F]{4})')
for ($i = $matches.Count - 1; $i -ge 0; $i--) {
    $m = $matches[$i]
    $code = [Convert]::ToInt32($m.Groups[1].Value, 16)
    $char = [char]$code
    $json = $json.Substring(0, $m.Index) + $char + $json.Substring($m.Index + $m.Length)
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$jsonPath = Join-Path $artDir 'version.json'
[IO.File]::WriteAllText($jsonPath, $json, $utf8NoBom)
Write-Host "version.json saved: $jsonPath"

$changelogPath = Join-Path $artDir 'changelog.txt'
[IO.File]::WriteAllText($changelogPath, $changelog, $utf8NoBom)
Write-Host "changelog.txt saved: $changelogPath"

# 根目录 versions.json 已废弃, 删除
$oldJson = Join-Path $ServerVersionDir 'versions.json'
if (Test-Path $oldJson) { Remove-Item $oldJson -Force }

# 根目录 version.ini (最新版本名)
$iniPath = Join-Path $ServerVersionDir 'version.ini'
[IO.File]::WriteAllText($iniPath, "latest=$Version`n", $utf8NoBom)
Write-Host "version.ini saved: $iniPath (latest=$Version)"

Write-Host "Publish $tag done -> $ServerVersionDir"
