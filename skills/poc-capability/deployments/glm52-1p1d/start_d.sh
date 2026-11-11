#!/usr/bin/env bash
source /root/.bashrc
export PROMETHEUS_MULTIPROC_DIR=/dev/shm/vllm_metrics && mkdir -p $PROMETHEUS_MULTIPROC_DIR
export HCCL_DFS_CONFIG="task_exception:off,inconsistent_check:off"
export VLLM_ASCEND_DP_ALLREDUCE_ON_NPU=1

unset ftp_proxy
unset https_proxy
unset http_proxy
unset HCCL_INTRA_ROCE_ENABLE

# 自动获取配置
nic_name=<NIC>
local_ip=<HOST_A>

# 以下环境变量无需修改
export HCCL_IF_IP=$local_ip
export GLOO_SOCKET_IFNAME=$nic_name
export TP_SOCKET_IFNAME=$nic_name
export HCCL_SOCKET_IFNAME=$nic_name

export HCCL_ALGO=level0:fullmesh

export VLLM_RPC_TIMEOUT=3600000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=30000
export HCCL_EXEC_TIMEOUT=200
export HCCL_CONNECT_TIMEOUT=1800
export HCCL_BUFFSIZE=1200

export OMP_PROC_BIND=false
export OMP_NUM_THREADS=10
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True

export ASCEND_RT_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
export TASK_QUEUE_ENABLE=1

export DYNAMIC_EPLB="true"
#export EXPERT_MAP_RECORD="true"


vllm serve <WEIGHTS_PATH> \
  --host $local_ip \
  --port 9988 \
  --data-parallel-size 8 \
  --data-parallel-address $local_ip \
  --data-parallel-rpc-port 12321 \
  --tensor-parallel-size 1 \
  --max_model_len 202752  \
  --max-num-batched-tokens 240 \
  --served-model-name glm52 \
  --gpu-memory-utilization 0.95 \
  --enable-expert-parallel \
  --async-scheduling \
  --max-num-seqs 60 \
  --enable-prefix-caching \
  --trust-remote-code \
  --compilation-config '{"cudagraph_mode": "FULL_DECODE_ONLY"}' \
  --speculative-config '{"num_speculative_tokens": 3,"method": "deepseek_mtp", "enforce_eager":true}' \
  --hf-overrides '{"use_index_cache": true, "index_topk_freq": 4}' \
  --quantization ascend \
  --enable-auto-tool-choice \
  --tool-call-parser glm47 \
  --reasoning-parser glm45 \
  --kv-transfer-config \
    '{"kv_connector": "MooncakeConnectorV1",
    "kv_role": "kv_consumer",
    "kv_port": "30300",
    "engine_id": "3",
    "kv_connector_extra_config": {
                "prefill": {
                        "dp_size": 1,
                        "tp_size": 8
                },
                "decode": {
                        "dp_size": 8,
                        "tp_size": 1
                },
                "ascend_local_comm_res_path": "/etc/hixlep"
        }
    }' \
  --additional_config '{"enable_cpu_binding": "True", "recompute_scheduler_enable": "True", "multistream_overlap_shared_expert": "True", "enable_sparse_sfa_c8": true, "enable_sparse_li_c8": true, "finegrained_tp_config": {"lmhead_tensor_parallel_size":8}}' \
  2>&1 | tee glm52_d.log

proxy：
python3 load_balance_proxy_server_example.py \
  --port 4999 \
  --host 127.0.0.1 \
  --prefiller-hosts \
    <HOST_B> \
  --prefiller-ports \
    9888 \
  --decoder-hosts \
    <HOST_A>  \
  --decoder-ports \
    9988 \
