using Oxygen
using HTTP
using CoreAlgo

@get "/health" function (req::HTTP.Request)
    return Dict("status" => "ok", "threads" => Threads.nthreads())
end

@get "/compute/{job_id}" function (req::HTTP.Request, job_id::Int)
    nt = CoreAlgo.main(job_id)
    return Dict(
        "job_id" => nt.job_id,
        "result" => nt.result,
        "threadid" => nt.threadid,
    )
end

const HOST = get(ENV, "SERVER_HOST", "0.0.0.0")
const PORT = parse(Int, get(ENV, "SERVER_PORT", "9397"))

@info "Starting server" host=HOST port=PORT threads=Threads.nthreads()

serve(host = HOST, port = PORT, access_log = nothing)
