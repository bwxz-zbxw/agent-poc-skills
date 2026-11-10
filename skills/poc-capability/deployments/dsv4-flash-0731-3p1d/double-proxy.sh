unset ftp_proxy
unset https_proxy
unset http_proxy

# proxy
python3 load_balance_proxy_server_example.py \
  --port 14258 \
  --host 0.0.0.0 \
  --prefiller-hosts \
    <HOST_32> \
    <HOST_32> \
    <HOST_31> \
  --prefiller-ports \
    9000 9001 9000\
  --decoder-hosts <HOST_31> \
  --decoder-ports 9001
