module Kernel

function compute_sum(job_id::Int)
    return job_id + 1
end

export compute_sum

end