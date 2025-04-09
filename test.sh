#!/bin/sh

GPIO_B=39
GPIO_B_PATH=/sys/class/gpio/gpio${GPIO_B}/value
GPIO_B_ON=0
GPIO_B_OFF=1

GPIO_Y=38
GPIO_Y_PATH=/sys/class/gpio/gpio${GPIO_Y}/value
GPIO_Y_ON=0
GPIO_Y_OFF=1

GPIO_IR=47
GPIO_IR_PATH=/sys/class/gpio/gpio${GPIO_IR}/value
GPIO_IR_ON=1
GPIO_IR_OFF=0

EXPECTED_BOOT_SIZE="00040000"

MMC="/media/mmc"
UPD_FILE="$MMC/autoupdate-full.bin"

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
if ! [ -d /sys/class/gpio/gpio${GPIO_B} ]; then
  echo ${GPIO_B} > /sys/class/gpio/export
  echo out > /sys/class/gpio/gpio${GPIO_B}/direction
fi
if ! [ -d /sys/class/gpio/gpio${GPIO_Y} ]; then
  echo ${GPIO_Y} > /sys/class/gpio/export
  echo out > /sys/class/gpio/gpio${GPIO_Y}/direction
fi
if ! [ -d /sys/class/gpio/gpio${GPIO_IR} ]; then
  echo ${GPIO_IR} > /sys/class/gpio/export
  echo out > /sys/class/gpio/gpio${GPIO_IR}/direction
fi

echo ${GPIO_B_OFF} > ${GPIO_B_PATH}
echo ${GPIO_Y_OFF} > ${GPIO_Y_PATH}
echo ${GPIO_IR_OFF} > ${GPIO_IR_PATH}

echo "0. Gathering system info"
cat /proc/mtd > $MMC/info_mtd.log
dmesg > $MMC/info_dmesg.log
lsmod > $MMC/info_lsmod.log
ps > $MMC/info_ps.log
df -h > $MMC/info_df.log
mount > $MMC/info_mount.log

echo "0.1. creating backup of partitions"
STATE=0
MKFULL="/tmp/mkfull.sh"
echo "#!/bin/sh" > $MKFULL
echo "cd $MMC" >> $MKFULL
echo "cat \\" >> $MKFULL
cat /proc/mtd | tail -n+2 | while read; do
  MTD_DEV=$(echo ${REPLY} | cut -f1 -d:)
  MTD_NAME=$(echo ${REPLY} | cut -f2 -d\")
  # toggle blue led
  if [ $STATE -eq 0 ]; then
    echo ${GPIO_B_ON} > ${GPIO_B_PATH}
    STATE=1
  else
    echo ${GPIO_B_OFF} > ${GPIO_B_PATH}
    STATE=0
  fi
  echo "Backing up ${MTD_DEV} (${MTD_NAME})..."
  dd if=/dev/${MTD_DEV}ro of=$MMC/mtd_backup_${MTD_DEV}_${MTD_NAME}.bin
  echo "mtd_backup_${MTD_DEV}_${MTD_NAME}.bin \\" >> $MKFULL
done

echo " > $MMC/fullbackup.bin" >> $MKFULL
chmod +x $MKFULL

# make the full backup
echo ${GPIO_B_OFF} > ${GPIO_B_PATH}
echo ${GPIO_Y_ON} > ${GPIO_Y_PATH}
$MKFULL
echo ${GPIO_B_OFF} > ${GPIO_B_PATH}
echo ${GPIO_Y_OFF} > ${GPIO_Y_PATH}


echo "!!! Done with the backups, proceeding..."

sync

### echo "1. bind mount passwd and shadow"
### umount /etc/passwd /etc/shadow 2>&1 > /dev/null
### mount -o bind /tmp/Test/passwd /etc/passwd
### mount -o bind /tmp/Test/shadow /etc/shadow

### echo "2. run wpa supplicant in background, waiting 3s..."
### ifconfig wlan0 up
### wpa_supplicant -D nl80211 -iwlan0 -c /tmp/Test/wpa.conf & 
### sleep 3
### echo "3. spawning udhcpcd on wlan0, sleeping 3s..."
### udhcpc -i wlan0
### sleep 3
### ifconfig wlan0

echo "4. turning on both LEDs"
echo ${GPIO_Y_ON} > ${GPIO_Y_PATH}
echo ${GPIO_B_ON} > ${GPIO_B_PATH}

echo "5. check if upd file is there"
if ! [ -f "${UPD_FILE}" ]; then
  echo "Update uboot file not found at ${UPD_FILE}" > $MMC/error.log
  echo ${GPIO_Y_OFF} > ${GPIO_Y_PATH}
  echo ${GPIO_B_OFF} > ${GPIO_B_PATH}
  echo ${GPIO_IR_ON} > ${GPIO_IR_PATH}
  while [ 1 ]; do
    echo ${GPIO_Y_ON} > ${GPIO_Y_PATH}
    sleep 0.25
    echo ${GPIO_Y_OFF} > ${GPIO_Y_PATH}
    sleep 0.25
  done
  # watchdog will bite before ever hitting this!
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
      echo "boot is not ${EXPECTED_BOOT_SIZE} bytes, it's ${MTD_SIZE}" > $MMC/error.log
      echo ${GPIO_Y_OFF} > ${GPIO_Y_PATH}
      echo ${GPIO_B_OFF} > ${GPIO_B_PATH}
	    echo ${GPIO_IR_ON} > ${GPIO_IR_PATH}
      while [ 1 ]; do
        echo ${GPIO_B_ON} > ${GPIO_B_PATH}
        sleep 0.25
        echo ${GPIO_B_OFF} > ${GPIO_B_PATH}
        sleep 0.25
      done
      # watchdog will bite before ever hitting this!
      exit 1
    fi

    echo ${GPIO_Y_ON} > ${GPIO_Y_PATH}
    echo "Copying uboot to ${MTD_NAME}"
    # get only 256k
    dd if=${UPD_FILE} of=/tmp/bootloader.bin bs=262144 count=1
    flashcp /tmp/bootloader.bin /dev/${MTD_DEV}
    #flash_eraseall /dev/${MTD_DEV}
    echo ${GPIO_B_ON} > ${GPIO_B_PATH}
    echo "Nuking the mtd1"
    flash_eraseall /dev/mtd1
    #echo "Copying env update to mtd1..."
    #flashcp ${ENV_FILE} /dev/mtd1
    sync
    #reboot -f
    # it's better for the WDT to bite than to reboot... go figure.
    echo ${GPIO_Y_OFF} > ${GPIO_Y_PATH}
    echo ${GPIO_B_OFF} > ${GPIO_B_PATH}
    while [ 1 ]; do
      echo ${GPIO_Y_ON} > ${GPIO_Y_PATH}
      echo ${GPIO_B_ON} > ${GPIO_B_PATH}
      sleep 0.25
      echo ${GPIO_Y_OFF} > ${GPIO_Y_PATH}
      echo ${GPIO_B_OFF} > ${GPIO_B_PATH}
      sleep 0.25
    done
    # watchdog will bite before ever hitting this!
    exit 1
  fi
done

# we didn't find boot, so... keep flashing all
echo ${GPIO_Y_OFF} > ${GPIO_Y_PATH}
echo ${GPIO_B_OFF} > ${GPIO_B_PATH}
echo ${GPIO_IR_ON} > ${GPIO_IR_PATH}
while [ 1 ]; do
	echo ${GPIO_Y_ON} > ${GPIO_Y_PATH}
	echo ${GPIO_B_ON} > ${GPIO_B_PATH}
	sleep 0.25
	echo ${GPIO_Y_OFF} > ${GPIO_Y_PATH}
	echo ${GPIO_B_OFF} > ${GPIO_B_PATH}
	sleep 0.25
done
