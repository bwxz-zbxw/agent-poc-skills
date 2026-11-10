IMAGES_ID=$1
NAME=$2
if [ $# -ne 2 ]; then
	echo "error: need one argument describing your container name."
	exit 1
fi

docker run -u root -it -d \
    --name ${NAME} \
    --shm-size="80g" \
    --net=host \
    --pid=host \
    --privileged=true \
    --device /dev/davinci0 \
    --device /dev/davinci1 \
    --device /dev/davinci2 \
    --device /dev/davinci3 \
    --device /dev/davinci4 \
    --device /dev/davinci5 \
    --device /dev/davinci6 \
    --device /dev/davinci7 \
    --device /dev/davinci_manager \
    --device /dev/hisi_hdc \
    --device /dev/ummu \
    --device /dev/uburma \
    -v /root/host:/root/host \
    -v /usr/local/sbin/npu-smi:/usr/local/sbin/npu-smi \
    -v /etc/ascend_install.info:/etc/ascend_install.info \
    -v /usr/local/sbin:/usr/local/sbin \
    -v /usr/local/dcmi:/usr/local/dcmi \
    -v /var/log/npu:/usr/log/ \
    -v /mnt:/mnt \
    -v /etc/hccl_rootinfo.json:/etc/hccl_rootinfo.json \
    -v /lib/route.conf:/lib/route.conf \
    -v /root/.cache:/root/.cache \
    -v /usr/local/Ascend/driver/tools/hccn_tool:/usr/local/Ascend/driver/tools/hccn_tool \
    -v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi \
    -v /usr/bin/urma_admin:/usr/bin/urma_admin \
    -v /usr/local/Ascend/driver/lib64/:/usr/local/Ascend/driver/lib64/ \
    -v /usr/local/Ascend/driver/version.info:/usr/local/Ascend/driver/version.info \
    -v /usr/local/Ascend/driver:/usr/local/Ascend/driver \
    -v /etc/hccn.conf:/etc/hccn.conf \
    -v /home:/home \
    -v /etc/hixlep:/etc/hixlep \
    -w /home \
    ${IMAGES_ID} \
    bash