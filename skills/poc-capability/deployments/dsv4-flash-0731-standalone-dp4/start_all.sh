#!/usr/bin/env bash
# 由历史 POC 记录归纳；IP/NIC/权重路径已占位符化，运行前替换 <HOST_x> / <NIC> / <WEIGHTS_PATH>
source /usr/local/Ascend/driver/bin/setenv.bash
source /usr/local/Ascend/cann/set_env.sh

export HCCL_BUFFSIZE=1024
export OMP_PROC_BIND=false
export OMP_NUM_THREADS=10
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True

export VLLM_VERSION=v0.27.1
export ASCEND_RT_VISIBLE_DEVICES=4,5,6,7
 
vllm serve <WEIGHTS_PATH>  \
  --host 0.0.0.0 \
  --port 9000 \
  --api-server-count 1 \
  --data-parallel-size 4 \
  --max_model_len 1048576 \
  --max-num-batched-tokens 8192 \
  --served-model-name dsv4 \
  --gpu-memory-utilization 0.9 \
  --enable-expert-parallel \
  --async-scheduling \
  --max-num-seqs 64 \
  --block-size 128 \
  --tokenizer-mode deepseek_v4 \
  --tool-call-parser deepseek_v4 \
  --enable-auto-tool-choice \
  --reasoning-parser deepseek_v4 \
  --trust-remote-code \
  --no-enable-prefix-caching \
  --speculative-config '{"method":"dspark","num_speculative_tokens":5,"enforce_eager":true}' \
  --additional_config '{"enable_cpu_binding": true, "multistream_overlap_shared_expert": true,"enable_shared_expert_dp":true}' \
  --compilation-config '{"cudagraph_mode": "FULL_DECODE_ONLY"}' \
2>&1 | tee dsv4.log
