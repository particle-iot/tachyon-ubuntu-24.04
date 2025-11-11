#!/bin/bash

case "$1" in
    desktop)
        export PROJECT=ubuntu
        export SUBPROJECT=desktop-preinstalled
        export IMAGE_SIZE=$((5*1024*1024*1024)) # 4GB
        ;;
    headless)
        export PROJECT=ubuntu-cpc
        export IMAGE_SIZE=$((4*1024*1024*1024)) # 3GB
        ;;
    *)
        echo "Unknown image type"
        exit 1
        ;;
esac

set -e

DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")

cd "$DIR"

export DEBIAN_FRONTEND=noninteractive

if dpkg -s circleci-runner >/dev/null 2>&1; then
    apt-mark hold circleci-runner
fi
apt-get update -y
apt-get upgrade -y
apt-get install livecd-rootfs qemu-user-static binfmt-support -y

# Patch buggy minimize-manual
patch /usr/share/livecd-rootfs/minimize-manual $DIR/stuff/minimize-manual.patch
# Patch lb_chroot_apt to retry
patch /usr/lib/live/build/lb_chroot_apt $DIR/stuff/lb_chroot_apt.patch

patch /usr/lib/live/build/lb_binary_package-lists $DIR/stuff/lb_binary_package-lists.patch

patch /usr/share/livecd-rootfs/live-build/ubuntu-cpc/hooks.d/chroot/999-ubuntu-image-customization.chroot $DIR/stuff/999-ubuntu-image-customization.chroot.patch
patch /usr/share/livecd-rootfs/live-build/auto/config $DIR/stuff/config.patch
patch /usr/share/livecd-rootfs/live-build/ubuntu-cpc/hooks.d/base/disk-image-uefi.binary $DIR/stuff/disk-image-uefi.patch

mkdir build
cd build

cp -r "$(dpkg -L livecd-rootfs | grep "auto$")" auto

export SUITE=noble

export RELEASE_NAME="Ubuntu 24.04 LTS (Noble Nombat)"
export RELEASE_VERSION="24.04"
export KERNEL_FLAVOR="particle"

export ARCH=arm64
export IMAGEFORMAT=ext4
export IMAGE_HAS_HARDCODED_PASSWORD=1
export IMAGE_FORCE_HOOKS=true
export IMAGE_TARGETS=disk-image-non-cloud,disk1-img-xz

if [[ "${CIRCLECI:-}" == "true" ]]; then
    export APT_MIRROR="http://us-east-1.ec2.ports.ubuntu.com/ubuntu-ports"
else
    export APT_MIRROR="http://ports.ubuntu.com"
fi

unset DEBIAN_FRONTEND

sed -i '1s/^/set -x\n/' $HOME/.bashrc
mv /bin/sh /bin/sh.orig
cat << 'EOF' > /bin/sh
#!/bin/sh.orig

exec /bin/sh.orig -x "$@"
EOF
chmod +x /bin/sh

lb config \
    --architecture arm64 \
    --bootstrap-qemu-arch arm64 \
    --bootstrap-qemu-static /usr/bin/qemu-aarch64-static \
    --archive-areas "main restricted universe multiverse" \
    --parent-archive-areas "main restricted universe multiverse" \
    --mirror-bootstrap "${APT_MIRROR}" \
    --parent-mirror-bootstrap "${APT_MIRROR}" \
    --mirror-chroot-security "${APT_MIRROR}" \
    --parent-mirror-chroot-security "${APT_MIRROR}" \
    --mirror-binary-security "${APT_MIRROR}" \
    --parent-mirror-binary-security "${APT_MIRROR}" \
    --mirror-binary "${APT_MIRROR}" \
    --parent-mirror-binary "${APT_MIRROR}" \
    --mirror-chroot "${APT_MIRROR}" \
    --parent-mirror-chroot "${APT_MIRROR}" \
    --keyring-packages ubuntu-keyring \
    --linux-flavours "${KERNEL_FLAVOR}" \
    --initramfs none \
    --system normal

# Add some default packages
cat >> config/package-lists/particle.list.chroot <<EOF
software-properties-common
network-manager
EOF
cp -a config/package-lists/particle.list.chroot config/package-lists/particle.list.binary

# Add particle repo
cat >> config/archives/particle.list.chroot <<EOF
deb [signed-by=/etc/apt/trusted.gpg.d/particle.key.gpg] http://packages.particle.io/ubuntu noble-stable main
deb-src [signed-by=/etc/apt/trusted.gpg.d/particle.key.gpg] http://packages.particle.io/ubuntu noble-stable main
EOF
cp -a config/archives/particle.list.chroot config/archives/particle.list.binary

wget -O config/archives/particle.key https://packages.particle.io/public-keyring.gpg

touch config/universe-enabled

lb build --verbose --debug

if [ "$PROJECT" == "ubuntu" ]; then
    xz -T4 -c binary/boot/disk-uefi.ext4 > $DIR/build/rootfs.img.xz
else
    mv livecd.ubuntu-cpc.disk1.img.xz $DIR/build/rootfs.img.xz
fi

exit 0
