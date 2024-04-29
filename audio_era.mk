AUDIO_ERA_BUILD = $(SOFT_BUILD)/audio_era

ARIANE ?= $(ESP_ROOT)/rtl/cores/ariane/ariane

RISCV_TESTS = $(SOFT)/riscv-tests
RISCV_PK = $(SOFT)/riscv-pk
OPENSBI = $(SOFT)/opensbi

AUDIO_ERA = $(ESP_ROOT)/soft/ariane/audio-era
AUDIO_PIPELINE = $(ESP_ROOT)/soft/ariane/audio-era/src/audio-pipeline
MINI_ERA = $(ESP_ROOT)/soft/ariane/audio-era/src/mini-era

audio-era: audio-era-distclean $(AUDIO_ERA_BUILD)/prom.srec $(AUDIO_ERA_BUILD)/ram.srec $(AUDIO_ERA_BUILD)/prom.bin $(AUDIO_ERA_BUILD)/audio_era.bin

audio-era-distclean: audio-era-clean

audio-era-clean:
	$(QUIET_CLEAN)$(RM)		 	\
		$(AUDIO_ERA_BUILD)/prom.srec 	\
		$(AUDIO_ERA_BUILD)/ram.srec		\
		$(AUDIO_ERA_BUILD)/prom.exe		\
		$(AUDIO_ERA_BUILD)/audio_era.exe	\
		$(AUDIO_ERA_BUILD)/prom.bin		\
		$(AUDIO_ERA_BUILD)/riscv.dtb		\
		$(AUDIO_ERA_BUILD)/startup.o		\
		$(AUDIO_ERA_BUILD)/main.o		\
		$(AUDIO_ERA_BUILD)/uart.o		\
		$(AUDIO_ERA_BUILD)/get_counter.o \
		$(AUDIO_ERA_BUILD)/read_trace.o \
		$(AUDIO_ERA_BUILD)/kernels_api.o \
		$(AUDIO_ERA_BUILD)/descrambler_function.o \
		$(AUDIO_ERA_BUILD)/viterbi_parms.o \
		$(AUDIO_ERA_BUILD)/viterbi_flat.o \
		$(AUDIO_ERA_BUILD)/audio_era.bin

$(AUDIO_ERA_BUILD)/riscv.dtb: $(ESP_CFG_BUILD)/riscv.dts $(ESP_CFG_BUILD)/socmap.vhd
	$(QUIET_BUILD) mkdir -p $(AUDIO_ERA_BUILD)
	@dtc -I dts $< -O dtb -o $@

# use the startup code from mini-era as it seems to be handling multi-core
$(AUDIO_ERA_BUILD)/startup.o: $(AUDIO_ERA)/src/mini-era/startup.S $(AUDIO_ERA_BUILD)/riscv.dtb
	@mkdir -p $(AUDIO_ERA_BUILD)
	$(QUIET_CC) cd $(AUDIO_ERA_BUILD); $(CROSS_COMPILE_ELF)gcc \
		-Os \
		-Wall -Werror \
		-mcmodel=medany -mexplicit-relocs \
		-I$(BOOTROM_PATH) -DSMP=$(SMP)\
		-c $< -o startup.o

$(AUDIO_ERA_BUILD)/main.o: $(BOOTROM_PATH)/main.c $(ESP_CFG_BUILD)/esplink.h
	@mkdir -p $(AUDIO_ERA_BUILD)
	$(QUIET_CC) $(CROSS_COMPILE_ELF)gcc \
		-Os \
		-Wall -Werror \
		-mcmodel=medany -mexplicit-relocs \
		-I$(BOOTROM_PATH) \
		-I$(DESIGN_PATH)/$(ESP_CFG_BUILD) \
		-c $< -o $@

$(AUDIO_ERA_BUILD)/uart.o: $(BOOTROM_PATH)/uart.c $(ESP_CFG_BUILD)/esplink.h
	@mkdir -p $(AUDIO_ERA_BUILD)
	$(QUIET_CC) $(CROSS_COMPILE_ELF)gcc \
		-Os \
		-Wall -Werror \
		-mcmodel=medany -mexplicit-relocs \
		-I$(BOOTROM_PATH) \
		-I$(DESIGN_PATH)/$(ESP_CFG_BUILD) \
		-c $< -o $@

$(AUDIO_ERA_BUILD)/prom.exe: $(AUDIO_ERA_BUILD)/startup.o $(AUDIO_ERA_BUILD)/uart.o $(AUDIO_ERA_BUILD)/main.o $(BOOTROM_PATH)/linker.lds
	@mkdir -p $(AUDIO_ERA_BUILD)
	$(QUIET_CC) $(CROSS_COMPILE_ELF)gcc \
		-Os \
		-Wall -Werror \
		-mcmodel=medany -mexplicit-relocs \
		-I$(BOOTROM_PATH) \
		-I$(DESIGN_PATH)/$(ESP_CFG_BUILD) \
		-nostdlib -nodefaultlibs -nostartfiles \
		-T$(BOOTROM_PATH)/linker.lds \
		$(AUDIO_ERA_BUILD)/startup.o $(AUDIO_ERA_BUILD)/uart.o $(AUDIO_ERA_BUILD)/main.o \
		-o $@
	@cp $(AUDIO_ERA_BUILD)/prom.exe $(SOFT_BUILD)/prom.exe

$(AUDIO_ERA_BUILD)/prom.srec: $(AUDIO_ERA_BUILD)/prom.exe
	@mkdir -p $(AUDIO_ERA_BUILD)
	$(QUIET_OBJCP)$(CROSS_COMPILE_ELF)objcopy -O srec $< $@
	@cp $(AUDIO_ERA_BUILD)/prom.srec $(SOFT_BUILD)/prom.srec

$(AUDIO_ERA_BUILD)/prom.bin: $(AUDIO_ERA_BUILD)/prom.exe
	@mkdir -p $(AUDIO_ERA_BUILD)
	$(QUIET_OBJCP) $(CROSS_COMPILE_ELF)objcopy -O binary $< $@
	@cp $(AUDIO_ERA_BUILD)/prom.bin $(SOFT_BUILD)/prom.bin

RISCV_CFLAGS  = -I$(RISCV_TESTS)/env
RISCV_CFLAGS += -I$(RISCV_TESTS)/benchmarks/common
RISCV_CFLAGS += -I$(BOOTROM_PATH)
RISCV_CFLAGS += -mcmodel=medany
RISCV_CFLAGS += -static
RISCV_CFLAGS += -O2
RISCV_CFLAGS += -ffast-math
RISCV_CFLAGS += -fno-common
RISCV_CFLAGS += -fno-builtin-printf
RISCV_CFLAGS += -nostdlib
RISCV_CFLAGS += -nostartfiles -lm -lgcc

RISCV_CFLAGS += -I$(RISCV_PK)/machine
RISCV_CFLAGS += -I$(DESIGN_PATH)/$(ESP_CFG_BUILD)
RISCV_CFLAGS += -I$(DRIVERS)/include/
RISCV_CFLAGS += -I$(DRIVERS)/../common/include/
RISCV_CFLAGS += -I$(DRIVERS)/common/include/
RISCV_CFLAGS += -I$(DRIVERS)/baremetal/include/
RISCV_CFLAGS += -I$(AUDIO_ERA)/include/audio-pipeline
RISCV_CFLAGS += -I$(AUDIO_ERA)/include/mini-era
RISCV_CFLAGS += -I$(AUDIO_ERA)/data

# Flags for mini-era
#SPX_CFLAGS += -DHW_FFT -DUSE_FFT_FX=32 -DUSE_FFT_ACCEL_TYPE=1 -DFFT_SPANDEX_MODE=0 -DHW_FFT_BITREV
#SPX_CFLAGS += -DHW_VIT -DVIT_DEVICE_NUM=0 -DVIT_SPANDEX_MODE=0
SPX_CFLAGS += -DDOUBLE_WORD
SPX_CFLAGS += -DUSE_ESP_INTERFACE -DITERATIONS=100
#SPX_CFLAGS += -DTWO_CORE_SCHED
#SPX_CFLAGS += -DUSE_FFT_SENSOR
#SPX_CFLAGS += -DUSE_VIT_SENSOR

# Flags for audio-pipeline
NUM_BLOCKS ?= 4
BLOCK_SIZE ?= 1024
SAMPLERATE ?= 48000
NORDER ?= 3
NUM_SRCS ?= 16
COH_MODE ?= 0
IS_ESP ?= 1
DO_CHAIN_OFFLOAD ?= 0
DO_NP_CHAIN_OFFLOAD ?= 0
DO_PP_CHAIN_OFFLOAD ?= 0
USE_INT ?= 0
USE_REAL_DATA ?= 1
DO_DATA_INIT ?= 1
USE_AUDIO_DMA ?= 0
USE_MONOLITHIC_ACC ?= 0
DO_FFT_IFFT_OFFLOAD ?= 0
EPOCHS_TARGET ?= 1

RISCV_CFLAGS += -DNUM_BLOCKS=$(NUM_BLOCKS)
RISCV_CFLAGS += -DBLOCK_SIZE=$(BLOCK_SIZE)
RISCV_CFLAGS += -DSAMPLERATE=$(SAMPLERATE)
RISCV_CFLAGS += -DNORDER=$(NORDER)
RISCV_CFLAGS += -DNUM_SRCS=$(NUM_SRCS)
RISCV_CFLAGS += -DCOH_MODE=$(COH_MODE)
RISCV_CFLAGS += -DIS_ESP=$(IS_ESP)
RISCV_CFLAGS += -DDO_CHAIN_OFFLOAD=$(DO_CHAIN_OFFLOAD)
RISCV_CFLAGS += -DDO_NP_CHAIN_OFFLOAD=$(DO_NP_CHAIN_OFFLOAD)
RISCV_CFLAGS += -DDO_PP_CHAIN_OFFLOAD=$(DO_PP_CHAIN_OFFLOAD)
RISCV_CFLAGS += -DUSE_INT=$(USE_INT)
RISCV_CFLAGS += -DUSE_REAL_DATA=$(USE_REAL_DATA)
RISCV_CFLAGS += -DDO_DATA_INIT=$(DO_DATA_INIT)
RISCV_CFLAGS += -DUSE_AUDIO_DMA=$(USE_AUDIO_DMA)
RISCV_CFLAGS += -DUSE_MONOLITHIC_ACC=$(USE_MONOLITHIC_ACC)
RISCV_CFLAGS += -DDO_FFT_IFFT_OFFLOAD=$(DO_FFT_IFFT_OFFLOAD)
RISCV_CFLAGS += -DEPOCHS_TARGET=$(EPOCHS_TARGET)

RISCV_CPPFLAGS += $(RISCV_CFLAGS)
RISCV_CFLAGS += -std=gnu99

AUDIO_SRCS = \
	$(AUDIO_PIPELINE)/AudioBase.cpp \
	$(AUDIO_PIPELINE)/BFormat.cpp \
	$(AUDIO_PIPELINE)/AmbisonicBinauralizer.cpp \
	$(AUDIO_PIPELINE)/AmbisonicProcessor.cpp \
	$(AUDIO_PIPELINE)/AmbisonicZoomer.cpp \
	$(AUDIO_PIPELINE)/audio.cpp \
	$(AUDIO_PIPELINE)/kiss_fft.cpp \
	$(AUDIO_PIPELINE)/kiss_fftr.cpp \
	$(AUDIO_PIPELINE)/DMAAcc.cpp \
	$(AUDIO_PIPELINE)/FFTAcc.cpp \
	$(AUDIO_PIPELINE)/FIRAcc.cpp \
	$(AUDIO_PIPELINE)/FFIAcc.cpp \
	$(AUDIO_PIPELINE)/FFIChain.cpp

MINI_ERA_SRCS = \
	$(MINI_ERA)/read_trace.c \
	$(MINI_ERA)/calculate_dist_from_fmcw.c \
	$(MINI_ERA)/fft.c \
	$(MINI_ERA)/kernels_api.c 


# Compile utility functions for mini-era
$(AUDIO_ERA_BUILD)/read_trace.o: $(AUDIO_ERA)/src/mini-era/read_trace.c
	@mkdir -p $(AUDIO_ERA_BUILD)
	$(QUIET_CC) $(CROSS_COMPILE_ELF)gcc $(RISCV_CFLAGS) \
		-O2 \
		-Wall -Werror \
		-mcmodel=medany -mexplicit-relocs $(SPX_CFLAGS) \
		-I$(AUDIO_ERA)/include/mini-era \
		-I$(BOOTROM_PATH) \
		-I$(DESIGN_PATH)/$(ESP_CFG_BUILD) \
		-c $< -o $@

$(AUDIO_ERA_BUILD)/calculate_dist_from_fmcw.o: $(AUDIO_ERA)/src/mini-era/calculate_dist_from_fmcw.c
	@mkdir -p $(AUDIO_ERA_BUILD)
	$(QUIET_CC) $(CROSS_COMPILE_ELF)gcc $(RISCV_CFLAGS) \
		-O2 \
		-mcmodel=medany -mexplicit-relocs $(SPX_CFLAGS) \
		-I$(AUDIO_ERA)/include/mini-era \
		-I$(BOOTROM_PATH) \
		-I$(DESIGN_PATH)/$(ESP_CFG_BUILD) \
		-c $< -o $@

$(AUDIO_ERA_BUILD)/fft.o: $(AUDIO_ERA)/src/mini-era/fft.c
	@mkdir -p $(AUDIO_ERA_BUILD)
	$(QUIET_CC) $(CROSS_COMPILE_ELF)gcc $(RISCV_CFLAGS) \
		-O2 \
		-mcmodel=medany -mexplicit-relocs $(SPX_CFLAGS) \
		-I$(AUDIO_ERA)/include/mini-era \
		-I$(BOOTROM_PATH) \
		-I$(DESIGN_PATH)/$(ESP_CFG_BUILD) \
		-c $< -o $@

$(AUDIO_ERA_BUILD)/kernels_api.o: $(AUDIO_ERA)/src/mini-era/kernels_api.c
	@mkdir -p $(AUDIO_ERA_BUILD)
	$(QUIET_CC) $(CROSS_COMPILE_ELF)gcc $(RISCV_CFLAGS) \
		-O2 \
		-mcmodel=medany -mexplicit-relocs $(SPX_CFLAGS) \
		-I$(AUDIO_ERA)/include/mini-era \
		-I$(BOOTROM_PATH) \
		-I$(DESIGN_PATH)/$(ESP_CFG_BUILD) \
		-c $< -o $@

$(AUDIO_ERA_BUILD)/get_counter.o: $(AUDIO_ERA)/src/mini-era/get_counter.c
	@mkdir -p $(AUDIO_ERA_BUILD)
	$(QUIET_CC) $(CROSS_COMPILE_ELF)gcc \
		-O2 \
		-mcmodel=medany -mexplicit-relocs $(SPX_CFLAGS) \
		-I$(AUDIO_ERA)/include/mini-era \
		-I$(BOOTROM_PATH) \
		-I$(DESIGN_PATH)/$(ESP_CFG_BUILD) \
		-c $< -o $@

$(AUDIO_ERA_BUILD)/descrambler_function.o: $(AUDIO_ERA)/src/mini-era/descrambler_function.c
	@mkdir -p $(AUDIO_ERA_BUILD)
	$(QUIET_CC) $(CROSS_COMPILE_ELF)gcc \
		-O2 \
		-mcmodel=medany -mexplicit-relocs $(SPX_CFLAGS) \
		-I$(AUDIO_ERA)/include/mini-era \
		-I$(BOOTROM_PATH) \
		-I$(DESIGN_PATH)/$(ESP_CFG_BUILD) \
		-c $< -o $@

$(AUDIO_ERA_BUILD)/viterbi_parms.o: $(AUDIO_ERA)/src/mini-era/viterbi_parms.c
	@mkdir -p $(AUDIO_ERA_BUILD)
	$(QUIET_CC) $(CROSS_COMPILE_ELF)gcc \
		-O2 \
		-mcmodel=medany -mexplicit-relocs $(SPX_CFLAGS) \
		-I$(AUDIO_ERA)/include/mini-era \
		-I$(BOOTROM_PATH) \
		-I$(DESIGN_PATH)/$(ESP_CFG_BUILD) \
		-c $< -o $@

$(AUDIO_ERA_BUILD)/viterbi_flat.o: $(AUDIO_ERA)/src/mini-era/viterbi_flat.c
	@mkdir -p $(AUDIO_ERA_BUILD)
	$(QUIET_CC) $(CROSS_COMPILE_ELF)gcc \
		-O2 \
		-mcmodel=medany -mexplicit-relocs $(SPX_CFLAGS) \
		-I$(AUDIO_ERA)/include/mini-era \
		-I$(BOOTROM_PATH) \
		-I$(DESIGN_PATH)/$(ESP_CFG_BUILD) \
		-c $< -o $@

OBJ =	$(AUDIO_ERA_BUILD)/read_trace.o \
		$(AUDIO_ERA_BUILD)/calculate_dist_from_fmcw.o \
		$(AUDIO_ERA_BUILD)/fft.o \
		$(AUDIO_ERA_BUILD)/kernels_api.o \
		$(AUDIO_ERA_BUILD)/get_counter.o \
		$(AUDIO_ERA_BUILD)/descrambler_function.o \
		$(AUDIO_ERA_BUILD)/viterbi_parms.o \
		$(AUDIO_ERA_BUILD)/viterbi_flat.o

$(AUDIO_ERA_BUILD)/audio_era.exe: $(AUDIO_ERA)/src/main.cpp $(AUDIO_SRCS) $(OBJ) $(AUDIO_ERA_BUILD)/uart.o
	@mkdir -p $(AUDIO_ERA_BUILD)
	$(QUIET_CC) $(CROSS_COMPILE_ELF)gcc $(RISCV_CPPFLAGS) $(ADDN_RISCV_CFLAGS) $(SPX_CFLAGS) \
	$(MINI_ERA)/crt.S  \
	$(SOFT)/common/syscalls.c \
	-T $(RISCV_TESTS)/benchmarks/common/test.ld -o $@ \
	$(OBJ) \
	$(AUDIO_ERA_BUILD)/uart.o $(AUDIO_SRCS) $(AUDIO_ERA)/src/main.cpp \
	$(SOFT_BUILD)/drivers/probe/libprobe.a \
	$(SOFT_BUILD)/drivers/utils/baremetal/libutils.a

$(AUDIO_ERA_BUILD)/audio_era.bin: $(AUDIO_ERA_BUILD)/audio_era.exe
	@mkdir -p $(AUDIO_ERA_BUILD)
	$(QUIET_OBJCP) riscv64-unknown-elf-objcopy -O binary $(AUDIO_ERA_BUILD)/audio_era.exe $@
	@cp $(AUDIO_ERA_BUILD)/audio_era.bin $(SOFT_BUILD)/systest.bin

$(AUDIO_ERA_BUILD)/ram.srec: $(AUDIO_ERA_BUILD)/audio_era.exe
	@mkdir -p $(AUDIO_ERA_BUILD)
	$(QUIET_OBJCP) riscv64-unknown-elf-objcopy -O srec --gap-fill 0 $< $@
	@cp $(AUDIO_ERA_BUILD)/ram.srec $(SOFT_BUILD)/ram.srec

fpga-run-audio-era: esplink audio-era
	@./$(ESP_CFG_BUILD)/esplink --reset
	@./$(ESP_CFG_BUILD)/esplink --brom -i $(SOFT_BUILD)/prom.bin
	@./$(ESP_CFG_BUILD)/esplink --dram -i $(SOFT_BUILD)/systest.bin
	@./$(ESP_CFG_BUILD)/esplink --reset

xmsim-compile-audio-era: socketgen check_all_srcs audio-era xcelium/xmready xcelium/xmsim.in
	$(QUIET_MAKE) \
	cd xcelium; \
	rm -f prom.srec ram.srec; \
	ln -s $(SOFT_BUILD)/prom.srec; \
	ln -s $(SOFT_BUILD)/ram.srec; \
	echo $(SPACES)"$(XMUPDATE) $(SIMTOP)"; \
	$(XMUPDATE) $(SIMTOP);

xmsim-audio-era: xmsim-compile-audio-era
	@cd xcelium; \
	echo $(SPACES)"$(XMSIM)"; \
	$(XMSIM); \
	cd ../

xmsim-gui-audio-era: xmsim-compile-audio-era
	@cd xcelium; \
	echo $(SPACES)"$(XMSIM) -gui"; \
	$(XMSIM) -gui; \
	cd ../
