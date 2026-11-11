#!/usr/bin/env bash
# 由历史 POC 记录归纳；IP/NIC/权重路径已占位符化，运行前替换 <HOST_x> / <NIC> / <WEIGHTS_PATH>
# Load model from ModelScope to speed up download
export VLLM_USE_MODELSCOPE=False
# Size of the shared buffer (in MB) used by HCCL for NPU-to-NPU collective communication
export HCCL_BUFFSIZE=512
# To reduce memory fragmentation and avoid out of memory
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True

export ASCEND_RT_VISIBLE_DEVICES=2,3

# Model weight path; can be a ModelScope model id (e.g., Eco-Tech/Qwen3.8-27B-w8a8) or a local directory path
# Ensure the model path matches the directory recorded during download
export MODEL_PATH=<WEIGHTS_PATH>

vllm serve $MODEL_PATH \
    --host 0.0.0.0 \
    --port 30002 \
    --tensor-parallel-size 2 \
    --quantization ascend \
    --served-model-name qwen3.8 \
    --max-num-seqs 128 \
    --max-model-len 419840 \
    --max-num-batched-tokens 16384 \
    --trust-remote-code \
    --no-enable-prefix-caching \
    --gpu-memory-utilization 0.95 \
    --speculative-config '{"method": "qwen3_5_mtp", "num_speculative_tokens": 3, "enforce_eager": true}' \
    --compilation-config '{"cudagraph_mode":"FULL_DECODE_ONLY"}' \
    --additional-config '{"enable_cpu_binding":true}' \
 2>&1 | tee start_vllm.log
