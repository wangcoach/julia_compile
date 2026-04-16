# =============================================================================
# precompile_workload.jl
#
# 这里的代码会在构建 sysimage 时实际执行，用于"喂"给编译器，
# 把 CoreAlgo 里会被调用的方法签名全部编成原生代码。
# 被 PackageCompiler 通过 precompile_execution_file 参数调用。
#
# 经验原则：**把线上最常见的调用路径都跑一遍**。
# =============================================================================

using CoreAlgo

for jid in 1:8
    CoreAlgo.main(jid)
end
