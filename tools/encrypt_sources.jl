#!/usr/bin/env julia
# =============================================================================
# encrypt_sources.jl
#
# 将 PKG_DIR/src 下所有 .jl 做 XOR 加密，输出为同名 .jl.enc 并删除明文 .jl。
# 密钥：环境变量 OBF_KEY（任意字符串，内部经 SHA256 派生 32 字节 keystream）。
#
# 若未设置 OBF_KEY 或为空：不做事（便于本地仅混淆、不加密）。
#
# 用法：
#   OBF_KEY='your-secret' julia tools/encrypt_sources.jl
# =============================================================================

using SHA

const PKG_NAME = get(ENV, "PKG_NAME", "CoreAlgo")
const PKG_DIR  = get(ENV, "PKG_DIR", joinpath(@__DIR__, "..", PKG_NAME))
const SRC_DIR  = joinpath(PKG_DIR, "src")

function xor_crypt!(data::Vector{UInt8}, key::Vector{UInt8})
    @assert !isempty(key)
    for i in eachindex(data)
        data[i] = xor(data[i], key[mod1(i, length(key))])
    end
    return data
end

function main()
    keystr = get(ENV, "OBF_KEY", "")
    if isempty(strip(keystr))
        @info "OBF_KEY 未设置，跳过磁盘加密（仅混淆时可直接编译）。"
        return
    end
    key = vec(sha256(codeunits(strip(keystr))))
    isdir(SRC_DIR) || error("源码目录不存在: $SRC_DIR")

    n = 0
    for (root, _, files) in walkdir(SRC_DIR)
        for f in files
            endswith(f, ".jl") || continue
            endswith(f, ".jl.enc") && continue
            path = joinpath(root, f)
            encpath = path * ".enc"
            data = read(path)
            xor_crypt!(data, key)
            write(encpath, data)
            rm(path)
            n += 1
            @info "  encrypted" file=relpath(path, PKG_DIR)
        end
    end
    @info "Source encryption finished." n_files=n
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    main()
end
