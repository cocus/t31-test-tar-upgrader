### Whats this?
This project is a simple tool that creates an all-in-one to upgrade certain stock firmwares of T31 SoC IP cameras into the open-source [Thingino](https://thingino.com/). In particular this only works with 16MB SPI flash. Should also work with 8MB flash chips, but some changes are required on `default-uenv.txt` and probably `test.sh`.

### How to use it
Run `make`. Unzip the newly-created `uncompress_to_sd.zip` to a FAT32 formatted SD card. Plug the card into the camera. Turn the camera on, and wait.

### How it works
Some firmwares based on the Hualai stock firmware for the T31 SoC contains an interesting backdoor (or feature?) that lets arbitrary code execution from an SD card.

One of the init scripts on these generic firmwares look for the existance of `/tmp/factory`, and if it finds it, the main camera app doesn't start, but rather a script is executed from `/tmp`. There's an additional application (rather than a script) that looks for a specific file on the SD card (`Test.tar`), and if it finds it, it uncompresses it, and checks for the existency of some other files. If everything seems to be in order, the `/tmp/factory` file appears, and it's possible to run a custom `test.sh` shell script from the freshly extracted tar file. For more info, [I'd link the source of a good example for a similar camera](https://qiita.com/Dmitrievich/items/05ec93b70a049a90e684 "I'd link the source of a good example for a similar camera") (use Google translate if needed).

Knowing that it's possible to run arbitrary code on these cameras, it's just a matter of figuring out a way to update the entire flash memory so it runs Thingino.
The original partition table from the stock firmware contains the following entries:
| mtd | size | name |
| ------------ | ------------ | ------------ |
| mtd0 | 00040000 | boot |
| mtd1 | 001f0000 | kernel |
| mtd2 | 003d0000 | rootfs |
| mtd3 | 003d0000 | app |
| mtd4 | 001f0000 | kback |
| mtd5 | 003d0000 | aback |
| mtd6 | 00060000 | cfg |
| mtd7 | 00010000 | para |

`boot`, where u-boot is stored, has the same size on stock and Thingino. However, the stock firmware doesn't have a `env` partition (which is where u-boot's environment is stored). 

Following [Paul's](https://github.com/themactep) instructions at [Thingino Upgrade from other Firmware](https://github.com/themactep/thingino-firmware/wiki/Installation#from-another-firmware), it's possible to just run these commands on the stock firmware.
In short, the `test.sh` script runs:
```
flashcp /path/to/mmc/u-boot-t31x.bin /dev/mtd0
flash_eraseall /dev/mtd1
```

Which updates the uboot binary from the one packaged after using this Makefile, and erases the NEXT partition after uboot, so the new uboot's env is empty and uses the default one, which can read the SD card and trigger an update with the autoupdate-full.bin.

NOTE: it might be possible that the camera reboots and ends up in the "cloner" mode (i.e. rom usb mode). Just reboot it.

### Bonus:
The `test.sh` also dumps the stock firmware's partitions to the SD card for future use, so nothing should be lost.

In order to recover the original firmware, a custom u-boot macro could be set on `bootcmd`so after OpenIPC reboots, u-boot executes this command instead of booting, and reverts back to the stock firmware.

Since the `test.sh` script copies the partitions one-by-one, a concatenation of all these needs to be manually created before attempting to recover the original firmware.

This can be done thru ssh on the camera (with the SD card connected) running OpenIPC, or in any computer where the SD card is mounted.


```bash
# cat mtd_backup_mtd0_boot.bin mtd_backup_mtd1_kernel.bin mtd_backup_mtd2_rootfs.bin mtd_backup_mtd3_app.bin mtd_backup_mtd4_kback.bin mtd_backup_mtd5_aback.bin mtd_backup_mtd6_cfg.bin mtd_backup_mtd7_para.bin > stock.bin
```


Once `stock.bin` is created, set the a custom `bootcmd` environment variable on the camera so in the next reboot the camera restores the stock firmware:
```bash
# fw_setenv bootcmd 'gpio clear 39; mmc rescan; mw.b 0x80600000 0xff 0x1000000; fatload mmc 0:1 0x80600000 stock.bin; sf probe 0; sf erase 0x0 0x1000000; sf write 0x80600000 0x0 0x1000000; reset'
# reboot
```
