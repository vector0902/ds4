# ds4-server Tuning Guide (H20 96GB)

## Host Specs
- GPU: NVIDIA H20 (sm_90), 97 GiB HBM
- CPU: 32 cores
- RAM: 128 GiB (mostly free)
- Model: ~80 GiB Q8 (ds4flash.gguf, ~671B MoE)

## Current Settings & Performance

### ds4-server.sh

```bash
export DS4_CUDA_COPY_MODEL=1          # 必须: 将80GiB模型载入HBM
export DS4_CUDA_Q8_F16_CACHE_MB=3072  # 推荐: 3GiB F16反量化缓存, 再高会OOM
#export DS4_CUDA_Q8_F16_CACHE_MB=4096 # 已验证在H20 96GB上OOM

OPTS=" --port 8888 --prefill-chunk 8192 --threads 4 "
```

### 性能数据

| 阶段 | 优化前 | 优化后 | 提升 |
|------|--------|--------|------|
| Prefill | 27 tok/s | 165 tok/s | 6x |
| Decode (thinking) | - | 32 tok/s | - |
| Decode (tools) | 3.6 tok/s | 27 tok/s | 7.5x |
| GPU显存带宽 | 0% | ~3% | - |
| GPU功耗 | 145W | ~300W | - |

### 关键优化说明

1. **DS4_CUDA_COPY_MODEL=1** — 将模型完整拷贝到 HBM，避免通过 PCIe UVA 读取主机内存。不加此选项时权重在系统内存中，速度极慢。
2. **DS4_CUDA_Q8_F16_CACHE_MB=3072** — 将关键权重（attention output、shared expert等）预反量化为 F16 存于 HBM，减少运行时反量化开销。H20 96GB 下 3GiB 为安全上限。
3. **--prefill-chunk 8192** — 增大预填充粒度，提升 GPU 利用率。4096→8192 使 prefill 提升约 30%。
4. **--threads 4** — 4 个 CPU 辅助线程足够。该主机 CPU 负载极低（load < 1），线程数影响不大。

### 减速元凶: token-mismatch

工具调用场景下，每次工具返回结果后会触发 KV 缓存失效（`reason=token-mismatch`），强制重新跑完整 prefill。日志中每次工具调用浪费约 35s 重复 prefill 时间。

```
live kv cache miss live=5873 prompt=5893 common=5638 reason=token-mismatch
```

这是 DS4 工具调用流程的固有开销，无法通过参数消除。

### 进一步提速唯一路径

单卡 H20 已接近极限。MoE 模型 decode 受限于 H20 较低的 TFLOPS（相比 H100）。下一级加速需要：

- 多 GPU 分布式推理（`--help distributed`）
- 或使用更高算力的 GPU（H100/B200）
