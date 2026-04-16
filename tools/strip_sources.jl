#!/usr/bin/env julia
# =============================================================================
# strip_sources.jl
#
# 在 sysimage 构建完成后，把被编译进 sysimage 的那个包的源代码 *.jl
# 替换成只包含 `module XXX end` 的占位 stub。
#
# 原理：
#   - sysimage 里已有包的已编译机器码
#   - 启动 julia 时使用 `-J <sysimage>` 加载 sysimage
#   - `using CoreAlgo` 会直接绑定 sysimage 中的模块，不再读磁盘源码
#   - 但 Julia 的包解析器仍需要"能找到"这个包（Project.toml + 根源文件存在）
#   - 所以保留 Project.toml 和一个空 stub 主文件即可
#
# 可复用说明：
#   - PKG_NAME 环境变量指定包名（默认 CoreAlgo）
#   - PKG_DIR  环境变量指定包目录（默认 ./<PKG_NAME>）
# =============================================================================

const PKG_NAME = get(ENV, "PKG_NAME", "CoreAlgo")
const PKG_DIR  = get(ENV, "PKG_DIR",  joinpath(@__DIR__, "..", PKG_NAME))
const SRC_DIR  = joinpath(PKG_DIR, "src")
const MAIN_FILE = joinpath(SRC_DIR, "$(PKG_NAME).jl")

@info "Stripping package sources" pkg=PKG_NAME src_dir=SRC_DIR

isdir(SRC_DIR) || error("源码目录不存在: $SRC_DIR")

for (root, _, files) in walkdir(SRC_DIR)
    for f in files
        endswith(f, ".jl") || continue
        path = joinpath(root, f)
        if path == MAIN_FILE
            continue
        end
        @info "  删除次级源文件" file=relpath(path, PKG_DIR)
        rm(path)
    end
end

stub = """
# ============================================================
# THIS IS A STUB. Real compiled code lives in the sysimage.
# Do NOT edit. Regenerate via tools/build_sysimage.jl.
# ============================================================
module $(PKG_NAME)
end
"""

open(MAIN_FILE, "w") do io
    write(io, stub)
end
@info "  已写入 stub" file=relpath(MAIN_FILE, PKG_DIR)

@info "Source stripping finished."
