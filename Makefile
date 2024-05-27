all: uncompress_to_sd.zip

u-boot-t31x.bin:
	@echo " [GTXASPEC-UBOOT] $@"
	@wget -q https://github.com/gtxaspec/u-boot-ingenic/releases/download/latest/u-boot-t31x.bin 2>&1 > /dev/null

autoupdate-full.bin:
	@echo " [THINGINO-Fw]    $@"
	@wget -q https://github.com/themactep/thingino-firmware/releases/download/firmware/thingino-personalcam.bin -O $@ 2>&1 > /dev/null


uncompress_to_sd.zip: Test.tar u-boot-t31x.bin autoupdate-full.bin
	@echo " [ZIP]            $^ -> $@"
	@zip -r $@ $^ 2>&1 > /dev/null

factory:
	@touch factory

Test.tar: factory Test
	@echo " [TESTTAR]        $^ -> $@"
	@tar cvf $@ Test factory 2>&1 > /dev/null

clean:
	@rm -f Test.tar factory uncompress_to_sd.zip autoupdate-full.bin u-boot-t31x.bin
