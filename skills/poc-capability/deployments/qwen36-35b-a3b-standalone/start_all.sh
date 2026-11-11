#!/usr/bin/env bash
# 由历史 POC 记录归纳；IP/NIC/权重路径已占位符化，运行前替换 <HOST_x> / <NIC> / <WEIGHTS_PATH>
export VLLM_USE_MODELSCOPE=True
export ASCEND_RT_VISIBLE_DEVICES=0
export VLLM_USE_V2_MODEL_RUNNER=1
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=3000
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True
export OMP_PROC_BIND=false
export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export TASK_QUEUE_ENABLE=1
export ASCEND_RT_VISIBLE_DEVICES=6,7
export ASCEND_LOCAL_COMM_RES='{"version":"1.3"}'

vllm serve /data/models/Qwen3.6-35B-A3B-w8a8-mxfp8 \
  --host 0.0.0.0 \
  --port 12315 \
  --served-model-name qwen3.6 \
  --trust-remote-code \
  --quantization ascend \
  --safetensors-load-strategy lazy \
  --tensor-parallel-size 2 \
  --data-parallel-size 1 \
  --max-model-len 135168 \
  --max-num-seqs 128 \
  --max-num-batched-tokens 16384 \
  --seed 1024 \
  --gpu-memory-utilization 0.95 \
  --speculative-config '{"method":"qwen3_5_mtp","num_speculative_tokens":3}' \
  --compilation-config '{"cudagraph_mode":"FULL_DECODE_ONLY"}' \
  --additional-config '{"enable_flashcomm1": true, "enable_cpu_binding":true,"ascend_compilation_config":{"enable_npugraph_ex":true,"enable_static_kernel":false,"enable_super_kernel":false}}' \
  --no-enable-prefix-caching
