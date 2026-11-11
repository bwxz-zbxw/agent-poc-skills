#!/usr/bin/env bash
# P：DP8/TP1/EP8
# local_ip=<HOST_A>
# local_ifname=<NIC>
pkill -9 VLLM
pkill -9 vllm
pkill -9 python

local_ip=<HOST_B>
local_ifname=<NIC>
export ASCEND_RT_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
export VLLM_RPC_TIMEOUT=3600000
export GLOO_SOCKET_IFNAME=$local_ifname
export TP_SOCKET_IFNAME=$local_ifname
export HCCL_SOCKET_IFNAME=$local_ifname
export HCCL_CONNECT_TIMEOUT=1200
export HCCL_DETERMINISTIC=true
export HCCL_OP_EXPANSION_MODE=CCU_SCHED
export ASCEND_LOCAL_COMM_RES='{"version":"1.3"}'
export OMP_PROC_BIND=false
export OMP_NUM_THREADS=10
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True

aicpu_headers=/usr/local/Ascend/cann-9.2.0/tools/hcc/aarch64-target-linux-gnu/include/c++/14.3.0
export CPLUS_INCLUDE_PATH="$aicpu_headers:$aicpu_headers/aarch64-target-linux-gnu:$aicpu_headers/backward"
export VLLM_USE_V2_MODEL_RUNNER=1
export VLLM_HOST_IP=$local_ip
export HCCL_IF_IP=$local_ip
export HCCL_BUFFSIZE=1600
exec vllm serve <WEIGHTS_PATH> \
  --served-model-name dsv41 \
  --host 0.0.0.0 \
  --port 8367 \
  --api-server-count 1 \
  --data-parallel-size 8 \
  --data-parallel-rpc-port 16971 \
  --tensor-parallel-size 1 \
  --enable-expert-parallel \
  --enable-ep-weight-filter \
  --seed 1024 \
  --max-model-len 1048576 \
  --max-num-batched-tokens 4096 \
  --max-num-seqs 64 \
  --block-size 128 \
  --enable-prefix-caching \
  --model-loader-extra-config '{"enable_multithread_load":true,"num_threads":128}' \
  --trust-remote-code \
  --engram-config '{"cpu_offload":true,"dp_shared_memory":true}' \
  --tokenizer-mode deepseek_v41 \
  --reasoning-parser deepseek_v41 \
  --tool-call-parser deepseek_v41 \
  --enable-auto-tool-choice \
  --gpu-memory-utilization 0.90 \
  --quantization deepseek_v4_fp8 \
  --async-scheduling \
  --speculative-config '{"method":"dspark","num_speculative_tokens":5,"enforce_eager":true}' \
  --enforce-eager \
  --kv-transfer-config '{"kv_connector":"MooncakeHybridConnector","kv_role":"kv_producer","kv_port":21860,"engine_id":"dsv41-17-p","kv_connector_extra_config":{"prefill":{"dp_size":8,"tp_size":1},"decode":{"dp_size":8,"tp_size":1}}}' \
  --additional-config '{"multistream_engram_overlap":false,"enable_cpu_binding":true,"multistream_overlap_shared_expert":true,"multistream_dsv4_dsa_overlap":true,"enable_fused_mc2":0,"enable_force_eplb":false}' \
2>&1 | tee p.log
