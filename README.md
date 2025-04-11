## Ubuntu 24.04 based on Qualcomm/Canonical build

### Chroot/rootfs

TODO add documentation and build scripts for chroot/rootfs. This is done with [livecd-rootfs](https://launchpad.net/livecd-rootfs).

### What works for now

1. WiFi (sometimes doesn't probe)
2. BLE (MAC needs to be set on boot with `sudo btmgmt -i hci0 public-addr 11:22:33:44:55:66`, TODO fix)
3. USB Host
4. Main USB port in gadget/peripheral mode by default or in Host mode if manually switched with `echo "host" | sudo tee /sys/kernel/debug/usb/a600000.usb/mode`. Automatic switching doesn't work, something with pmic-glink
6. `qupv3fw.elf` firmware loading for i2c/spi/uart peripheral configurations
7. PCIE

### What definitely doesn't work

1. Modem. It is detected/loads firmware, but crashes with glink issues. To test start `rmtfs.service`
2. ADB. No prebuilt adbd package and gadget configuration, need to add.

### Flashing

Prerequisite: running normal 20.04 image.

1. Flash u-boot/xbl combined binaries, see https://github.com/particle-iot-inc/tachyon-u-boot
2. Replace LUN 0 `edl --loader=prog_firehose_ddr.elf wf --memory=ufs --lun=0 tachyon-ubuntu-24.04-preview+250412.img`
3. Reset `edl --loader=prog_firehose_ddr.elf reset`

To sum up:

```console
$ edl --loader=prog_firehose_ddr.elf w xbl_a xbl.mbn
$ edl --loader=prog_firehose_ddr.elf w xbl_b xbl.mbn
$ edl --loader=prog_firehose_ddr.elf wf --memory=ufs --lun=0 tachyon-ubuntu-24.04-preview+250412.img
$ edl --loader=prog_firehose_ddr.elf reset
```
