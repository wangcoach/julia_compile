using Oxygen
using HTTP
using CoreAlgo
using CoreAlgo2

@get "/health" function (req::HTTP.Request)
    return "ok"
end

@get "/compute/{job_id}" function (req::HTTP.Request, job_id::Int)
    nt = if job_id > 100
        CoreAlgo2.main(job_id)
    else
        CoreAlgo.main(job_id)
    end
    return Dict(
        "job_id" => nt.job_id,
        "result" => nt.result,
        "threadid" => nt.threadid,
    )
end

const HOST = get(ENV, "SERVER_HOST", "0.0.0.0")
const PORT = parse(Int, get(ENV, "SERVER_PORT", "9397"))

# parallel：多连接分发到多线程（配合 julia -t N）。async 仅表示 serve 是否阻塞返回，与并发吞吐不是一回事。
serveparallel(host = HOST, port = PORT)
