Set-Location $PSScriptRoot
$img = Join-Path $PSScriptRoot "CoreAlgo_sysimage.dll"
if (-not (Test-Path $img)) {
    Write-Error "未找到 CoreAlgo_sysimage.dll，请先运行: julia --project=. build_sysimage.jl"
    exit 1
}
& julia -J $img --project=. server.jl
