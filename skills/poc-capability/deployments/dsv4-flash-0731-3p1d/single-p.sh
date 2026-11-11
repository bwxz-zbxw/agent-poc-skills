source /root/.bashrc
export PATH=/usr/local/python3.12.13/bin:$PATH
unset LD_PRELOAD

unset ftp_proxy
unset https_proxy
unset http_proxy
unset HCCL_INTRA_ROCE_ENABLE

# 自动获取配置
nic_name="<NIC>"
local_ip="<HOST_32>"

#nic_name=<NIC>
#local_ip=<HOST_EXT>

node0_ip="<HOST_32>"

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
# export ASCEND_LOCAL_COMM_RES_PATH=/etc/hixlep/

export OMP_PROC_BIND=false
export OMP_NUM_THREADS=10
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True

export TASK_QUEUE_ENABLE=1

export ASCEND_RT_VISIBLE_DEVICES=0,1,2,3
export ASCEND_LOCAL_COMM_RES='{"version":"1.3"}'


vllm serve <WEIGHTS_PATH> \
  --host $local_ip \
  --port 9000 \
  --data-parallel-size 4 \
  --data-parallel-address $local_ip \
  --data-parallel-rpc-port 12321 \
  --tensor-parallel-size 1 \
  --max_model_len 1048576 \
  --max-num-batched-tokens 8192 \
  --served-model-name dsv4_0905 \
  --gpu-memory-utilization 0.85 \
  --enable-expert-parallel \
  --async-scheduling \
  --max-num-seqs 8 \
  --block-size 32 \
  --enable-prefix-caching \
  --api_server_count 1 \
  --tokenizer-mode deepseek_v4 \
  --tool-call-parser deepseek_v4 \
  --enable-auto-tool-choice \
  --reasoning-parser deepseek_v4 \
  --trust-remote-code \
  --enforce-eager \
  --no-disable-hybrid-kv-cache-manager \
  --speculative-config '{"method":"dspark","num_speculative_tokens":5,"enforce_eager":true}' \
  --kv-transfer-config  \
    '{"kv_connector": "MooncakeHybridConnector",
    "kv_role": "kv_producer",
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
  --additional_config '{"enable_cpu_binding": "True", "multistream_overlap_shared_expert": true, "ascend_compilation_config":{"enable_npugraph_ex":true,"enable_static_kernel":true}}'