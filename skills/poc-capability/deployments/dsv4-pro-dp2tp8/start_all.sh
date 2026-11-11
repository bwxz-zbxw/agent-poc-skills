#!/usr/bin/env bash
# 由历史 POC 记录归纳；IP/NIC/权重路径已占位符化，运行前替换 <HOST_x> / <NIC> / <WEIGHTS_PATH>
node1：
export OMP_PROC_BIND=false
export OMP_NUM_THREADS=10
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True
export HCCL_BUFFSIZE=512
export ASCEND_RT_VISIBLE_DEVICES=0,1,2,3,4,5,6,7

nic_name="<NIC>"
local_ip="<HOST_A>"
export HCCL_IF_IP=$local_ip
export GLOO_SOCKET_IFNAME=$nic_name
export TP_SOCKET_IFNAME=$nic_name
export HCCL_SOCKET_IFNAME=$nic_name

export VLLM_ENGINE_READY_TIMEOUT_S=3600
export VLLM_RPC_TIMEOUT=3600000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=30000
export HCCL_EXEC_TIMEOUT=1800
export HCCL_CONNECT_TIMEOUT=1800

nohup vllm serve <WEIGHTS_PATH> \
  --host 0.0.0.0 \
  --port 8555 \
  --max_model_len 200000 \
  --safetensors-load-strategy 'prefetch' \
  --max-num-batched-tokens 8192 \
  --served-model-name dsv4_pro \
  --gpu-memory-utilization 0.94 \
  --enable-expert-parallel \
  --async-scheduling \
  --max-num-seqs 40 \
  --block-size 128 \
  --enable-prefix-caching \
  --api_server_count 1 \
  --tokenizer-mode deepseek_v4 \
  --tool-call-parser deepseek_v4 \
  --enable-auto-tool-choice \
  --reasoning-parser deepseek_v4 \
  --data-parallel-size 2 \
  --data-parallel-size-local 1 \
  --data-parallel-start-rank 0 \
  --data-parallel-address $local_ip \
  --data-parallel-rpc-port 6987 \
  --tensor-parallel-size 8 \
  --compilation-config '{"cudagraph_mode": "FULL_DECODE_ONLY", "cudagraph_capture_sizes":[8,16,24,32,40,48,64,80,96,112,128,144,160]}' \
  --speculative-config '{"num_speculative_tokens": 3, "method": "mtp","enforce_eager":true}' \
  --additional_config '{"enable_cpu_binding": "True", "multistream_overlap_shared_expert": true, "multistream_dsa_preprocess":false, "dp_allreduce_on_npu":false, "enable_flashcomm1": true, "enable_dsa_cp": true}' \
  > v4_pro_node1.log 2>&1 &
node2：
export OMP_PROC_BIND=false
export OMP_NUM_THREADS=10
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True
export HCCL_BUFFSIZE=512
export ASCEND_RT_VISIBLE_DEVICES=0,1,2,3,4,5,6,7

nic_name="<NIC>"
local_ip="<HOST_B>"
export HCCL_IF_IP=$local_ip
export GLOO_SOCKET_IFNAME=$nic_name
export TP_SOCKET_IFNAME=$nic_name
export HCCL_SOCKET_IFNAME=$nic_name

export VLLM_ENGINE_READY_TIMEOUT_S=3600
export VLLM_RPC_TIMEOUT=3600000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=30000
export HCCL_EXEC_TIMEOUT=1800
export HCCL_CONNECT_TIMEOUT=1800

nohup vllm serve <WEIGHTS_PATH> \
  --host 0.0.0.0 \
  --port 8555 \
  --headless \
  --max_model_len 200000 \
  --safetensors-load-strategy 'prefetch' \
  --max-num-batched-tokens 8192 \
  --served-model-name dsv4_pro \
  --gpu-memory-utilization 0.94 \
  --enable-expert-parallel \
  --async-scheduling \
  --max-num-seqs 40 \
  --block-size 128 \
  --tokenizer-mode deepseek_v4 \
  --tool-call-parser deepseek_v4 \
  --enable-auto-tool-choice \
  --reasoning-parser deepseek_v4 \
  --data-parallel-size 2 \
  --data-parallel-size-local 1 \
  --data-parallel-start-rank 1 \
  --data-parallel-address <HOST_A> \
  --data-parallel-rpc-port 6987 \
  --tensor-parallel-size 8 \
  --compilation-config '{"cudagraph_mode": "FULL_DECODE_ONLY", "cudagraph_capture_sizes":[8,16,24,32,40,48,64,80,96,112,128,144,160]}' \
  --speculative-config '{"num_speculative_tokens": 3, "method": "mtp","enforce_eager":true}' \
  --additional_config '{"enable_cpu_binding": "True", "multistream_overlap_shared_expert": true, "multistream_dsa_preprocess":false, "dp_allreduce_on_npu":false, "enable_flashcomm1": true, "enable_dsa_cp": true}' \
  > v4_pro_node2.log 2>&6 &
