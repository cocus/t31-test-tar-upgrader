all: uncompress_to_sd.zip

openipc.t31-nor-ultimate.tgz:
	@echo " [OPENIPC]  $@"
	@wget -q https://github.com/OpenIPC/firmware/releases/download/latest/openipc.t31-nor-ultimate.tgz 2>&1 > /dev/null

uImage.t31: openipc.t31-nor-ultimate.tgz
	@echo " [TGZ]      $< -> $@"
	@tar -zxvf $< $@ 2>&1 > /dev/null

rootfs.squashfs.t31: openipc.t31-nor-ultimate.tgz
	@echo " [TGZ]      $< -> $@"
	@tar -zxvf $< $@ 2>&1 > /dev/null

u-boot-t31x-universal.bin:
	@echo " [OPENIPC]  $@"
	@wget -q https://github.com/OpenIPC/firmware/releases/download/latest/u-boot-t31x-universal.bin 2>&1 > /dev/null

uncompress_to_sd.zip: ubootenv.bin Test.tar uImage.t31 rootfs.squashfs.t31 u-boot-t31x-universal.bin
	@echo " [ZIP]      $^ -> $@"
	@zip -r $@ $^ 2>&1 > /dev/null

ubootenv.bin: default-uenv.txt
	@echo " [UBOOTENV] $< -> $@"
	@mkenvimage -s 0x10000 -o $@ $<

factory:
	@touch factory

Test.tar: factory Test
	@echo " [TESTTAR]  $^ -> $@"
	@tar cvf $@ Test factory 2>&1 > /dev/null

clean:
	@rm -f ubootenv.bin Test.tar factory uncompress_to_sd.zip openipc.t31-nor-ultimate.tgz uImage.t31 rootfs.squashfs.t31 u-boot-t31x-universal.bin
