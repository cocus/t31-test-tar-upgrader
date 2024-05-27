#!/bin/sh


EXPECTED_BOOT_SIZE="00040000"
MMC="/media/mmc"
UBOOT_FILE="${MMC}/u-boot-t31x.bin"
#ENV_FILE="${MMC}/ubootenv.bin"

dmesg -n1

echo ""
echo "==== about to begin, killing assis and petting watchdog in background ASAP"
pkill -9 assis
sleep 3
#echo 'V' > /dev/watchdog
watchdog -t 10 /dev/watchdog0

echo "==== remounting SD card if required"
if ! mount | grep -q $MMC; then
  echo "not mounted, trying to mount mmcblk0"
  mount /dev/mmcblk0p1 $MMC
else
  echo "it's mounted, proceeding"
fi

echo "============ fun is about to begin, sit tight"
if ! [ -d /sys/class/gpio/gpio47 ]; then
  echo 47 > /sys/class/gpio/export
  echo out > /sys/class/gpio/gpio47/direction
  echo 0 > /sys/class/gpio/gpio47/value
fi
if ! [ -d /sys/class/gpio/gpio48 ]; then
  echo 48 > /sys/class/gpio/export
  echo out > /sys/class/gpio/gpio48/direction
  echo 0 > /sys/class/gpio/gpio48/value
fi
if ! [ -d /sys/class/gpio/gpio14 ]; then
  echo 14 > /sys/class/gpio/export
  echo out > /sys/class/gpio/gpio48/direction
  echo 1 > /sys/class/gpio/gpio14/value
fi

# turn on IR leds
echo 1 > /sys/class/gpio/gpio14/value

echo "0. Gathering system info"
cat /proc/mtd > $MMC/info_mtd.log
dmesg > $MMC/info_dmesg.log
lsmod > $MMC/info_lsmod.log
ps > $MMC/info_ps.log
df -h > $MMC/info_df.log
mount > $MMC/info_mount.log

echo "0.1. creating backup of partitions"
STATE=0
cat /proc/mtd | tail -n+2 | while read; do
  MTD_DEV=$(echo ${REPLY} | cut -f1 -d:)
  MTD_NAME=$(echo ${REPLY} | cut -f2 -d\")
  # toggle blue led
  if [ $STATE -eq 0 ]; then
    echo 1 > /sys/class/gpio/gpio48/value
    STATE=1
  else
    echo 0 > /sys/class/gpio/gpio48/value
    STATE=0
  fi
  echo "Backing up ${MTD_DEV} (${MTD_NAME})..."
  dd if=/dev/${MTD_DEV}ro of=$MMC/mtd_backup_${MTD_DEV}_${MTD_NAME}.bin
done
echo "!!! Done with the backups, proceeding..."

echo "1. bind mount passwd and shadow"
umount /etc/passwd /etc/shadow 2>&1 > /dev/null
mount -o bind /tmp/Test/passwd /etc/passwd
mount -o bind /tmp/Test/shadow /etc/shadow

### echo "2. run wpa supplicant in background, waiting 3s..."
### ifconfig wlan0 up
### wpa_supplicant -D nl80211 -iwlan0 -c /tmp/Test/wpa.conf & 
### sleep 3
### echo "3. spawning udhcpcd on wlan0, sleeping 3s..."
### udhcpc -i wlan0
### sleep 3
### ifconfig wlan0

echo "4. turning on both LEDs"
echo 1 > /sys/class/gpio/gpio47/value
echo 1 > /sys/class/gpio/gpio48/value

echo "5. run upgrade to openipc"

if ! [ -f "${UBOOT_FILE}" ]; then
  echo "Update uboot file not found at ${UBOOT_FILE}"
  echo 1 > /sys/class/gpio/gpio47/value
  echo 0 > /sys/class/gpio/gpio487/value
  while [ 1 ]; do
    echo 0 > /sys/class/gpio/gpio14/value
    sleep 0.25
    echo 1 > /sys/class/gpio/gpio14/value
    sleep 0.25
  done
  exit 1
fi

#if ! [ -f "${ENV_FILE}" ]; then
#  echo "Update env file not found at ${ENV_FILE}"
#  echo 0 > /sys/class/gpio/gpio47/value
#  echo 1 > /sys/class/gpio/gpio487/value
#  while [ 1 ]; do
#    echo 0 > /sys/class/gpio/gpio14/value
#    sleep 0.25
#    echo 1 > /sys/class/gpio/gpio14/value
#    sleep 0.25
#  done
#  exit 1
#fi

cat /proc/mtd | tail -n+2 | while read; do
  MTD_DEV=$(echo ${REPLY} | cut -f1 -d:)
  MTD_SIZE=$(echo ${REPLY} | cut -f2 -d: | cut -f2 -d' ')
  MTD_NAME=$(echo ${REPLY} | cut -f2 -d\")
  if [ "${MTD_NAME}" == "boot" ]; then
    echo "it's boot"
    if ! [ "${MTD_SIZE}" == "${EXPECTED_BOOT_SIZE}" ]; then
      echo "boot is not ${EXPECTED_BOOT_SIZE}"
      echo 1 > /sys/class/gpio/gpio47/value
      echo 1 > /sys/class/gpio/gpio487/value
      while [ 1 ]; do
        echo 0 > /sys/class/gpio/gpio14/value
        sleep 0.25
        echo 1 > /sys/class/gpio/gpio14/value
        sleep 0.25
      done
      exit 1
    fi
    echo "Copying uboot to ${MTD_NAME}"
    flashcp ${UBOOT_FILE} /dev/${MTD_DEV}
    echo "Nuking the mtd1"
    flash_eraseall /dev/mtd1
#    echo "Copying env update to mtd1..."
#    flashcp ${ENV_FILE} /dev/mtd1
    reboot
    exit 0
  fi
done
