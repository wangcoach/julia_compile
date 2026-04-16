#!/usr/bin/env julia
# =============================================================================
# build_sysimage.jl
#
# 将 `CoreAlgo` 包编译进 sysimage（原生机器码 .so/.dll），
# 运行时用 `julia -J <sysimage>` 加载，源码不再出现在磁盘上。
#
# 可复用说明：
#   - 通过环境变量 PKG_NAME 指定要打包的包名（默认 "CoreAlgo"）
#   - 通过环境变量 SYSIMAGE_PATH 指定输出路径（默认 "./CoreAlgoSys.<ext>"）
#   - 通过环境变量 PRECOMPILE_FILE 指定预编译 workload（默认 tools/precompile_workload.jl）
#
# 用法：
#   julia --project=. tools/build_sysimage.jl
#
# 若曾运行 encrypt_sources.jl，编译前需 OBF_KEY 与 decrypt_sources.jl 解密（本脚本会自动调用）。
# =============================================================================

include(joinpath(@__DIR__, "decrypt_sources.jl"))
decrypt_sources!()

using Pkg
Pkg.instantiate()

using PackageCompiler

const PKG_NAME         = get(ENV, "PKG_NAME", "CoreAlgo")
const DEFAULT_EXT      = Sys.iswindows() ? "dll" : (Sys.isapple() ? "dylib" : "so")
const SYSIMAGE_PATH    = get(ENV, "SYSIMAGE_PATH", joinpath(@__DIR__, "..", "$(PKG_NAME)Sys.$(DEFAULT_EXT)"))
const PRECOMPILE_FILE  = get(ENV, "PRECOMPILE_FILE", joinpath(@__DIR__, "precompile_workload.jl"))

@info "Building sysimage" pkg=PKG_NAME output=SYSIMAGE_PATH precompile=PRECOMPILE_FILE

create_sysimage(
    [Symbol(PKG_NAME)];
    sysimage_path = SYSIMAGE_PATH,
    precompile_execution_file = isfile(PRECOMPILE_FILE) ? PRECOMPILE_FILE : nothing,
    incremental = true,
)

@info "Sysimage build finished" path=SYSIMAGE_PATH size_MB=round(filesize(SYSIMAGE_PATH) / 1024 / 1024; digits=2)
