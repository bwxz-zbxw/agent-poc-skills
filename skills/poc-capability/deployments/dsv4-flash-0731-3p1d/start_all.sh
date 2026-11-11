#!/usr/bin/env bash
# ============================================================
# DeepSeek-V4-Flash-0731 · 3P1D（双机 16 卡：P1/P2 同机，P3/D 同机）
# ------------------------------------------------------------
# 本目录是早期人工整理的部署目录，P/D 脚本已按角色拆好：
#   single-p.sh   -> P1（<HOST_32>:9000，kv_producer，engine_id=1）
#   single-p2.sh  -> P2（<HOST_32>:9001，kv_producer，engine_id=2）
#   single-p3.sh  -> P3（<HOST_31>:9000，kv_producer，engine_id=1）
#   single-d.sh   -> D （<HOST_31>:9001，kv_consumer，engine_id=1）
#   double-proxy.sh -> 前置代理（对外 14258）
#
# 用法（先替换 <HOST_31>/<HOST_32>/<NIC>/<WEIGHTS_PATH>/<HOST_EXT>）：
#   机器A: bash single-p.sh  ;  bash single-p3.sh ; bash single-d.sh
#   机器B: bash single-p2.sh ;  bash single-p.sh
#   代理 : bash double-proxy.sh
# 完整参数与拓扑见同目录 deploy.yaml。
# ============================================================
set -euo pipefail

cat <<'EOF'
本脚本仅作启动入口说明，不自动拉起 4 个实例。

请按 deploy.yaml 的 topology 顺序，在对应机器上分别执行：
  P1: ./single-p.sh
  P2: ./single-p2.sh
  P3: ./single-p3.sh
  D : ./single-d.sh
  代理: ./double-proxy.sh   (对外端口 14258)

注意：
  1. 先启动 P1/P2/P3 与 D，确认 KV 通道就绪后再起代理。
  2. <HOST_31>/<HOST_32>/<NIC>/<WEIGHTS_PATH> 需替换为本机真实值。
EOF
