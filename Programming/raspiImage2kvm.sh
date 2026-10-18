#!/bin/bash
#
# Modify a raspberry image so it can be used by a qemu raspbian emulator
#
# For details see http://www.linux-tips-and-tricks.de/en/raspberry/310-how-to-emulate-raspberry-pi-on-kvm-2/
#
# (c) 2015 - framp at linux-tips-and-tricks dot de 

# some defaults 

SRC_DIR="~/raspberry/raspbian"
SRC_IMG=$SRC_DIR/"2015-02-16-raspbian-wheezy.img"

SRC_IMG=${1-$SRC_IMG} 
FILENAME="${SRC_IMG##*/}"
QCOW="${FILENAME%.*}".qcow
IMG="${FILENAME%.*}".img

INCREASE=6GB

echo "Copying image $SRC_IMG to ."
cp $SRC_IMG .

echo "Mouting image $IMG"
mount $IMG -o offset=62914560 /mnt

echo "Modifying image $IMG for QEMUE usage"
sed -i 's/^/#/' /mnt/etc/ld.so.preload
cat <<EOF > /mnt/etc/udev/rules.d/90-qemu.rules
KERNEL=="sda", SYMLINK+="mmcblk0"
KERNEL=="sda?", SYMLINK+="mmcblk0p%n"
KERNEL=="sda2", SYMLINK+="root"
EOF
echo $(date +"%Y-%m-%d %T") > /mnt/etc/fake-hwclock.data
umount /mnt

echo "Converting img to qcow"
qemu-img convert -f raw -O qcow2 $IMG $QCOW 

echo "Increasing disk space by $INCREASE"
qemu-img resize $QCOW +$INCREASE 

echo "Starting image now"
./start.sh $QCOW
