<#
.SYNOPSIS
    从本地 .env 读取密钥，通过 --dart-define 注入后构建。

.DESCRIPTION
    密钥保存在 .env（已被 .gitignore 忽略），不进入版本库。
    本脚本只打印被注入的变量「名字」，绝不打印值。

    注意：dart-define 的值会被编译进产物，可被逆向提取。
    不要把「必须保密的共享账号」放进来。

.EXAMPLE
    pwsh scripts/build_local.ps1 -Target apk
    pwsh scripts/build_local.ps1 -Target ios
#>
param(
    [ValidateSet('apk', 'appbundle', 'ios')]
    [string]$Target = 'apk',

    [string]$EnvFile = (Join-Path $PSScriptRoot '..\.env')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $EnvFile)) {
    Write-Host "未找到 $EnvFile" -ForegroundColor Red
    Write-Host "请先复制模板并填入真实值：" -ForegroundColor Yellow
    Write-Host "    Copy-Item .env.example .env" -ForegroundColor Yellow
    exit 1
}

$defines = @('--dart-define=FLUTTER_APP_ENV=release')
$injected = @()

foreach ($line in Get-Content -LiteralPath $EnvFile) {
    $text = $line.Trim()
    if ($text -eq '' -or $text.StartsWith('#')) { continue }

    $eq = $text.IndexOf('=')
    if ($eq -lt 1) { continue }

    $key = $text.Substring(0, $eq).Trim()
    $value = $text.Substring($eq + 1).Trim()

    # 值为空视为「不使用」，不注入（保持代码内 defaultValue 生效）
    if ($value -eq '') { continue }

    $defines += "--dart-define=$key=$value"
    $injected += $key
}

if ($injected.Count -eq 0) {
    Write-Host "警告：.env 中没有任何有效值，将按无密钥方式构建。" -ForegroundColor Yellow
} else {
    Write-Host "已注入 $($injected.Count) 个密钥：$($injected -join ', ')" -ForegroundColor Cyan
}

switch ($Target) {
    'apk'       { & flutter build apk --release @defines }
    'appbundle' { & flutter build appbundle --release @defines }
    'ios'       { & flutter build ios --release --no-codesign @defines }
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "构建失败，退出码 $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "构建完成：$Target" -ForegroundColor Green
