### Whats this?
This project is a simple tool that creates an all-in-one to upgrade certain stock firmwares of T31 SoC IP cameras into the open-source OpenIPC.

### Requirements
Install the `u-boot-tools` package so mkenvimage is available. `tar`, `zip`, `make` and `wget` should be installed as well.

### How to use it
Modify `autoconfig.sh` and put your WiFi credentials on `your_ssid_here` and `your_password_here`. Run `make`. Unzip the newly-created `uncompress_to_sd.zip` to a FAT32 formatted SD card. Plug the card into the camera. Turn the camera on, and wait.

### How it works
Some firmwares based on the Hualai stock firmware for the T31 SoC contains an interesting backdoor (or feature?) that lets arbitrary code execution from an SD card.
One of the init scripts on these generic firmwares look for the existance of `/tmp/factory`, and if it finds it, the main camera app doesn't start, but rather a script is executed from `/tmp`. There's an additional application (rather than a script) that looks for a specific file on the SD card (`Test.tar`), and if it finds it, it uncompresses it, and checks for the existency of some other files. If everything seems to be in order, the `/tmp/factory` file appears, and it's possible to run a custom `test.sh` shell script from the freshly extracted tar file. For more info, [I'd link the source of a good example for a similar camera](https://qiita.com/Dmitrievich/items/05ec93b70a049a90e684 "I'd link the source of a good example for a similar camera") (use Google translate if needed).
Knowing that it's possible to run arbitrary code on these cameras, it's just a matter of figuring out a way to update the entire flash memory so it runs OpenIPC.
OpenIPC provides a tool to upgrade *some* cameras to it (a statically linked binary that can run on stock firmwares), but it's not a particular good choice for this camera.
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

Take into account that OpenIPC's ultimate firmware uses a different partition layout:
| mtd | size | name |
| ------------ | ------------ | ------------ |
| mtd0 | 00040000 | boot |
| mtd1 | 00010000 | env |
| mtd2 | 0300000 | kernel |
| mtd3 | 0a00000 | rootfs |
| mtd4 | - | roofs_data |

`boot`, where u-boot is stored, has the same size on both firmwares. However, the stock firmware doesn't have a `env` partition (which is where u-boot's environment is stored). Nonetheless, the stock firmware's `kernel` partition starts at the same address where `env` should start on OpenIPC. This means, OpenIPC's u-boot and env could be updated in-place without much headache. Considering the stock firmware already contains `flash_cp` (a tool to write binaries directly to MTD devices, like the mtd0 or mtd1), it is possible to swap the u-boot and provide a custom environment from within the stock firmware using the `Test.tar` method from above. These additional firmware files come directly from the latest OpenIPC CICD builds and are copied alongside `Test.tar` on the SD card, so they can be read from the stock firmware's Linux, or the u-boot later on.
If this is executed, then after a reboot, the OpenIPC u-boot would boot instead of the stock firmware's u-boot. However, due to the other partitions not matching what OpenIPC expects, it'd fail to boot. Thus, a custom boot script was provided. This new boot macro is stored on a custom u-boot environment created by this tool. Updating the default `bootcmd` env variable does the trick. Instead of trying to boot as it would normally, some commands were injected there. First of all, OpenIPC's u-boot doesn't recognize the SD card by default since a GPIO is not properly set, so the first thing would be to initialize the SD card by setting the GPIO and running `mmc rescan`. Then, run the same commands provided by the [OpenIPC firmware install guide](https://openipc.org/cameras/vendors/ingenic/socs/t31x?mac=2e-39-e0-b1-ef-87&cip=192.168.1.10&sip=192.168.1.254&net=wifi&rom=nor16m&var=ultimate&sd=sd "OpenIPC firmware install guide"), which updates the uImage (kernel) and rootfs directly on the expected addresses on the SPI flash, then clears the region of the `rootfs_data`, and finally executes the `setnor16m` to properly set up the boot command that OpenIPC expects and reboots. Note that this command comes from the `bootcmdnor` environment variable, which was also modified to properly initialize the SD card on every single boot; alongside turning on the yellow LED (gpio 47).
Per the new WiFi driver loading mechanism, a new environment variable is also set with the appropriate driver name `wlandevice=atbm603x-t31-mmc1`.
After the system reboots, OpenIPC is fully running, but it's not connected to any useful WiFi (it'd be trying to connect to a SSID of OpenIPC and password openipc12345). In order to solve this without any interaction with the camera, an `autoconfig.sh` file is also added on the SD card as well. This file is executed by OpenIPC on boot, and gets removed afterwards. On this file, it's possible to call `fw_setenv` to set the AP's SSID and password, and just reboot. Finally, once the system reboots, this file is not on the SD card anymore (got erased after executing it), but the WiFi should be already connected to the configured credentials.

Bonus:
The `test.sh` also dumps the stock firmware's partitions to the SD card for future use, so nothing should be lost.
In order to recover the original firmware, a custom u-boot macro could be set on `bootcmd`so after OpenIPC reboots, u-boot executes this command instead of booting, and reverts back to the stock firmware. Since the `test.sh` script copies the partitions one-by-one, a concatenation of all these needs to be manually created before attempting to recover the original firmware. This can be done thru ssh on the camera (with the SD card connected) running OpenIPC, or in any computer where the SD card is mounted.
```bash
# cat mtd_backup_mtd0_boot.bin mtd_backup_mtd1_kernel.bin mtd_backup_mtd2_rootfs.bin mtd_backup_mtd3_app.bin mtd_backup_mtd4_kback.bin mtd_backup_mtd5_aback.bin mtd_backup_mtd6_cfg.bin mtd_backup_mtd7_para.bin > stock.bin
```
Once `stock.bin` is created, set the a custom `bootcmd` environment variable on the camera so in the next reboot the camera restores the stock firmware:
```bash
# fw_serenv bootcmd 'gpio clear 39; mmc rescan; mw.b 0x80600000 0xff 0x1000000; fatload mmc 0:1 0x80600000 stock.bin; sf probe 0; sf erase 0x0 0x1000000; sf write 0x80600000 0x0 0x1000000; reset'
# reboot
```
