# 在 julia_test 目录下执行: julia --project=. build_sysimage.jl
# 生成包含 CoreAlgo、CoreAlgo2 以及 HTTP/Oxygen 的单一 sysimage（一个 DLL，进程内同时可用两套算法）
using PackageCompiler

root = @__DIR__
outdir = joinpath(root, "compiled")
mkpath(outdir)
img = joinpath(outdir, "server_sysimage.dll")

create_sysimage(
    ["CoreAlgo", "CoreAlgo2"];
    sysimage_path = img,
    project = root,
)

println()
println("Sysimage 已生成: ", img)
println("启动示例: julia -t 4 -J \"", img, "\" --project=\"", root, "\" \"", joinpath(root, "server.jl"), "\"")
