#!/usr/bin/env bash
# 由历史 POC 记录归纳；IP/NIC/权重路径已占位符化，运行前替换 <HOST_x> / <NIC> / <WEIGHTS_PATH>
unset ftp_proxy
unset https_proxy
unset http_proxy
unset HCCL_INTRA_ROCE_ENABLE

export ASCEND_RT_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
export HCCL_OP_EXPANSION_MODE="AIV"
export HCCL_BUFFSIZE=1024
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True
export TASK_QUEUE_ENABLE=1
export VLLM_ASCEND_ENABLE_FLASHCOMM1=1
export VLLM_ASCEND_ENABLE_PREFETCH_MLP=1

vllm serve /data/models/GLM-5.2-w4a4c8-mxfp4 \
  --host 0.0.0.0 \
  --port 9888 \
  --api-server-count 1 \
  --data-parallel-size 1 \
  --tensor-parallel-size 8 \
  --enable-expert-parallel \
  --max-model-len 135000 \
  --max-num-batched-tokens 16384 \
  --max-num-seqs 128 \
  --served-model-name glm \
  --gpu-memory-utilization 0.95 \
  --no-enable-prefix-caching \
  --trust-remote-code \
  --quantization ascend \
  --enable-auto-tool-choice \
  --tool-call-parser glm47 \
  --reasoning-parser glm45 \
  --kv-cache-dtype fp8 \
  --additional-config '{"enable_flashcomm1": true, "enable_cpu_binding": true, "multistream_overlap_shared_expert": true, "enable_dsa_cp": true, "enable_sparse_sfa_c8": true, "enable_sparse_li_c8": true}'
