@echo off
cd /d "%~dp0"
if not exist "CoreAlgo_sysimage.dll" (
  echo 未找到 CoreAlgo_sysimage.dll，请先运行: julia --project=. build_sysimage.jl
  exit /b 1
)
julia -J CoreAlgo_sysimage.dll --project=. server.jl
