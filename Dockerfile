# syntax=docker/dockerfile:1.6
# =============================================================================
# Multi-stage Dockerfile
#   Stage 1 (builder) : 安装依赖 → 编译 sysimage → 抹除源码
#   Stage 2 (runtime) : 仅携带 sysimage + stub + server.jl + 依赖 depot
# =============================================================================

ARG JULIA_VERSION=1.11.6

# ---------- Stage 1: builder ----------
FROM julia:${JULIA_VERSION} AS builder

# 可选：磁盘加密 .jl.enc 的密钥。构建时传入：docker build --build-arg OBF_KEY=你的密钥 .
ARG OBF_KEY=""
ENV OBF_KEY=${OBF_KEY}

WORKDIR /build

# 先复制清单文件，利用 Docker layer cache 避免每次改代码都重新装依赖
COPY Project.toml Manifest.toml ./
COPY CoreAlgo/Project.toml ./CoreAlgo/Project.toml
# CoreAlgo 源码在构建阶段必须存在（要被编译进 sysimage）
COPY CoreAlgo/src ./CoreAlgo/src

RUN julia --project=. -e 'using Pkg; Pkg.instantiate()'

# 复制构建脚本与服务入口
COPY tools ./tools
COPY server.jl ./server.jl

# ① AST 混淆（私有符号重命名、去 docstring）→ ② 可选 XOR 加密为 .jl.enc → ③ 解密回明文再编译
RUN julia --project=. tools/obfuscate_sources.jl
RUN julia tools/encrypt_sources.jl
RUN julia tools/decrypt_sources.jl
RUN julia --project=. tools/build_sysimage.jl

# 去掉调试符号，降低逆向可读性（若镜像无 strip 则忽略）
RUN strip --strip-debug /build/CoreAlgoSys.so 2>/dev/null || true

# 抹除源码：把 CoreAlgo/src/*.jl 替换为 stub，实际机器码留在 .so 中
RUN julia tools/strip_sources.jl

# ---------- Stage 2: runtime ----------
FROM julia:${JULIA_VERSION} AS runtime

# 运行期线程数（用户需求：10 线程）
ENV JULIA_NUM_THREADS=10 \
    SERVER_HOST=0.0.0.0 \
    SERVER_PORT=9397

WORKDIR /app

# 依赖 depot（已预编译）
COPY --from=builder /root/.julia /root/.julia

# 工程文件 & 入口
COPY --from=builder /build/Project.toml     /app/Project.toml
COPY --from=builder /build/Manifest.toml    /app/Manifest.toml
COPY --from=builder /build/server.jl        /app/server.jl
# 只剩 stub 的 CoreAlgo（源码已被抹除）
COPY --from=builder /build/CoreAlgo         /app/CoreAlgo
# 真正的代码 —— 原生机器码 sysimage
COPY --from=builder /build/CoreAlgoSys.so   /app/CoreAlgoSys.so

EXPOSE 9397

# 启动：10 线程 + 加载 sysimage
CMD ["julia", \
     "--project=/app", \
     "--threads=10", \
     "--sysimage=/app/CoreAlgoSys.so", \
     "/app/server.jl"]
