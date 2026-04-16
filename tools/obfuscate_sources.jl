#!/usr/bin/env julia
# =============================================================================
# obfuscate_sources.jl
#
# 在 PackageCompiler 构建 sysimage 之前，对包源码做 AST 级混淆：
#   - 去掉模块级 docstring（@doc 宏包裹）
#   - 将「私有」标识符（以单下划线开头、且非 __ 保留名）重命名为不可读短名
#
# 环境变量：
#   PKG_NAME / PKG_DIR — 同 strip_sources.jl
#
# 用法（在仓库根目录）：
#   julia --project=. tools/obfuscate_sources.jl
# =============================================================================

using SHA

const PKG_NAME = get(ENV, "PKG_NAME", "CoreAlgo")
const PKG_DIR  = get(ENV, "PKG_DIR", joinpath(@__DIR__, "..", PKG_NAME))
const SRC_DIR  = joinpath(PKG_DIR, "src")

function should_obfuscate_symbol(s::Symbol)::Bool
    str = String(s)
    length(str) ≤ 1 && return false
    str == "_" && return false
    startswith(str, "__") && return false   # __init__, __module__, ...
    return startswith(str, '_')
end

function collect_symbols!(x, set::Set{Symbol})
    if x isa Expr
        foreach(a -> collect_symbols!(a, set), x.args)
    elseif x isa Symbol
        should_obfuscate_symbol(x) && push!(set, x)
    elseif x isa QuoteNode
        if x.value isa Symbol
            should_obfuscate_symbol(x.value) && push!(set, x.value)
        else
            collect_symbols!(x.value, set)
        end
    end
end

function build_symmap(syms::Vector{Symbol})::Dict{Symbol,Symbol}
    symmap = Dict{Symbol,Symbol}()
    for s in sort(unique(syms))
        h = bytes2hex(sha256(String(s))[1:6])
        symmap[s] = Symbol("_o", h)
    end
    return symmap
end

function rewrite_ast(x, symmap::Dict{Symbol,Symbol})
    if x isa Expr
        Expr(x.head, Any[rewrite_ast(a, symmap) for a in x.args]...)
    elseif x isa Symbol
        get(symmap, x, x)
    elseif x isa QuoteNode
        QuoteNode(rewrite_ast(x.value, symmap))
    else
        x
    end
end

"""去掉 @doc 字符串 ... Expr(:module) 这种外层，只保留 module 本体。"""
function strip_doc_wrapped_modules!(ex::Expr)
    ex.head === :toplevel || return ex
    newargs = Any[]
    for arg in ex.args
        if arg isa Expr && arg.head === :macrocall && length(arg.args) ≥ 4
            m = arg.args[1]
            if m isa GlobalRef && m.name === Symbol("@doc")
                inner = arg.args[end]
                push!(newargs, inner)
                continue
            end
        end
        push!(newargs, arg)
    end
    ex.args = newargs
    return ex
end

"""去掉 LineNumberNode，避免 repr 输出里带源路径与行号。"""
function strip_linenodes!(x)
    if x isa Expr
        x.args = Any[strip_linenodes!(a) for a in x.args if !(a isa LineNumberNode)]
    elseif x isa QuoteNode
        return QuoteNode(strip_linenodes!(x.value))
    else
        return x
    end
    return x
end

function emit_toplevel(io::IO, ex::Expr)
    ex.head === :toplevel || error("expected :toplevel, got $(ex.head)")
    for arg in ex.args
        arg isa LineNumberNode && continue
        # print(Expr) 输出合法 Julia 源码；repr 会变成 :(module …) 无法作为 package 入口加载
        print(io, arg)
        println(io)
        println(io)
    end
end

function obfuscate_file!(path::AbstractString, symmap::Dict{Symbol,Symbol})
    src = read(path, String)
    top = Meta.parseall(src; filename=path)
    top isa Expr || error("parse failed: $path")
    strip_doc_wrapped_modules!(top)
    top2 = rewrite_ast(top, symmap)
    strip_linenodes!(top2)
    open(path, "w") do io
        emit_toplevel(io, top2)
    end
    return nothing
end

function main()
    isdir(SRC_DIR) || error("源码目录不存在: $SRC_DIR")
    paths = String[]
    for (root, _, files) in walkdir(SRC_DIR)
        for f in files
            endswith(f, ".jl") || continue
            push!(paths, joinpath(root, f))
        end
    end
    isempty(paths) && error("未找到任何 .jl: $SRC_DIR")

    syms = Set{Symbol}()
    for p in paths
        top = Meta.parseall(read(p, String); filename=p)
        top isa Expr || error("parse failed: $p")
        collect_symbols!(top, syms)
    end

    symmap = build_symmap(collect(syms))
    @info "Obfuscating package sources" pkg=PKG_NAME n_files=length(paths) n_renames=length(symmap)

    for p in paths
        obfuscate_file!(p, symmap)
        @info "  obfuscated" file=relpath(p, PKG_DIR)
    end
    @info "Obfuscation finished."
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    main()
end
