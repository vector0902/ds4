# ds4-server Tuning Guide (H20 96GB)

## Host Specs
- GPU: NVIDIA H20 (sm_90), 97 GiB HBM3
- CPU: 32 cores, 128 GiB RAM

## Current Optimal Settings

```bash
export DS4_CUDA_COPY_MODEL=1          # 必须 — 将80GiB模型完整拷贝到HBM, 否则速度极慢
export DS4_CUDA_Q8_F16_CACHE_MB=3072  # 最大安全值(已验证4096会OOM), 缓存关键权重为F16加速

OPTS=" --port 8888 --prefill-chunk 8192 --threads 4 "
```

## 性能实测

| 指标 | 优化前 (UVA+主机内存) | 优化后 (HBM) |
|------|----------------------|--------------|
| Prefill (5000 tok) | 27 tok/s, 185s | **165 tok/s, 30s** |
| Decode (thinking) | - | **32 tok/s** |
| Decode (tools) | 3.6 tok/s | **27 tok/s** |
| GPU 显存带宽 | 0% | ~3% |
| GPU 功耗 | 145W | ~300W |

## 已穷举可调参数

### 已检查但不值得修改的环境变量

| 变量 | 结论 |
|------|------|
| `DS4_CUDA_MOE_TILE4` | 仅影响prefill大batch, decode走独立单token路径, 无影响 |
| `DS4_CUDA_MOE_ATOMIC_DOWN` | 显存占用高, H20剩余空间不够 |
| `DS4_CUDA_MOE_GATE_ROW512/2048` | 自动调优已选最优值1024, 手动指定更小值无帮助 |
| `DS4_CUDA_MOE_DOWN_ROW512/1024` | 同上, 自动调优已最优 |
| `DS4_CUDA_SERIAL_F16_MATMUL` | 强制串行matmul, 会更慢, 不要设置 |
| `DS4_CUDA_SERIAL_ROUTER` | 同上, 更慢 |
| `DS4_CUDA_Q8_F16_ALL=1` | 需要~160GiB显存, 在H20 96GB上OOM |
| `DS4_CUDA_ATTN_Q_B_F32_CACHE` | 需要额外显存, 且HBM下F16速度已足够 |
| `DS4_CUDA_DISABLE_QKV_RMS_FUSED` | 默认已启用优化fusion, 最好不要禁用它 |
| `DS4_CUDA_DISABLE_SHARED_GATE_UP_PAIR` | 同上, 默认已启用 |
| `DS4_CUDA_DISABLE_HC_SPLIT_NORM_FUSED` | 同上 |
| `DS4_CUDA_DISABLE_Q8_HC_EXPAND_FUSED` | 同上 |

| 选项 | 结论 |
|------|------|
| `--warm-weights` | 对`DS4_CUDA_COPY_MODEL=1`冗余, 拷贝过程已触达所有页面 |
| `--quality` | 偏好精确kernel, 关闭加速近似路径, 会变慢 |
| `--power` | 默认100已满 |
| `--ssd-streaming` | 需要模型不在HBM时使用, 当前已全部放入HBM, 不需要 |
| `--threads` | 当前`--threads 30`多余, CPU负载仅<1, 4线程足矣 |
| `--mtp FILE` | 有MTP draft模型文件可提速2-3x, 但当前ds4flash没有MTP配套文件 |

## 单卡极限与更优路径

**当前H20性能已达极限**, 瓶颈在H20的算力(TFLOPS是H100的~1/13)。下一步提升只有：

1. **多GPU分布式推理** (`./ds4-server --help distributed`)
2. **使用更高算力GPU** (H100/B200)
3. **MTP draft模型** (需要配套GGUF文件, 可提decode速2-3x)

## 附: 最耗时的隐藏开销 (工具调用场景)

```
live kv cache miss ... reason=token-mismatch
```

每次工具调用返回后, prompt变更导致KV缓存失效, 强制重跑完整prefill。
日志实测: 每次工具调用约浪费35s重复prefill。这是DS4工具调用流程的固有开销。
