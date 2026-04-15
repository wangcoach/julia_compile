# 本文件由 CoreAlgo.jl include 进来，属于同一模块，不单独构成 package。
# 打包 sysimage 时，会随 CoreAlgo 一并编译进二进制。

function _compute_sum(job_id::Int)

    return job_id + 1
end
