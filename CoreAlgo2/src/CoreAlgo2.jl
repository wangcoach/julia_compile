module CoreAlgo2

include("Kernel.jl")
using .Kernel
using DataFrames
using CSV
using JSON3

function _results_csv_path()
    joinpath(dirname(@__DIR__), "results.csv")
end

function main(job_id::Int)
    r = compute_sum(job_id)
    nt = (
        job_id = job_id,
        result = r,
        threadid = Threads.threadid(),
    )
    meta = Dict("job_id" => job_id, "result" => r, "threadid" => nt.threadid)
    df = DataFrame(
        job_id = [job_id],
        result = [r],
        threadid = [nt.threadid],
        meta_json = [String(JSON3.write(meta))],
    )
    path = _results_csv_path()
    if isfile(path)
        CSV.write(path, df; append = true, writeheader = false)
    else
        CSV.write(path, df)
    end
    return nt
end

end
