"""
核心算法包：可拆成多个 .jl，在模块内用 include 组合。
交付时用 PackageCompiler 打成 sysimage，整个包（含所有 include 的文件）都会进镜像。
"""
module CoreAlgo

include("Kernel.jl")

export main

function main(job_id::Int)
    r = _compute_sum(job_id)
    return (
        job_id = job_id,
        result = r,
        threadid = Threads.threadid(),
    )
end

end
