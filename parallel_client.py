"""
并行请求示例：先在本目录启动 Julia 服务：
  julia --project=. server.jl

再运行（需安装 requests）：
  pip install requests
  python parallel_client.py
"""

from __future__ import annotations

import concurrent.futures
import sys

import requests

BASE = "http://127.0.0.1:9397"


def fetch_one(job_id: int) -> dict:
    r = requests.get(f"{BASE}/compute/{job_id}", timeout=120)
    r.raise_for_status()
    return r.json()


def main() -> None:
    try:
        requests.get(f"{BASE}/health", timeout=5)
    except requests.RequestException as e:
        print("无法连接服务，请先运行: julia --project=. server.jl", file=sys.stderr)
        raise SystemExit(1) from e

    job_ids = list(range(1, 5000))
    with concurrent.futures.ThreadPoolExecutor(max_workers=20) as pool:
        results = list(pool.map(fetch_one, job_ids))

    for row in results:
        print(row)


if __name__ == "__main__":
    main()
