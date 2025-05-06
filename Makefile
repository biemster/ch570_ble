TARGET := broadcaster

TOOLCHAIN_PREFIX := ../../CH592/MRS_Toolchain_Linux_x64_V1.92/RISC-V_Embedded_GCC12/bin/riscv-none-elf

APP_C_SRCS += \
  ./$(TARGET).c

SDK_BLE_HAL_C_SRCS := \
  ./sdk/BLE/HAL/MCU.c \
  ./sdk/BLE/HAL/RTC.c \
  ./sdk/BLE/HAL/SLEEP.c

SDK_STDPERIPHDRIVER_C_SRCS += \
  ./sdk/StdPeriphDriver/CH57x_clk.c \
  ./sdk/StdPeriphDriver/CH57x_flash.c \
  ./sdk/StdPeriphDriver/CH57x_gpio.c \
  ./sdk/StdPeriphDriver/CH57x_i2c.c \
  ./sdk/StdPeriphDriver/CH57x_keyscan.c \
  ./sdk/StdPeriphDriver/CH57x_pwm.c \
  ./sdk/StdPeriphDriver/CH57x_pwr.c \
  ./sdk/StdPeriphDriver/CH57x_spi.c \
  ./sdk/StdPeriphDriver/CH57x_sys.c \
  ./sdk/StdPeriphDriver/CH57x_timer.c \
  ./sdk/StdPeriphDriver/CH57x_uart.c \
  ./sdk/StdPeriphDriver/CH57x_usbdev.c \
  ./sdk/StdPeriphDriver/CH57x_usbhostBase.c \
  ./sdk/StdPeriphDriver/CH57x_usbhostClass.c

SDK_STARTUP_S_UPPER_SRCS += \
  ./sdk/Startup/startup_CH572.S

C_SRCS := \
  $(APP_C_SRCS) \
  $(SDK_BLE_HAL_C_SRCS) \
  $(SDK_STDPERIPHDRIVER_C_SRCS)

S_UPPER_SRCS := \
  $(SDK_STARTUP_S_UPPER_SRCS)

OBJS := \
  $(foreach src,$(C_SRCS),$(subst ./,obj/,$(patsubst %.c,%.o,$(src)))) \
  $(foreach src,$(S_UPPER_SRCS),$(subst ./,obj/,$(patsubst %.S,%.o,$(src))))

MAKEFILE_DEPS := \
  $(foreach obj,$(OBJS),$(patsubst %.o,%.d,$(obj)))


STDPERIPHDRIVER_LIB := -L"./sdk/StdPeriphDriver" -lISP572
BLE_LIB := -L"./sdk/BLE/LIB" -lCH572BLE_PERI
LIBS := $(STDPERIPHDRIVER_LIB) $(BLE_LIB)

SECONDARY_FLASH := $(TARGET).hex
SECONDARY_LIST := $(TARGET).lst
SECONDARY_SIZE := $(TARGET).siz
SECONDARY_BIN := $(TARGET).bin

# ARCH is rv32imac on older gcc, rv32imac_zicsr on newer gcc
# ARCH := rv32imac
ARCH := rv32imac_zicsr

CFLAGS_COMMON := \
  -march=$(ARCH) \
  -mabi=ilp32 \
  -mcmodel=medany \
  -msmall-data-limit=8 \
  -mno-save-restore \
  -Os \
  -fmessage-length=0 \
  -fsigned-char \
  -ffunction-sections \
  -fdata-sections
  #-g

.PHONY: all
all: $(TARGET).elf secondary-outputs

.PHONY: clean
clean:
	-rm $(OBJS)
	-rm $(MAKEFILE_DEPS)
	-rm $(SECONDARY_FLASH)
	-rm $(SECONDARY_LIST)
	-rm $(SECONDARY_BIN)
	-rm $(TARGET).elf
	-rm $(TARGET).map
	-rm -r ./obj

.PHONY: secondary-outputs
secondary-outputs: $(SECONDARY_FLASH) $(SECONDARY_LIST) $(SECONDARY_SIZE) $(SECONDARY_BIN)

$(TARGET).elf: $(OBJS)
	${TOOLCHAIN_PREFIX}-gcc \
	    $(CFLAGS_COMMON) \
	    -T "sdk/Ld/Link.ld" \
	    -nostartfiles \
	    -Xlinker \
	    --gc-sections \
	    -Xlinker \
	    --print-memory-usage \
	    -Wl,-Map,"$(TARGET).map" \
	    -Lobj \
	    --specs=nano.specs \
	    --specs=nosys.specs \
	    -o "$(TARGET).elf" \
	    $(OBJS) \
	    $(LIBS)

%.hex: %.elf
	@ ${TOOLCHAIN_PREFIX}-objcopy -O ihex "$<"  "$@"

%.bin: %.elf
	$(TOOLCHAIN_PREFIX)-objcopy -O binary $< "$@"

%.lst: %.elf
	@ ${TOOLCHAIN_PREFIX}-objdump \
	    --source \
	    --all-headers \
	    --demangle \
	    --line-numbers \
	    --wide "$<" > "$@"

%.siz: %.elf
	@ ${TOOLCHAIN_PREFIX}-size --format=berkeley "$<"

obj/%.o: ./%.c
	@ mkdir --parents $(dir $@)
	@ ${TOOLCHAIN_PREFIX}-gcc \
	    $(CFLAGS_COMMON) \
	    -DDEBUG \
	    -I"src/include" \
	    -I"sdk/StdPeriphDriver/inc" \
	    -I"sdk/RVMSIS" \
	    -I"sdk/BLE/LIB" \
	    -I"sdk/BLE/HAL/include" \
	    -std=gnu99 \
	    -MMD \
	    -MP \
	    -MF"$(@:%.o=%.d)" \
	    -MT"$(@)" \
	    -c \
	    -o "$@" "$<"

obj/%.o: ./%.S
	@ mkdir --parents $(dir $@)
	@ ${TOOLCHAIN_PREFIX}-gcc \
	    $(CFLAGS_COMMON) \
	    -x assembler \
	    -MMD \
	    -MP \
	    -MF"$(@:%.o=%.d)" \
	    -MT"$(@)" \
	    -c \
	    -o "$@" "$<"

rx: CFLAGS_COMMON += -DTEST_MODE=MODE_RX
rx: clean all

tx: CFLAGS_COMMON += -DTEST_MODE=MODE_TX
tx: clean all

f: clean all
	chprog $(TARGET).bin

flash: 
	chprog $(TARGET).bin
