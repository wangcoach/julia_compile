# Julia 源码"加密" + 多线程服务化 + Docker 交付 方案

> 通用方案。对任意需要闭源分发的 Julia 算法包都可以 **复制 `tools/` 目录 + `Dockerfile` + 改两行配置** 来复用。

---

## 1. 为什么这样做 —— 背景与目标

- **加密诉求**：交付时磁盘上不应出现可读的核心算法 `.jl` 源码。
- **调用诉求**：`server.jl`（及任何 Julia 代码）仍可通过 `using CoreAlgo` 正常调用。
- **性能诉求**：HTTP 服务需要多线程处理并发请求（用户要求 `-t 10`）。
- **交付诉求**：以 Docker 镜像的方式一键部署，隔离环境。

Julia 生态的标准做法是 **PackageCompiler sysimage**：把 Julia 代码 AOT 编译成原生机器码 (`.so` / `.dll` / `.dylib`)，然后把源码从产物里拿掉。机器码无法还原为原始 `.jl`，等价于"加密"。这比任何 AES + 运行时解密的方案都要 **干净、快、零运行期开销**。

---

## 2. 方案总览

```
┌─────────────────────────────────────────────────────────────────────┐
│  Docker build (multi-stage)                                         │
│                                                                     │
│  Stage 1 [builder]                                                  │
│    ① Pkg.instantiate     ──► 装好依赖                               │
│    ② obfuscate_sources.jl ─► AST：去 doc、私有符号重命名               │
│    ③ encrypt_sources.jl  ─► 可选：OBF_KEY 下 XOR → *.jl.enc，删明文  │
│    ④ decrypt_sources.jl    ─► 编译前解密回 .jl（build_sysimage 也会调）│
│    ⑤ build_sysimage.jl   ─► PackageCompiler → CoreAlgoSys.so        │
│    ⑥ strip (binutils)    ─► strip-debug 降低 .so 符号可读性（可选）   │
│    ⑦ strip_sources.jl    ─► 交付用 stub，删子文件                    │
│                                                                     │
│  Stage 2 [runtime]                                                  │
│    · 只拷贝：sysimage + stub + 依赖 depot + server.jl               │
│    · CMD: julia --threads=10 -J CoreAlgoSys.so server.jl            │
└─────────────────────────────────────────────────────────────────────┘
```

运行时，`using CoreAlgo` 优先绑定 sysimage 中已编译的模块，**磁盘上的 stub 只是让包解析器"看得见"这个包，里面没有任何算法逻辑。**

---

## 3. 目录结构（复用时照着建）

```
project/
├─ Project.toml              # 顶层环境：Oxygen / HTTP / <你的包> / PackageCompiler
├─ Manifest.toml
├─ server.jl                 # 业务入口，using <你的包>
├─ CoreAlgo/                 # 要加密的包
│  ├─ Project.toml
│  └─ src/
│     ├─ CoreAlgo.jl         # 主模块
│     └─ Kernel.jl           # 子文件（可多层 include）
├─ Dockerfile
├─ docker-compose.yml
├─ .dockerignore
└─ tools/
   ├─ obfuscate_sources.jl  # 编译前 AST 混淆（通用）
   ├─ encrypt_sources.jl    # 可选：明文 .jl → XOR → .jl.enc
   ├─ decrypt_sources.jl    # 编译前 .jl.enc → 明文（build_sysimage 会 include）
   ├─ build_sysimage.jl      # 构建脚本（通用）
   ├─ precompile_workload.jl # 预热代码（业务相关，需要改）
   ├─ strip_sources.jl       # 源码抹除脚本（通用）
   └─ README.md              # 本文件
```

---

## 4. 加密流程详解

### 4.1 AST 混淆 — `tools/obfuscate_sources.jl`

- 在 **PackageCompiler 之前** 对 `<PKG_DIR>/src/**/*.jl` 做 AST 变换：
  - 去掉模块顶层的 `@doc` 宏包裹与 docstring，避免字符串与说明进产物。
  - 将「私有」标识符（以单下划线 `_` 开头、且非 `__init__` 等双下划线保留名）重命名为 `_o` + `SHA256` 截断短名，跨文件保持一致。
  - 去掉 `LineNumberNode`，减少 `print` 输出里的路径/行号信息。
- 写出时使用 `print(Expr)`（**不用** `repr`，否则会变成 `:(module …)`，包入口无法加载）。

### 4.2 可选磁盘 XOR — `encrypt_sources.jl` / `decrypt_sources.jl`

- 环境变量 **`OBF_KEY`**：任意字符串，经 `SHA256` 派生 32 字节后与文件逐字节 XOR。
- **`encrypt_sources.jl`**：`*.jl` → `*.jl.enc`，再删除明文 `.jl`。若未设置 `OBF_KEY` 则跳过（仅混淆、不加密文件）。
- **`decrypt_sources.jl`**：存在 `*.jl.enc` 时解密回 `.jl` 并删除 `.enc`；`build_sysimage.jl` 开头会 `include` 并调用，保证本地「先加密再编译」一条命令也能工作。
- **说明**：XOR 仅增加「构建中间产物在磁盘上不可直接当文本打开」这一层，**不是**密码学意义上的强保密；真正抗逆向仍靠后面的 **sysimage 原生码**。

### 4.3 Sysimage 编译 — `tools/build_sysimage.jl`

- 底层调用 `PackageCompiler.create_sysimage`。
- `precompile_execution_file` 指向 `precompile_workload.jl`，里面跑一遍线上常见调用路径，让编译器 trace 出真正需要的方法签名。
- 输出：`<PKG_NAME>Sys.{so|dll|dylib}`，里面是 LLVM 产出的原生机器码。

> 反编译成本：等价于反编译 C/C++ 二进制，实践中几乎不可能还原出 Julia 源码。

### 4.4 源码抹除 — `tools/strip_sources.jl`

- 删除 `<PKG_DIR>/src/` 下所有次级 `.jl` 文件。
- 把主文件 `<PKG_DIR>/src/<PKG_NAME>.jl` 改写为：
  ```julia
  module CoreAlgo
  end
  ```
- 保留 `<PKG_DIR>/Project.toml`，这样 Julia 的包解析器仍能找到这个包的"元信息"。
- 注意：**Project.toml 里的 UUID 必须与编译 sysimage 时一致**，否则 `using` 会退回去找源码。

### 4.5 运行时加载

```bash
julia --project=. --threads=10 --sysimage=./CoreAlgoSys.so server.jl
```

- `-J` 指定 sysimage，里面包含所有已编译方法。
- `using CoreAlgo` 直接从 sysimage 取模块，**不再读磁盘**。
- 启动时间大幅缩短（典型：冷启动从 ~10s 降到 <1s）。

---

## 5. 多线程 & 性能

- `--threads=10` （等价于环境变量 `JULIA_NUM_THREADS=10`）让 Julia 运行期有 10 个 worker 线程。
- Oxygen.jl 的 HTTP 服务器默认会把请求派发到这些线程上，`Threads.@spawn` / `Threads.threadid()` 都可用。
- 若业务要跑真正的数据并行，`@threads for` 或 `Threads.@spawn` 按惯用法写即可。
- Python 客户端（`parallel_client.py`）用 `ThreadPoolExecutor(max_workers=20)` 即可打满服务端。

> 用户消息中同时出现了"10 线程"和"-t 4"，此方案按 **10 线程** 实现。如需 4 线程，仅改两处：`Dockerfile` 的 `JULIA_NUM_THREADS=10` 和 `CMD` 的 `--threads=10`。

---

## 6. Docker 交付

多阶段构建（见根目录 `Dockerfile`）：

| Stage    | 做什么                              | 产物                                      |
| -------- | ----------------------------------- | ----------------------------------------- |
| builder  | 装依赖、编 sysimage、抹源码         | `CoreAlgoSys.so` + stub 后的 `CoreAlgo/`  |
| runtime  | 只拷必要文件                        | 可直接运行的精简镜像                      |

启动：

```bash
docker compose up -d --build
# 或
docker build -t julia-corealgo-service .
docker run --rm -p 9397:9397 julia-corealgo-service
```

若要在构建阶段对中间产物做 XOR 加密，传入密钥（运行镜像内**不会**包含该 ARG，仅 builder 层使用）：

```bash
docker build --build-arg OBF_KEY=你的密钥 -t julia-corealgo-service .
```

验证：

```bash
curl http://127.0.0.1:9397/health
curl http://127.0.0.1:9397/compute/42
```

进容器看源码是否真的被抹：

```bash
docker exec -it julia-corealgo-service cat /app/CoreAlgo/src/CoreAlgo.jl
# 应该只看到空的 `module CoreAlgo end` stub
ls /app/CoreAlgo/src/           # 只剩主文件，子文件已删
ls -lh /app/CoreAlgoSys.so      # 真正的机器码
```

---

## 7. 如何复用到别的项目

1. **复制** `tools/`、`Dockerfile`、`.dockerignore`、`docker-compose.yml` 到新项目。
2. **改包名** —— 假设新包叫 `MyAlgo`：
   - `tools/precompile_workload.jl`：把 `using CoreAlgo` / `CoreAlgo.main` 改成你真实的调用；
   - 构建/抹除脚本支持通过环境变量切换，不用动代码：
     ```bash
     PKG_NAME=MyAlgo julia --project=. tools/build_sysimage.jl
     PKG_NAME=MyAlgo julia              tools/strip_sources.jl
     ```
   - 或直接在 `Dockerfile` 里加 `ENV PKG_NAME=MyAlgo` 再调用脚本。
3. **改服务端口/线程**：`Dockerfile` 末尾 `JULIA_NUM_THREADS` 和 `--threads=N`。
4. **改预热 workload**：`tools/precompile_workload.jl` 里跑一遍 **线上真实会走到的热路径**，trace 越全，冷启动/首请求越快。
5. **确保 Project.toml 里用 `[sources]` 指向本地包**，否则 `Pkg.instantiate` 找不到。

### 7.1 脚本参数矩阵（通用）

| 脚本                         | 关键环境变量     | 默认值                         |
| ---------------------------- | ---------------- | ------------------------------ |
| `tools/obfuscate_sources.jl` | `PKG_NAME` / `PKG_DIR` | `CoreAlgo` / `../CoreAlgo` |
| `tools/encrypt_sources.jl`   | `PKG_NAME` / `PKG_DIR` / **`OBF_KEY`** | 空则跳过加密 |
| `tools/decrypt_sources.jl`   | 同上 + **`OBF_KEY`**（存在 `.jl.enc` 时必填） | — |
| `tools/build_sysimage.jl`    | `PKG_NAME`       | `CoreAlgo`                     |
|                              | `SYSIMAGE_PATH`  | `../<PKG_NAME>Sys.<ext>`       |
|                              | `PRECOMPILE_FILE`| `tools/precompile_workload.jl` |
| `tools/strip_sources.jl`     | `PKG_NAME`       | `CoreAlgo`                     |
|                              | `PKG_DIR`        | `../<PKG_NAME>`                |

### 7.2 多包加密

如果要同时加密多个包，`build_sysimage.jl` 里把

```julia
create_sysimage([Symbol(PKG_NAME)]; ...)
```

换成

```julia
create_sysimage([:PkgA, :PkgB, :PkgC]; ...)
```

并对每个包都跑一遍 `strip_sources.jl`（或扩展脚本，循环处理）。

---

## 8. 安全性说明（对外可对话的口径）

- 交付物中不存在 `.jl` 明文源码（主文件是空 stub，子文件已删）。
- 算法逻辑以 **LLVM 编译后的原生机器码** 形式存在于 sysimage 中；AST 混淆与 XOR 主要降低**源码与符号可读性**，核心防护仍是 **sysimage + strip-debug**。
- 运行镜像不携带 `OBF_KEY`；若使用 `--build-arg OBF_KEY=...`，密钥仅存在于构建机的 builder 层历史中，请注意 registry/缓存策略。
- 该做法是 [JuliaHub / Julia Computing 官方推荐的商业分发方式](https://julialang.github.io/PackageCompiler.jl/stable/sysimages.html)。

## 9. 常见坑 & 对策

| 坑                                                                      | 对策                                                                                                   |
| ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `using CoreAlgo` 报 `LoadError: ArgumentError: Package CoreAlgo not found in current path` | 顶层 `Project.toml` 的 `[sources]` 必须保留指向本地包路径；`CoreAlgo/Project.toml` 的 UUID 必须不变。 |
| 抹除源码后 Julia 警告 `invalidated due to source file change`           | 必须走 `-J CoreAlgoSys.so` 启动；不要在无 sysimage 的情况下执行 `using CoreAlgo`。                     |
| sysimage 里找不到线上实际调用的方法，首请求很慢                         | 把真实调用样例补进 `precompile_workload.jl`。                                                          |
| 镜像过大                                                                | `runtime` stage 已只拷必须文件；如需更小，可进一步删 `/root/.julia/registries`、裁剪 stdlib。          |
| Windows 上 sysimage 文件扩展名是 `.dll`                                 | 构建脚本已自动按平台选后缀；Dockerfile 里走 Linux，固定 `.so`。                                        |

---

## 10. 升级算法的发布流程

1. 开发者在本地仓库修改 `CoreAlgo/src/*.jl`（源码版仓库，**勿提交到交付镜像的仓库**）。
2. 如有新公共 API，更新 `tools/precompile_workload.jl` 覆盖新的调用路径。
3. `docker compose build`（CI 中跑）→ 产物里源码已被抹除。
4. 推送到 registry / 客户环境 `docker compose up -d`。

> 建议把 "带源码的开发仓" 与 "交付仓" 分两个 repo，或用 CI job 在构建阶段把源码临时拉进来再擦掉。
