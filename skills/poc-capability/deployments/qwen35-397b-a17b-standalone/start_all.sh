#!/usr/bin/env bash
# 由历史 POC 记录归纳；IP/NIC/权重路径已占位符化，运行前替换 <HOST_x> / <NIC> / <WEIGHTS_PATH>
export ASCEND_RT_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
export PYTORCH_NPU_ALLOC_CONF="expandable_segments:True"
export OMP_NUM_THREADS=10
export TASK_QUEUE_ENABLE=1
export HCCL_OP_EXPANSION_MODE="AIV"
export VLLM_ASCEND_ENABLE_FLASHCOMM1=1
export HCCL_BUFFSIZE=3072

vllm serve <WEIGHTS_PATH> \
--host 0.0.0.0 \
--port 8010 \
--quantization ascend \
--served-model-name qwen35 \
--data-parallel-size 4 \
--tensor-parallel-size 2 \
--enable-expert-parallel \
--max-num-seqs 64 \
--max-model-len 262144 \
--max-num-batched-tokens 8192 \
--gpu-memory-utilization 0.9 \
--trust-remote-code \
--additional-config '{"enable_cpu_binding":true,"enable_balance_scheduling":true,"enable_flashcomm1":true,"enable_fused_mc2":1}' \
--enable-prefix-caching \
--mm-processor-cache-gb 0 \
--async-scheduling \
--default-chat-template-kwargs '{"enable_thinking": false}' \
--reasoning-parser qwen3 \
--speculative-config '{"method":"qwen3_5_mtp","num_speculative_tokens":5,"enforce_eager": true}' \
--compilation-config '{"cudagraph_mode":"FULL_DECODE_ONLY"}'
