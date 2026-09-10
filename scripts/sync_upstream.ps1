param(
    [switch]$CheckOnly,
    [switch]$Merge,
    [string]$UpstreamRemote = "upstream",
    [string]$UpstreamUrl = "https://github.com/singleton-altman/MoviePilotLite.git"
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "   OmniHub 上游代码基线同步与巡检工具   " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# 1. 检查 remote
$remotes = git remote
if ($remotes -notcontains $UpstreamRemote) {
    Write-Host "[+] 正在添加上游 remote: $UpstreamRemote -> $UpstreamUrl" -ForegroundColor Green
    git remote add $UpstreamRemote $UpstreamUrl
}

# 2. 获取上游最新代码和标签
Write-Host "[*] 正在拉取上游仓库最新提交与标签..." -ForegroundColor Yellow
git fetch $UpstreamRemote --tags

# 3. 计算分支关系
$mergeBase = (git merge-base HEAD "$UpstreamRemote/master").Trim()
$behindCount = (git rev-list --count "HEAD..$UpstreamRemote/master").Trim()
$aheadCount = (git rev-list --count "$UpstreamRemote/master..HEAD").Trim()
$latestUpstreamCommit = (git rev-parse --short "$UpstreamRemote/master").Trim()

Write-Host "`n[状态概览]" -ForegroundColor White
Write-Host "  - 上游最新提交: $latestUpstreamCommit"
Write-Host "  - 共同分叉祖先: $mergeBase"
Write-Host "  - OmniHub 独有自研提交: $aheadCount 个"
Write-Host "  - 上游落后待同步提交: $behindCount 个"

if ([int]$behindCount -eq 0) {
    Write-Host "`n[✓] 当前 OmniHub 已完全同步至上游最新提交，无需更新！" -ForegroundColor Green
    exit 0
}

Write-Host "`n[待同步文件差异统计]:" -ForegroundColor White
git diff --stat "HEAD...$UpstreamRemote/master"

# 4. 检查自研敏感冲突区
$conflictingFiles = git diff --name-only "HEAD...$UpstreamRemote/master" | Where-Object {
    $_ -like "*dian115*" -or $_ -like "*jav*" -or $_ -like "*shorebird*" -or $_ -like "*app_setting*"
}
if ($conflictingFiles) {
    Write-Host "`n[!] 注意：以下文件在上游变动中与 OmniHub 自研模块存在交集：" -ForegroundColor Yellow
    $conflictingFiles | ForEach-Object { Write-Host "    - $_" -ForegroundColor DarkYellow }
}

if ($CheckOnly -or (-not $Merge)) {
    Write-Host "`n[提示] 如需执行合并，请重新运行带 -Merge 参数的指令：" -ForegroundColor Cyan
    Write-Host "       powershell -ExecutionPolicy Bypass -File scripts\sync_upstream.ps1 -Merge" -ForegroundColor White
    Write-Host "       或直接呼唤大模型助手：帮我合并上游更新。" -ForegroundColor Cyan
    exit 0
}

# 5. 执行合并
Write-Host "`n[*] 正在执行 git merge $UpstreamRemote/master..." -ForegroundColor Yellow
git merge "$UpstreamRemote/master"
if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[✓] 合并成功！请运行 flutter analyze 和构建测试进行验证。" -ForegroundColor Green
} else {
    Write-Host "`n[!] 合并存在冲突，请使用大模型助手协助解决冲突！" -ForegroundColor Red
}

