# 用法（在项目根目录）：
#   julia --project=. build_sysimage.jl
#
# 会生成 CoreAlgo_sysimage.dll（Windows）或 .so（Linux/macOS），
# 启动服务（任选其一）：
#   julia -J CoreAlgo_sysimage.dll --project=. server.jl
#   .\start_server.bat
# 说明：自定义 sysimage 必须在进程启动时通过 -J 指定，无法仅靠「julia server.jl」加载。

using Pkg
Pkg.activate(@__DIR__)
if Base.find_package("PackageCompiler") === nothing
    Pkg.add("PackageCompiler")
end
using PackageCompiler

out = joinpath(@__DIR__, "CoreAlgo_sysimage." * (Sys.iswindows() ? "dll" : "so"))

create_sysimage(
    ["CoreAlgo"];
    sysimage_path = out,
    project = @__DIR__,
)

println("已生成: ", out)
println("启动示例: julia -J ", basename(out), " --project=. server.jl")
println("或 Windows: .\\start_server.bat")
