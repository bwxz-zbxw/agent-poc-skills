#!/usr/bin/env bash
# $1=ASCEND_RT_VISIBLE_DEVICES $2=端口 $3=dp_size $4=dp_rank $5=dp_address $6=dp_rpc_port $7=tp_size $8=pp_size

unset ftp_proxy https_proxy http_proxy all_proxy
unset FTP_PROXY HTTPS_PROXY HTTP_PROXY ALL_PROXY
pkill -9 VLLM
pkill -9 vllm
pkill -9 python

nic_name="<NIC>"
local_ip="<HOST_A>"

model_path="<WEIGHTS_PATH>"
EAGLE3_WEIGHT_PATH="<WEIGHTS_PATH>"

export HCCL_BUFFSIZE=256
export HCCL_IF_IP=$local_ip
export HCCL_OP_EXPANSION_MODE="AIV"
export ASCEND_RT_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
export HCCL_SOCKET_IFNAME=$nic_name
export GLOO_SOCKET_IFNAME=$nic_name
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True
export ASCEND_LOCAL_COMM_RES='{"version":"1.3"}'
export VLLM_RPC_TIMEOUT=3600000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=30000
export HCCL_EXEC_TIMEOUT=204
export HCCL_CONNECT_TIMEOUT=180

# Mooncake 库:本镜像装在 python site-packages(文档默认的 toolkit 路径不存在,动态探测)
MOONCAKE_PY_DIR=$(python -c "import mooncake, os; print(os.path.dirname(mooncake.__file__))" 2>/dev/null || true)
export LD_LIBRARY_PATH=/usr/local/Ascend/ascend-toolkit/latest/lib64:${MOONCAKE_PY_DIR:+$MOONCAKE_PY_DIR:}$LD_LIBRARY_PATH

vllm serve "$model_path" \
    --host 0.0.0.0 \
    --port 31050 \
    --data-parallel-size 2 \
    --tensor-parallel-size 4 \
    --served-model-name minimax-m3 \
    --trust-remote-code \
    --dtype bfloat16 \
    --max-num-seqs 128 \
    --max-num-batched-tokens 32768 \
    --max-model-len 136000 \
    --enable-expert-parallel \
    --quantization mxfp8 \
    --gpu-memory-utilization 0.95 \
    --distributed-executor-backend mp \
    --kv-cache-dtype fp8 \
    --reasoning-parser minimax_m3 \
    --safetensors-load-strategy prefetch \
    --speculative-config '{"method":"eagle3","model":"'"${EAGLE3_WEIGHT_PATH}"'","num_speculative_tokens":3,"kv_cache_dtype":"bfloat16"}' \
    --enforce-eager \
    --enable-chunked-prefill \
    --enable-prefix-caching \
    --no-async-scheduling \
    --additional-config '{"enable_cpu_binding":true,"ascend_compilation_config":{"fuse_qknorm_rope":true,"fuse_norm_quant":true},"multistream_overlap_shared_expert":true,"enable_shared_expert_dp":true}' \
    --kv-transfer-config \
    '{
        "kv_connector":"MooncakeConnectorV1",
        "kv_role":"kv_producer",
        "kv_port":"30000",
        "engine_id":"0",
        "kv_connector_extra_config":{
            "use_ascend_direct":true,
            "prefill":{"dp_size":2,"tp_size":4},
            "decode":{"dp_size":2,"tp_size":4}
        }
    }' \
    2>&1 | tee p.log
