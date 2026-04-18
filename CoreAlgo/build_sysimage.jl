# 在 CoreAlgo 目录下执行: julia --project=. build_sysimage.jl
# 生成预编译系统镜像（源码以机器码形式编入镜像，便于分发时隐藏 .jl 逻辑；并非密码学意义上的加密）
using PackageCompiler

root = @__DIR__
outdir = joinpath(root, "compiled")
mkpath(outdir)
img = joinpath(outdir, "CoreAlgo_sysimage.dll")

# 不传 precompile_execution_file：不跑额外预编译脚本，镜像体积可能略小，首次运行到未编入路径时可能多 JIT
create_sysimage(
    ["CoreAlgo"];
    sysimage_path = img,
    project = root,
)

println()
println("Sysimage 已生成: ", img)
println("使用方式示例: julia -J \"", img, "\" --project=\"", root, "\" your_script.jl")
