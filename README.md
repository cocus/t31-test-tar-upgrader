### Whats this?
This project is a simple tool that creates an all-in-one to upgrade certain stock firmwares of T31 SoC IP cameras into the open-source [Thingino](https://thingino.com/). In particular this only works with 16MB SPI flash. Should also work with 8MB flash chips. However, this only implements the Personal Cam Pan and Cam2 cameras.

### How to use it
NOTE: It only supports Personal Cam Pan and Personal Cam2, but in theory it might support a lot more.
1. Run `make`.
2. Unzip the newly-created `personalcam2.zip` or `personalpan.zip` to a FAT32 formatted SD card. FAT16 or exFAT WON'T WORK!.
3. Plug the card into the camera. Turn the camera on, and wait.
4. The Yellow, Blue and IR LEDs show you the status of the update, as follows:
 - Blue blink, NO IR, NO Yellow: dumping backup to SD.
 - Yellow blink, IR ON, NO Blue: update file not found.
 - Blue blink, IR ON, NO Yellow: expected boot partition size doesn't match.
 - Blue + Yellow blink, NO IR: process finished, wait for the watchdog to reboot the camera (or reboot it yourself)
 - Blue + Yellow blink, solid IR: couldn't find boot partition.
 - Blue solid, NO IR, NO Yellow: Flashing uboot.
 - Yellow solid, NO IR, NO Blue: Generating full backup of all partitions.
 - Blue + Yellow solid, NO IR: Erasing mtd1.
5. Once the LED goes dark (or you cycle its power), the system reboots into the new u-boot. This new u-boot will see the `autoupdate-full.bin` and flash it. This part of the process doesn't show any LED indication, so you need to be patient. If it takes more than 5 minutes, power cycle it (and hope for the best).
6. Fast Blue LED blinks will occur, which means the cycle is finished, and the camera is booting Thingino!

If it doesn't work, you'll need to take it apart and follow the [Thingino Cloner](https://thingino.com/cloner) tutorial.

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

In order to recover the original firmware, a custom u-boot macro could be set on `bootcmd`so after Thingino reboots, u-boot executes this command instead of booting, and reverts back to the stock firmware.

`fullbackup.bin` is created automatically when running the exploit and it's on the SD card, so it's possible tro just set the a custom `bootcmd` environment variable on the camera so in its next reboot it'll restore the stock firmware:
```bash
# fw_setenv bootcmd 'mmc rescan; mw.b 0x80600000 0xff 0x1000000; fatload mmc 0:1 0x80600000 stock.bin; sf probe 0; sf erase 0x0 0x1000000; sf write 0x80600000 0x0 0x1000000; reset'
# reboot
```

You can use the `fullbackup.bin` file as part of a single image that can be written on the flash using Ingenic's cloner.
