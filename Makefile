.PHONY: clean default

default: all


#TARGET	?= qemu-rv32g
#TARGET	?= qemu-rv64g
#TARGET	?= qemu-rv64gc
TARGET	?= qemu-rv64gqc
#TARGET	?= vf2

DEBUG ?= -DDEBUG

ifeq ($(TARGET), qemu-rv32g)
	ARCH    	?= riscv32-unknown-elf
	XLEN		= 32
	TOOLBIN 	?= /opt/riscv/rv32g/bin
	ADDFLAGS	= -DHW_QEMU -DXLEN=$(XLEN) -march=rv32g
	RUN			= qemu-system-riscv32 -machine virt -cpu rv32,pmp=false -smp 2 -gdb tcp::1234 -bios none -serial stdio -display none -kernel $(BUILD)/$(NAME).img
endif

ifeq ($(TARGET), qemu-rv64g)
	ARCH    	?= riscv64-unknown-elf
	XLEN		= 64
	TOOLBIN 	?= /opt/riscv/rv64g/bin
	ADDFLAGS	= -DHW_QEMU -DXLEN=$(XLEN) -march=rv64g
	RUN			= qemu-system-riscv64 -machine virt -cpu rv64,pmp=false -smp 2 -gdb tcp::1234 -bios none -serial stdio -display none -kernel $(BUILD)/$(NAME).img
endif

ifeq ($(TARGET), qemu-rv64gc)
	ARCH    	?= riscv64-unknown-elf
	XLEN		= 64
	TOOLBIN 	?= /opt/riscv/rv64g/bin
	ADDFLAGS	= -DENABLE_RVC -DHW_QEMU -DXLEN=$(XLEN) -march=rv64gc -mabi=lp64
	RUN			= qemu-system-riscv64 -machine virt -cpu rv64,pmp=false -smp 2 -gdb tcp::1234 -bios none -serial stdio -display none -kernel $(BUILD)/$(NAME).img
endif

ifeq ($(TARGET), qemu-rv64gqc)
	ARCH    	?= riscv64-unknown-elf
	XLEN		= 64
	TOOLBIN 	?= /opt/riscv/rv64g/bin
	ADDFLAGS	= -DENABLE_RVC -DHW_QEMU -DXLEN=$(XLEN) -march=rv64gqc -mabi=lp64
	RUN			= qemu-system-riscv64 -machine virt -cpu rv64,pmp=false -smp 2 -gdb tcp::1234 -bios none -serial stdio -display none -kernel $(BUILD)/$(NAME).img
endif

ifeq ($(TARGET), vf2)
	ARCH    	?= riscv64-unknown-elf
	XLEN		= 64
	TOOLBIN 	?= /opt/riscv/rv64g/bin
	ADDFLAGS	= -DENABLE_RVC -DHW_VF2 -DXLEN=$(XLEN) -march=rv64gc
define VF2_RUN_MSG

	running on VF2:
	- set TARGET = vf2 in this Makefile
	- make clean; make
	- create a FAT filesystem on SD card
	- copy build/vf2/vmon.img to SD card
	- insert SD card into VF2
	- attach GPIO-to-USB serial terminal to VF2 (e.g. minicom, 115200 baud)
	- set minicom to "Add Carriage Ret" (Ctrl-A Z, then U)
	- boot into U-Boot from SPI (both dip-switches to L)
	- in U-Boot command line, load and run vmon.img:
	StarFive # fatload mmc 1:2  0x43fff000 vmon.img
	StarFive # go 44000000

endef
	export VF2_RUN_MSG 
	RUN			= @echo "$$VF2_RUN_MSG"

endif

NAME	= vmon
CC      = $(TOOLBIN)/$(ARCH)-gcc
CFLAGS	= $(DEBUG) $(ADDFLAGS) -nostartfiles -g -I"src/include"
LD		= $(TOOLBIN)/$(ARCH)-ld
LDFLAGS = --no-warn-rwx-segments
OBJCOPY = $(TOOLBIN)/$(ARCH)-objcopy
OBJDUMP = $(TOOLBIN)/$(ARCH)-objdump
STRIP   = $(TOOLBIN)/$(ARCH)-strip
GDB		= $(TOOLBIN)/$(ARCH)-gdb
SRCD	= src
LOGD	= log

BUILD	= build/$(TARGET)
SRC = $(wildcard $(SRCD)/*.S)
OBJ = $(SRC:$(SRCD)/%.S=$(BUILD)/%.o)
DEP = $(OBJ:%.o=%.d)

-include $(DEP)


all: $(BUILD) $(BUILD)/$(NAME).img $(BUILD)/$(NAME)-stripped.img
	ls -al $(BUILD)/$(NAME).img $(BUILD)/$(NAME)-stripped.img

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/$(NAME).img: $(BUILD)/$(NAME).elf
	$(OBJCOPY) $(BUILD)/$(NAME).elf -I binary $@

$(BUILD)/$(NAME)-stripped.img: $(BUILD)/$(NAME).img
	$(STRIP) $< -o $@

$(BUILD)/$(NAME).elf: linker/link.ld.$(TARGET) Makefile $(OBJ)
	$(LD) -T linker/link.ld.$(TARGET) $(LDFLAGS) -o $@ $(OBJ)

$(BUILD)/%.o: $(SRCD)/%.S Makefile
	$(CC) $(CFLAGS) -MMD -c $< -o $@


clean:
	rm -f $(BUILD)/*.o $(BUILD)/*.d $(BUILD)/*.elf $(BUILD)/*.img $(BUILD)/*.log $(BUILD)/*.objdump

run: $(BUILD)/$(NAME).img
	$(RUN)

debug:
	$(GDB) entry -ex "target remote :1234"

