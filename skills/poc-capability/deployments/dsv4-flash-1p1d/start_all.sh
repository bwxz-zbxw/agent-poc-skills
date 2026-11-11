#!/usr/bin/env bash
# 由历史 POC 记录归纳；IP/NIC/权重路径已占位符化，运行前替换 <HOST_x> / <NIC> / <WEIGHTS_PATH>
D脚本：

# D实例：
# 注意 local_ip、master_ip、ASCEND_RT_VISIBLE_DEVICES、port配置
source /root/.bashrc
export VLLM_USE_V2_MODEL_RUNNER=0

unset ftp_proxy
unset https_proxy
unset http_proxy
unset HCCL_INTRA_ROCE_ENABLE

# 自动获取配置
nic_name=<NIC>
local_ip=<HOST_A>

#nic_name=<NIC>
#local_ip=<HOST_B>

master_ip=<HOST_A>

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
export HCCL_BUFFSIZE=4096
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
export ASCEND_LOCAL_COMM_RES_PATH=/etc/hixlep/

export OMP_PROC_BIND=false
export OMP_NUM_THREADS=10
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True

export TASK_QUEUE_ENABLE=1

export ASCEND_RT_VISIBLE_DEVICES=4,5,6,7


vllm serve <WEIGHTS_PATH> \
  --host $local_ip \
  --port 9001 \
  --data-parallel-size 4 \
  --data-parallel-address $local_ip \
  --data-parallel-rpc-port 12321 \
  --tensor-parallel-size 1 \
  --max_model_len 1048576 \
  --max-num-batched-tokens 256 \
  --served-model-name dsv \
  --gpu-memory-utilization 0.92 \
  --enable-expert-parallel \
  --async-scheduling \
  --max-num-seqs 64 \
  --block-size 128 \
  --no-enable-prefix-caching \
  --api_server_count 1 \
  --tokenizer-mode deepseek_v4 \
  --tool-call-parser deepseek_v4 \
  --enable-auto-tool-choice \
  --reasoning-parser deepseek_v4 \
  --trust-remote-code \
  --compilation-config '{"cudagraph_mode": "FULL_DECODE_ONLY"}' \
  --no-disable-hybrid-kv-cache-manager \
  --speculative-config '{"num_speculative_tokens":2,"method": "mtp", "enforce_eager": false}' \
  --kv-transfer-config \
  '{"kv_connector": "MooncakeHybridConnector",
  "kv_role": "kv_consumer",
  "kv_port": "36010",
  "engine_id": "1",
  "kv_connector_extra_config": {
            "prefill": {
                    "dp_size": 4,
                    "tp_size": 1
             },
             "decode": {
                    "dp_size": 4,
                    "tp_size": 1
             }
      }
  }' \
  --additional_config '{"enable_cpu_binding": "True", "recompute_scheduler_enable":true, "multistream_overlap_shared_expert": true}' \
  --default-chat-template-kwargs '{"thinking":false,"enable_thinking":false}' \
  --profiler-config '{"profiler": "torch", "torch_profiler_dir": "./dsv4_profile_decoder", "torch_profiler_with_stack": false}'



P脚本：

# P节点：
# 注意 local_ip、master_ip、ASCEND_RT_VISIBLE_DEVICES、port配置
source /root/.bashrc
export VLLM_USE_V2_MODEL_RUNNER=0

unset ftp_proxy
unset https_proxy
unset http_proxy
unset HCCL_INTRA_ROCE_ENABLE

# 自动获取配置
nic_name=<NIC>
local_ip=<HOST_A>

#nic_name=<NIC>
#local_ip=<HOST_B>

master_ip=<HOST_C>

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
export ASCEND_LOCAL_COMM_RES_PATH=/etc/hixlep/
export ASCEND_LOCAL_COMM_RES='{"version":"1.3"}'
export OMP_PROC_BIND=false
export OMP_NUM_THREADS=10
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True

export TASK_QUEUE_ENABLE=1

export ASCEND_RT_VISIBLE_DEVICES=0,1,2,3


vllm serve <WEIGHTS_PATH> \
  --host $local_ip \
  --port 9000 \
  --data-parallel-size 4 \
  --data-parallel-address $local_ip \
  --data-parallel-rpc-port 12321 \
  --tensor-parallel-size 1 \
  --max_model_len 1048576 \
  --max-num-batched-tokens 8192 \
  --served-model-name dsv \
  --gpu-memory-utilization 0.85 \
  --enable-expert-parallel \
  --async-scheduling \
  --max-num-seqs 8 \
  --block-size 128 \
  --enable-prefix-caching \
  --api_server_count 1 \
  --tokenizer-mode deepseek_v4 \
  --tool-call-parser deepseek_v4 \
  --enable-auto-tool-choice \
  --reasoning-parser deepseek_v4 \
  --trust-remote-code \
  --enforce-eager \
  --no-disable-hybrid-kv-cache-manager \
  --speculative-config '{"num_speculative_tokens": 1,"method": "mtp", "enforce_eager": false}' \
  --kv-transfer-config \
  '{"kv_connector": "MooncakeHybridConnector",
  "kv_role": "kv_producer",
  "kv_port": "36010",
  "engine_id": "1",
  "kv_connector_extra_config": {
            "prefill": {
                    "dp_size": 4,
                    "tp_size": 1
             },
             "decode": {
                    "dp_size": 4,
                    "tp_size": 1
             }
      }
  }' \
  --additional_config '{"enable_cpu_binding": "True", "multistream_overlap_shared_expert": true}' \
  --enable-prefix-caching \
  --profiler-config '{"profiler": "torch", "torch_profiler_dir": "./dsv4_profile", "torch_profiler_with_stack": false}' \
  --default-chat-template-kwargs '{"thinking":false,"enable_thinking":false}'


Proxy脚本：
unset http_proxy
unset https_proxy
node_p0_ip="<HOST_A>"
node_d0_ip="<HOST_A>"

python <USER_PATH> \
    --port 2999 \
    --host 0.0.0.0 \
    --prefiller-hosts \
      $node_p0_ip \
    --prefiller-ports \
      9000 \
    --decoder-hosts \
      $node_d0_ip \
    --decoder-ports \
      9001



Aisbench config.py:
# 数据集文件夹路径，需可访问(请使用绝对路径)
DATASET_PATH = "<USER_PATH>"

# aisbench 工作路径, 为 git clone aisbench 后得到的 benchmark 目录的绝对路径
# 可通过命令 `pip show ais-bench-benchmark` 查询location
WORK_PATH = "/usr/local/python3.11.10/lib/python3.11/site-packages"

# 服务化配置的模型名称
MODEL_NAME = "dsv"
# 模型权重路径, 用于读取 tokenizer
MODEL_PATH = "<WEIGHTS_PATH>"
# 请求目的 IP
HOST_IP = "<HOST_B>"
# 请求目的端口
HOST_PORT = "2999"

## 鉴权信息
API_KEY = ""

# 如果使用稳态测试请将该字段设置为 "stable_stage"
DEFAULT_PERFORMANCE_TEST = "default_perf"

# aisbench输出日志保存路径
OUTPUT_DIR = "./outputs/default"

# 各节点信息，格式为 ["{ip}:{port}"]
# 用于查询vllm metrics计算各个dp域的prefix cache命中率，不配置默认为HOST_IP:HOST_PORT
# PD分离场景请填写各个P节点的IP和对应dp域的port
# POD_INFO = ["141.xx.xx.11:8000","141.xx.xx.12:8000"]
POD_INFO = ["<HOST_B>:9005"]
