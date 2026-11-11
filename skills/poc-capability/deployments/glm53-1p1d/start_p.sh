#!/usr/bin/env bash
# 清除代理环境变量
unset ftp_proxy FTP_PROXY
unset https_proxy HTTPS_PROXY
unset http_proxy HTTP_PROXY
source /root/.bashrc
export HCCL_DFS_CONFIG="task_exception:off,inconsistent_check:off"
unset ftp_proxy
unset https_proxy
unset http_proxy
unset HCCL_INTRA_ROCE_ENABLE

# 自动获取配置
nic_name="<NIC>"
local_ip="<HOST_A>"

# 以下环境变量无需修改
export HCCL_IF_IP=$local_ip
export GLOO_SOCKET_IFNAME=$nic_name
export TP_SOCKET_IFNAME=$nic_name
export HCCL_SOCKET_IFNAME=$nic_name

export ASCEND_LOCAL_COMM_RES='{"version":"1.3"}'
export HCCL_ALGO=level0:fullmesh

export VLLM_RPC_TIMEOUT=3600000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=30000
export HCCL_EXEC_TIMEOUT=204
export HCCL_CONNECT_TIMEOUT=180
export HCCL_BUFFSIZE=300
export VLLM_ASCEND_ENABLE_FLASHCOMM1=1
export VLLM_USE_FASTOKENS=1
export OMP_PROC_BIND=false
export OMP_NUM_THREADS=10
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True

export TASK_QUEUE_ENABLE=1

export DYNAMIC_EPLB="true"

vllm serve <WEIGHTS_PATH> \
  --host <HOST_A> \
  --port 8010 \
  --data-parallel-size 1 \
  --tensor-parallel-size 8 \
  --max_model_len 262144 \
  --max-num-batched-tokens 16384 \
  --served-model-name glm25 \
  --gpu-memory-utilization 0.95 \
  --enable-expert-parallel \
  --async-scheduling \
  --max-num-seqs 16 \
  --enable-prefix-caching \
  --trust-remote-code \
  --enforce-eager \
  --quantization ascend \
  --enable-auto-tool-choice \
  --tool-call-parser glm47 \
  --reasoning-parser glm45 \
  --speculative-config '{"num_speculative_tokens": 3,"method": "deepseek_mtp", "enforce_eager":true}' \
  --hf-overrides '{"use_index_cache": true, "index_topk_freq": 4}' \
  --kv-transfer-config \
    '{"kv_connector": "MooncakeConnectorV1",
    "kv_role": "kv_producer",
    "kv_port": "30100",
    "engine_id": "1",
    "kv_connector_extra_config": {
                "prefill": {
                        "dp_size": 1,
                        "tp_size": 8
                },
                "decode": {
                        "dp_size": 8,
                        "tp_size": 1
                }
        }
    }' \
  --kv-cache-dtype fp8 \
  --attention_config.indexer_kv_dtype fp8 \
  --additional_config '{"enable_cpu_binding": "True", "multistream_overlap_shared_expert": "True", "recompute_scheduler_enable": "True", "enable_dsa_cp": true, "enable_flashcomm1": true, "enable_fused_mc2": 1}'
