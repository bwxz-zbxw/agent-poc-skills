#!/usr/bin/env bash
# 由历史 POC 记录归纳；IP/NIC/权重路径已占位符化，运行前替换 <HOST_x> / <NIC> / <WEIGHTS_PATH>
# Load model from ModelScope to speed up download
export ASCEND_RT_VISIBLE_DEVICES=$1
port_=23161
echo "port:" $port_
export PYTORCH_NPU_ALLOC_CONF="expandable_segments:True"

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lilb64
export VLLM_DISABLE_COMPILE_CACHE=1

export OMP_NUM_THREADS=1
# echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
# sysctl -w vm.swappiness=0
# sysctl -w kernel.numa_balancing=0
# sysctl kernal.sched_migration_cost_ns=50000
export TASK_QUEUE_ENABLE=1

export ASCEND_RT_VISIBLE_DEVICES=0

export HCCL_IF_IP="127.0.0.1"
export HCCL_OP_EXPANSION_MODE="AIV"
export HCCL_BUFFSIZE=1024

# 启动prefix-caching的话将--no-enable-prefix-caching改成 --enable-prefix-caching 

nohup vllm serve <WEIGHTS_PATH> \
    --host 0.0.0.0 \
    --port $port_ \
    --data-parallel-size 1 \
    --tensor-parallel-size 1 \
    --served-model-name qwen3.6 \
    --max-num-seqs 32 \
    --max-model-len 262144 \
    --max-num-batched-tokens 16384 \
    --trust-remote-code \
    --no-enable-prefix-caching \
    --quantization ascend \
    --gpu-memory-utilization 0.95 \
    --async-scheduling \
    --speculative-config '{"method": "qwen3_5_mtp", "num_speculative_tokens": 3, "enforce_eager": true}' \
    --compilation-config '{"cudagraph_mode":"FULL_DECODE_ONLY"}' \
    --additional-config '{"enable_cpu_binding":true}' \
    > serve_1n_nopc.log 2>&1 &
