# 一次性：将 CoreAlgo 路径修正为项目根下的 ./CoreAlgo（更新 Manifest）
using Pkg
Pkg.activate(@__DIR__)
try
    Pkg.rm("CoreAlgo")
catch
end
Pkg.develop(path = joinpath(@__DIR__, "CoreAlgo"))
println("CoreAlgo 已指向: ", joinpath(@__DIR__, "CoreAlgo"))
