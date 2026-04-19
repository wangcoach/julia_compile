# julia_compile

Julia + [Oxygen](https://github.com/OxygenFramework/Oxygen.jl) HTTP 服务示例：根目录环境聚合两个本地包 **`CoreAlgo`** 与 **`CoreAlgo2`**，按 `job_id` 分支调用（`job_id > 100` 走 `CoreAlgo2`，否则走 `CoreAlgo`）。可选使用 [PackageCompiler](https://github.com/JuliaLang/PackageCompiler.jl) 生成单一 sysimage 以加快启动。

## 环境要求

- Julia 1.11+（开发时使用 1.11.6）
- 克隆后请在仓库根目录操作（下文路径以根目录为准）

## 首次：安装依赖

在仓库根目录执行：

```bash
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

若缺少 `Manifest.toml` 或需重新解析依赖，可先：

```bash
julia --project=. -e "using Pkg; Pkg.resolve()"
```

## 启动 HTTP 服务

默认监听 `0.0.0.0:9397`，可通过环境变量 `SERVER_HOST`、`SERVER_PORT` 修改。

**源码直接启动：**

```bash
julia --project=. server.jl
```

**使用编译好的 sysimage（推荐在已生成 `compiled/server_sysimage.dll` 后）：**

```bash
julia -t 4 -J ".\compiled\server_sysimage.dll" --project=. server.jl
```

`-t 4` 为 Julia 线程数，可按机器调整。

### 接口

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/health` | 健康检查，返回 `ok` |
| GET | `/compute/{job_id}` | 计算并返回 JSON（含 `job_id`、`result`、`threadid`） |

## 编译 sysimage

在根目录执行（耗时较长，会写入 `compiled/server_sysimage.dll`）：

```bash
julia --project=. build_sysimage.jl
```

该镜像将 `CoreAlgo`、`CoreAlgo2`、`Oxygen`、`HTTP` 等编入**单一** DLL，与 `server.jl` 配合使用（见上文 `-J` 启动方式）。

> 产物体积大，已通过 `.gitignore` 忽略 `compiled/`，勿将 DLL 提交到 Git。

## Python 压测客户端

需已安装 `requests`，服务已启动：

```bash
pip install requests
python -m unittest parallel_client -v
```

## 仓库布局（简要）

| 路径 | 说明 |
|------|------|
| `Project.toml` / `Manifest.toml` | 根环境依赖与版本锁定 |
| `server.jl` | Oxygen 路由与服务入口 |
| `CoreAlgo/`、`CoreAlgo2/` | 本地 path 包（算法与 `main`） |
| `build_sysimage.jl` | 生成 `compiled/server_sysimage.dll` |
| `parallel_client.py` | 并发请求 unittest |
