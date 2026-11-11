#!/usr/bin/env bash
# 由历史 POC 记录归纳；IP/NIC/权重路径已占位符化，运行前替换 <HOST_x> / <NIC> / <WEIGHTS_PATH>
set -o pipefail
source /root/.bashrc
export VLLM_USE_V2_MODEL_RUNNER=0
unset LD_PRELOAD

unset ftp_proxy
unset https_proxy
unset http_proxy
unset HCCL_INTRA_ROCE_ENABLE
# 自动获取配置
nic_name=<NIC>
local_ip=<HOST_A>
#export VLLM_VERSION=v0.27.1

# 以下环境变量无需修改
export HCCL_IF_IP=$local_ip
export GLOO_SOCKET_IFNAME=$nic_name
export TP_SOCKET_IFNAME=$nic_name
export HCCL_SOCKET_IFNAME=$nic_name

export HCCL_ALGO=level0:fullmesh

export VLLM_RPC_TIMEOUT=3600000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=30000
export HCCL_EXEC_TIMEOUT=2040
export HCCL_CONNECT_TIMEOUT=1200
export HCCL_BUFFSIZE=1024
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
export ASCEND_LOCAL_COMM_RES_PATH='{"version":"1.3"}'

export OMP_PROC_BIND=false
export OMP_NUM_THREADS=10
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True

export TASK_QUEUE_ENABLE=1

export ASCEND_RT_VISIBLE_DEVICES=0,1,2,3,4,5,6,7

printf "[launcher] LD_PRELOAD=%s MRV2=%s\n" "${LD_PRELOAD-unset}" "$VLLM_USE_V2_MODEL_RUNNER"
vllm serve <WEIGHTS_PATH> \
  --host $local_ip \
  --port 9001 \
  --tensor-parallel-size 8 \
  --max-num-batched-tokens 8192 \
  --served-model-name dsv4 \
  --gpu-memory-utilization 0.92 \
  --async-scheduling \
  --max-num-seqs 64 \
  --block-size 128 \
  --no-enable-prefix-caching \
  --tokenizer-mode deepseek_v4 \
  --tool-call-parser deepseek_v4 \
  --enable-auto-tool-choice \
  --enable-expert-parallel \
  --reasoning-parser deepseek_v4 \
  --trust-remote-code \
  --no-disable-hybrid-kv-cache-manager \
  --max_model_len 1048576 \
  --kv-cache-dtype fp8 \
  --attention_config.indexer_kv_dtype fp8 \
  --speculative-config '{"method":"dspark","num_speculative_tokens":5,"enforce_eager":true}' \
  --compilation-config '{"cudagraph_mode": "FULL_DECODE_ONLY"}' \
  --additional_config '{"enable_cpu_binding": true, "multistream_overlap_shared_expert": true, "enable_dsa_cp": true}' \
  2>&1 | tee ./logs/tp8-dsacp-c8-dspark-$(date +%Y%m%d_%H%M%S).log
