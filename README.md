# julia_compile

Oxygen HTTP 服务 + 本地包 `CoreAlgo` + 可选 [PackageCompiler](https://github.com/JuliaLang/PackageCompiler.jl) 生成 sysimage 的示例项目。

## 结构

```
.
├── CoreAlgo/              # 核心算法包（Julia 标准包布局）
│   ├── Project.toml
│   └── src/
│       ├── CoreAlgo.jl
│       └── Kernel.jl
├── server.jl              # Oxygen 路由，调用 CoreAlgo.main
├── build_sysimage.jl      # 将 CoreAlgo 打入系统镜像
├── parallel_client.py     # Python 并行请求示例
├── run_test.jl            # 仅测试 CoreAlgo，不启动 HTTP
├── start_server.bat       # Windows：带 -J 启动服务
└── Project.toml
```

## 运行

```bash
# 安装依赖并注册本地包 CoreAlgo（首次克隆后）
julia --project=. -e "using Pkg; Pkg.instantiate()"

# 若 Manifest 路径异常，可再执行：julia --project=. sync_pkg.jl

# 开发模式启动 HTTP
julia --project=. server.jl
```

```bash
# 测试算法
julia --project=. run_test.jl
```

## 生成 sysimage 并启动

```bash
julia --project=. build_sysimage.jl
# Windows
.\start_server.bat
```

国内可设置 `JULIA_PKG_SERVER` 加速 Pkg 下载（见 Julia 镜像站说明）；编译耗时主要取决于本机 CPU。

## Python 客户端

```bash
pip install requests
python parallel_client.py
```

需先启动 `server.jl` 或 `start_server.bat`，且端口与 `server.jl` 中 `serve` 一致。

## 许可

仓库代码按原项目用途使用；依赖库各自遵循其许可证。
