#!/usr/bin/env julia
# =============================================================================
# decrypt_sources.jl
#
# 若存在 .jl.enc，则用 OBF_KEY 解密回明文 .jl，并删除 .jl.enc。
# 供 build_sysimage.jl 在编译前 include；也可单独运行。
#
# 若无 .jl.enc：立即返回（明文混淆直编场景）。
# 若有 .jl.enc 但 OBF_KEY 为空：报错。
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

function decrypt_sources!()
    isdir(SRC_DIR) || error("源码目录不存在: $SRC_DIR")
    enc_paths = String[]
    for (root, _, files) in walkdir(SRC_DIR)
        for f in files
            endswith(f, ".jl.enc") || continue
            push!(enc_paths, joinpath(root, f))
        end
    end
    isempty(enc_paths) && return

    keystr = get(ENV, "OBF_KEY", "")
    isempty(strip(keystr)) && error("存在 $(length(enc_paths)) 个 .jl.enc 但未设置 OBF_KEY，无法解密编译。")
    key = vec(sha256(codeunits(strip(keystr))))

    for encpath in enc_paths
        path = replace(encpath, r"\.jl\.enc$" => ".jl")
        isfile(path) && error("解密目标已存在明文文件: $path")
        data = read(encpath)
        xor_crypt!(data, key)
        write(path, data)
        rm(encpath)
        @info "  decrypted" file=relpath(path, PKG_DIR)
    end
    @info "Source decryption finished." n_files=length(enc_paths)
    return
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    decrypt_sources!()
end
