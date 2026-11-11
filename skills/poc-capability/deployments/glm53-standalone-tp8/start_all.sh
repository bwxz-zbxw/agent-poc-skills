#!/usr/bin/env bash
# 由历史 POC 记录归纳；IP/NIC/权重路径已占位符化，运行前替换 <HOST_x> / <NIC> / <WEIGHTS_PATH>
source /root/.bashrc
export HCCL_DFS_CONFIG="task_exception:off,inconsistent_check:off"
export PROMETHEUS_MULTIPROC_DIR=/dev/shm/vllm_metrics && mkdir -p $PROMETHEUS_MULTIPROC_DIR
export ASCEND_RT_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True
export TASK_QUEUE_ENABLE=1

# 修改本机对应网卡名和本机ip
nic_name=<NIC>
local_ip=<HOST_A>

export HCCL_IF_IP=$local_ip
export GLOO_SOCKET_IFNAME=$nic_name
export TP_SOCKET_IFNAME=$nic_name
export HCCL_SOCKET_IFNAME=$nic_name
export OMP_PROC_BIND=false
export OMP_NUM_THREADS=100
export HCCL_BUFFSIZE=400
export HCCL_OP_EXPANSION_MODE="AIV"
#MLP权重预提取，主要用于小并发场景
export VLLM_ASCEND_ENABLE_PREFETCH_MLP=1
export HCCL_INTRA_PCIE_ENABLE=1
export HCCL_INTRA_ROCE_ENABLE=0
export ASCEND_LAUNCH_BLOCKING=0

export DYNAMIC_EPLB="true"
#开FASTOKENS，加速encode，decode（文本和token互相转换）
export VLLM_USE_FASTOKENS=1
# cann9.2.0不需要带上下面的算子优化
# source <USER_PATH>

vllm serve <WEIGHTS_PATH> \
  --host 0.0.0.0 \
  --port 8004 \
  --distributed-executor-backend mp \
  --data-parallel-size 1 \
  --data-parallel-size-local 1 \
  --data-parallel-address $local_ip \
  --data-parallel-rpc-port 13389 \
  --tensor-parallel-size 8 \
  --seed 1024 \
  --served-model-name glm \
  --enable-expert-parallel \
  --max-num-seqs 128 \
  --max-model-len 202752 \
  --max-num-batched-tokens 8192 \
  --trust-remote-code \
  --enable-prefix-caching \
  --gpu-memory-utilization 0.95 \
  --quantization ascend \
  --async-scheduling \
  --enable-auto-tool-choice \
  --tool-call-parser glm47 \
  --reasoning-parser glm45 \
  --kv-cache-dtype fp8 \
  --attention_config.indexer_kv_dtype fp8 \
  --compilation-config '{"cudagraph_mode":"FULL_DECODE_ONLY"}' \
  --hf-overrides '{"use_index_cache": true, "index_topk_freq": 4}' \
  --speculative-config '{"num_speculative_tokens": 3,"method": "deepseek_mtp", "enforce_eager":true}' \
  --additional_config '{"enable_flashcomm1": true, "enable_cpu_binding": "True", "multistream_overlap_shared_expert": "True", "enable_dsa_cp":true,"eplb_config": {"dynamic_eplb": true,"expert_heat_collection_interval": 50, "algorithm_execution_interval": 5, "eplb_policy_type": 2,"num_redundant_experts": 0 }}'
