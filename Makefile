all: personalpan.zip personalcam2.zip

build_%:
	@echo " [DIR]            $@"
	@mkdir -p $@/Test
	@echo " [STUFF]          copy from Test/"
	@cp Test/* $@/Test/
	@touch $@/factory

build_pan/autoupdate-full.bin:
	@echo " [THINGINO-Fw]    $@"
	@wget -q https://github.com/themactep/thingino-firmware/releases/latest/download/thingino-personalcam_pan_t31x.bin -O $@ 2>&1 > /dev/null

build_cam2/autoupdate-full.bin:
	@echo " [THINGINO-Fw]    $@"
	@wget -q https://github.com/themactep/thingino-firmware/releases/latest/download/thingino-personalcam_pan_t31x.bin -O $@ 2>&1 > /dev/null
#	@wget -q https://github.com/themactep/thingino-firmware/releases/latest/download/thingino-personalcam2_t31x.bin -O $@ 2>&1 > /dev/null

build_pan/Test/test.sh: build_pan
	@cp test.sh build_pan/Test/
	@echo " [GPIO] replacing gpio stuff for Cam Pan"
	@sed -i "s/GPIO_B=.*/GPIO_B=48/" build_pan/Test/test.sh
	@sed -i "s/GPIO_B_ON=.*/GPIO_B_ON=1/" build_pan/Test/test.sh
	@sed -i "s/GPIO_B_OFF=.*/GPIO_B_OFF=0/" build_pan/Test/test.sh
	@sed -i "s/GPIO_Y=.*/GPIO_Y=47/" build_pan/Test/test.sh
	@sed -i "s/GPIO_Y_ON=.*/GPIO_Y_ON=1/" build_pan/Test/test.sh
	@sed -i "s/GPIO_Y_OFF=.*/GPIO_Y_OFF=0/" build_pan/Test/test.sh
	@sed -i "s/GPIO_IR=.*/GPIO_IR=14/" build_pan/Test/test.sh
	@sed -i "s/GPIO_IR_ON=.*/GPIO_IR_ON=1/" build_pan/Test/test.sh
	@sed -i "s/GPIO_IR_OFF=.*/GPIO_IR_OFF=0/" build_pan/Test/test.sh

build_cam2/Test/test.sh: build_cam2
	@cp test.sh build_cam2/Test/
	@echo " [GPIO] replacing gpio stuff for Cam2"

build_%/Test.tar: build_%/Test/test.sh
	@echo " [TESTTAR]        $@"
	@tar cvf $@ -C `dirname $@` Test factory 2>&1 > /dev/null

personal%.zip: build_%/Test.tar build_%/autoupdate-full.bin
	@echo " [ZIP]            $^ -> $@"
	@zip -j -r $@ $^ 2>&1 > /dev/null

clean:
	@rm -rf build_pan build_cam2 personalpan.zip personalcam2.zip
