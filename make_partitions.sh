#!/bin/bash

set -ex

IMAGE_FILE="$1"
DEFAULT_OPTS="-a 2"
SGDISK="sgdisk $DEFAULT_OPTS"

rm -f "$IMAGE_FILE"
fallocate -l 16G "$IMAGE_FILE"

LOOP_DEVICE=$(losetup -f "$IMAGE_FILE" -b 4096 --show)

get_partition_by_name() {
    sgdisk -p $LOOP_DEVICE | sed -n '/Number/,$p' | awk "\$7 == \"$1\""| awk "{print \"$LOOP_DEVICE\"\"p\"\$1}"
}

trap "losetup -d $LOOP_DEVICE" EXIT

$SGDISK -Z $LOOP_DEVICE

# Disable ones we don't need
$SGDISK -n 0:0:+8K -t 0:2C86E742-745E-4FDD-BFD8-B6A7AC638772 -c 0:"ssd" $LOOP_DEVICE
$SGDISK -n 0:0:+1M -t 0:97745ABA-135A-44C3-9ADC-05616173C25C -c 0:"nvdata1" $LOOP_DEVICE
$SGDISK -n 0:0:+1M -t 0:97745ABA-135A-44C3-9ADC-05616173C26A -c 0:"nvdata2" $LOOP_DEVICE
$SGDISK -n 0:0:+32M -t 0:6C95E238-E343-4BA8-B489-8681ED22AD0B -c 0:"persist" $LOOP_DEVICE
$SGDISK -n 0:0:+1M -t 0:82ACC91F-357C-4A68-9C8F-689E1B1A23A1 -c 0:"misc" $LOOP_DEVICE
$SGDISK -n 0:0:+512K -t 0:DE7D4029-0F5B-41C8-AE7E-F6C023A02B33 -c 0:"keystore" $LOOP_DEVICE
$SGDISK -n 0:0:+512K -t 0:91B72D4D-71E0-4CBF-9B8E-236381CFF17A -c 0:"frp" $LOOP_DEVICE
$SGDISK -n 0:0:+512K -t 0:76C931C2-001A-4945-9035-E98F2F3327F7 -c 0:"art" $LOOP_DEVICE
$SGDISK -n 0:0:+256M -t 0:89A12DE1-5E41-4CB3-8B4C-B1441EB5DA38 -c 0:"cache" $LOOP_DEVICE
$SGDISK -n 0:0:+8M -t 0:4B7A15D6-322C-42AC-8110-88B7DA0C5D77 -c 0:"systemrw" $LOOP_DEVICE
$SGDISK -n 0:0:+64M -t 0:D504D6DB-FA92-4853-B59E-C7F292E2EA19 -c 0:"recovery" $LOOP_DEVICE
$SGDISK -n 0:0:+256M -t 0:1344859D-3A6A-4C14-A316-9E696B3A5400 -c 0:"recoveryfs" $LOOP_DEVICE
$SGDISK -n 0:0:+4G -t 0:1B81E7E6-F50D-419B-A739-2AEEF8DA3335 -c 0:"userdata" $LOOP_DEVICE
$SGDISK -n 0:0:+50M -t 0:B9906CDD-5714-45B6-AED9-C7FDF7B5306E -c 0:"efi" $LOOP_DEVICE
$SGDISK -n 0:0:0 -t 0:0FC63DAF-8483-4772-8E79-3D69D8477DE4 -c 0:"system" $LOOP_DEVICE

partx -a $LOOP_DEVICE || true

fatlabel $(get_partition_by_name "efi") efi
e2label $(get_partition_by_name "system") system

mkfs.vfat -F 16 -s 1 $(get_partition_by_name "efi")
mkfs.ext4 $(get_partition_by_name "system")

