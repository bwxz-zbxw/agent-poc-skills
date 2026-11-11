#!/usr/bin/env bash
source /root/.bashrc
unset ftp_proxy
unset https_proxy
unset http_proxy
unset HCCL_INTRA_ROCE_ENABLE
export PROMETHEUS_MULTIPROC_DIR=/dev/shm/vllm_metrics && mkdir -p $PROMETHEUS_MULTIPROC_DIR
export HCCL_DFS_CONFIG="task_exception:off,inconsistent_check:off"
# 自动获取配置
# nic_name=<NIC>
# local_ip=<HOST_A>
nic_name=<NIC>
local_ip=<HOST_B>
export VLLM_VERSION=v0.27.1
# 以下环境变量无需修改
export HCCL_IF_IP=$local_ip
export GLOO_SOCKET_IFNAME=$nic_name
export TP_SOCKET_IFNAME=$nic_name
export HCCL_SOCKET_IFNAME=$nic_name
export HCCL_ALGO=level0:fullmesh
export ASCEND_LOCAL_COMM_RES='{"version":"1.3"}'
export VLLM_RPC_TIMEOUT=3600000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=30000
export HCCL_EXEC_TIMEOUT=2040
export HCCL_CONNECT_TIMEOUT=1200
export HCCL_BUFFSIZE=1024
# export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
# export ASCEND_LOCAL_COMM_RES_PATH=/etc/hixlep/
export OMP_PROC_BIND=false
export OMP_NUM_THREADS=10
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True
export TASK_QUEUE_ENABLE=1
export ASCEND_RT_VISIBLE_DEVICES=0,1,2,3
export DYNAMIC_EPLB="true"
# "ascend_local_comm_res_path": "/etc/hixlep"
vllm serve <WEIGHTS_PATH> \
  --host $local_ip \
  --port 9001 \
  --data-parallel-size 4 \
  --data-parallel-address $local_ip \
  --data-parallel-rpc-port 12325 \
  --tensor-parallel-size 1 \
  --max_model_len 1048576 \
  --max-num-batched-tokens 4096 \
  --served-model-name dsv \
  --gpu-memory-utilization 0.92 \
  --enable-expert-parallel \
  --async-scheduling \
  --max-num-seqs 64 \
  --block-size 32 \
  --no-enable-prefix-caching \
  --api_server_count 1 \
  --tokenizer-mode deepseek_v4 \
  --tool-call-parser deepseek_v4 \
  --enable-auto-tool-choice \
  --reasoning-parser deepseek_v4 \
  --trust-remote-code \
  --compilation-config '{"cudagraph_mode": "FULL_DECODE_ONLY"}' \
  --no-disable-hybrid-kv-cache-manager \
  --speculative-config '{"method":"dspark","num_speculative_tokens":5,"enforce_eager":true}' \
  --profiler-config '{"profiler": "torch", "torch_profiler_dir": "<WEIGHTS_PATH>", "torch_profiler_with_stack": false}' \
  --kv-transfer-config  \
    '{"kv_connector": "MooncakeHybridConnector",
    "kv_role": "kv_consumer",
    "kv_port": "30100",
    "engine_id": "1",
    "kv_connector_extra_config": {
                "use_ascend_direct": true,
                "prefill": {
                        "dp_size": 4,
                        "tp_size": 1
                },
                "decode": {
                        "dp_size": 4,
                        "tp_size": 1
                }
        }
    }'  \
  --additional_config '{"enable_cpu_binding": "True", "recompute_scheduler_enable":true, "multistream_overlap_shared_expert": true}' \
  2>&1 | tee v4_flash_d_$(date +%Y%m%d_%H%M%S).log
