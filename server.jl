using Oxygen
using HTTP
using CoreAlgo

@get "/health" function (req::HTTP.Request)
    return "ok"
end

@get "/compute/{job_id}" function (req::HTTP.Request, job_id::Int)
    nt = CoreAlgo.main(job_id)
    return Dict(
        "job_id" => nt.job_id,
        "result" => nt.result,
        "threadid" => nt.threadid,
    )
end

serve(host = "127.0.0.1", port = 9397)
