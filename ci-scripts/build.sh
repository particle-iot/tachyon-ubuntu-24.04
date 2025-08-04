#!/bin/bash

case "$1" in
    desktop)
        export PROJECT=ubuntu
        export SUBPROJECT=desktop-preinstalled
        ;;
    headless)
        export PROJECT=ubuntu-cpc
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

apt-get update -y
apt-get upgrade -y
apt-get install livecd-rootfs qemu-user-static binfmt-support -y

mkdir build
cd build

cp -r "$(dpkg -L livecd-rootfs | grep "auto$")" auto

export SUITE=noble

export RELEASE_NAME="Ubuntu 24.04 LTS (Noble Nombat)"
export RELEASE_VERSION="24.04"
export KERNEL_FLAVOR="qcom"

export ARCH=arm64
export IMAGEFORMAT=none
export IMAGE_TARGETS=disk-image-non-cloud

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
    --mirror-bootstrap "http://ports.ubuntu.com" \
    --parent-mirror-bootstrap "http://ports.ubuntu.com" \
    --mirror-chroot-security "http://ports.ubuntu.com" \
    --parent-mirror-chroot-security "http://ports.ubuntu.com" \
    --mirror-binary-security "http://ports.ubuntu.com" \
    --parent-mirror-binary-security "http://ports.ubuntu.com" \
    --mirror-binary "http://ports.ubuntu.com" \
    --parent-mirror-binary "http://ports.ubuntu.com" \
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

# Patch buggy minimize-manual
patch /usr/share/livecd-rootfs/minimize-manual $DIR/stuff/minimize-manual.patch
# Patch lb_chroot_apt to retry
patch /usr/lib/live/build/lb_chroot_apt $DIR/stuff/lb_chroot_apt.patch

patch /usr/lib/live/build/lb_binary_package-lists $DIR/stuff/lb_binary_package-lists.patch

lb build --verbose --debug

(cd chroot && mksquashfs . $DIR/build/rootfs.squashfs.xz -no-progress -xattrs -comp xz)

exit 0
