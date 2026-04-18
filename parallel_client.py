"""
客户端并发压测（unittest）。

服务端需已启动，例如（julia_test 目录）：
  julia -t 4 -J ".\\CoreAlgo\\compiled\\CoreAlgo_sysimage.dll" --project=".\\CoreAlgo" ".\\server.jl"

运行（需 requests）：
  pip install requests
  python -m unittest parallel_client -v

说明：这里的「1～8 线程」指 Python 端 ThreadPoolExecutor 的并发数，
与 Julia 服务端 -t 4 无关；每次配置各发 100 次 GET /compute/{id}。
"""

from __future__ import annotations

import concurrent.futures
import time
import unittest

import requests

BASE = "http://127.0.0.1:9397"
REQUEST_TIMEOUT = 120
NUM_REQUESTS = 1000


def _fetch_one(job_id: int) -> dict:
    r = requests.get(f"{BASE}/compute/{job_id}", timeout=REQUEST_TIMEOUT)
    r.raise_for_status()
    return r.json()


class TestParallelComputeBenchmark(unittest.TestCase):
    """对 /compute 做 100 次请求，分别用客户端 1～8 线程测量总耗时。"""

    @classmethod
    def setUpClass(cls) -> None:
        try:
            r = requests.get(f"{BASE}/health", timeout=5)
            r.raise_for_status()
        except requests.RequestException as e:
            raise unittest.SkipTest(
                "无法连接服务，请先启动: julia --project=CoreAlgo server.jl"
            ) from e

    def test_client_threads_1_to_8_time_100_requests(self) -> None:
        job_ids = list(range(1, NUM_REQUESTS + 1))
        rows: list[tuple[int, float, float]] = []

        for workers in range(1, 9):
            with self.subTest(client_workers=workers):
                t0 = time.perf_counter()
                with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
                    list(pool.map(_fetch_one, job_ids))
                elapsed = time.perf_counter() - t0
                qps = NUM_REQUESTS / elapsed if elapsed > 0 else 0.0
                rows.append((workers, elapsed, qps))

        # 终端编码不一，表头用英文避免乱码
        header = f"{'workers':>8} {'total_s(100req)':>18} {'req/s':>10}"
        line = "-" * 40
        print()
        print(header)
        print(line)
        for workers, elapsed, qps in rows:
            print(f"{workers:>8} {elapsed:>18.3f} {qps:>10.1f}")
        print(line)

        for workers, elapsed, _ in rows:
            self.assertGreater(elapsed, 0.0, msg=f"workers={workers} 耗时异常")


if __name__ == "__main__":
    unittest.main()
