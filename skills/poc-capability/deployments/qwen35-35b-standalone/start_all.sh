#!/usr/bin/env bash
# 由历史 POC 记录归纳；IP/NIC/权重路径已占位符化，运行前替换 <HOST_x> / <NIC> / <WEIGHTS_PATH>
source /root/.bashrc
unset http_proxy
unset https_proxy
unset HTTP_PROXY
unset HTTPS_PROXY

# 环境变量配置
export VLLM_USE_MODELSCOPE=False
export ASCEND_RT_VISIBLE_DEVICES=0
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True
export TASK_QUEUE_ENABLE=1
# 可选：如果遇到 HCCL 缓冲区不足，可取消注释并调大
export HCCL_BUFFSIZE=512
export ASCEND_RT_VISIBLE_DEVICES=0,1

vllm serve <USER_PATH> \
  --host 0.0.0.0 \
  --port 8010 \
  --served-model-name Qwen3.5-35B-A3B \
  --trust-remote-code \
  --tensor-parallel-size 1 \
  --max-num-seqs 32 \
  --max-model-len 262144 \
  --max-num-batched-tokens 4096 \
  --gpu-memory-utilization 0.85 \
  --speculative-config '{"method": "qwen3_5_mtp", "num_speculative_tokens": 3}' \
  --compilation-config '{"cudagraph_mode": "FULL_DECODE_ONLY"}' \
  --additional-config '{"enable_cpu_binding": true}' \
  --limit-mm-per-prompt '{"image": 4, "video": 0}' \
  --allowed-local-media-path <USER_PATH>
