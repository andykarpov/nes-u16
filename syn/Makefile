###################################################################
# ReVerSE U16 Project Makefile v1.0
# 
# Specify the basename of the design (project) and top level entity
###################################################################

PROJECT = u16_nes
TOP_LEVEL_ENTITY = NES_u16

###################################################################
# Part, Family, Boardfile revA or revC, Flash loader device, etc

FAMILY = "Cyclone IV E"
PART = EP4CE22E22C8
FLASH_CONFIG = EPCS16
FLASH_LOADER = EP4CE22
BOARDFILE = revC

###################################################################
# Sources

SRCS = ../rtl/hdmi/serializer.vhd \
	../rtl/hdmi/hdmidelay.vhd \
	../rtl/hdmi/hdmidataencoder.v \
	../rtl/hdmi/encoder.vhd \
	../rtl/hdmi/av_hdmi.vhd \
	../rtl/memory/ram.vhd \
	../rtl/cpu/nz80cpu.vhd \
	../rtl/keyboard/receiver.vhd \
	../rtl/spi/spi.vhd \
	../rtl/sigma_delta_dac.v \
	../rtl/sdram.v \
	../rtl/NES_u16.v \
	../rtl/clk.v \
	../src/vga.v \
	../src/ppu.v \
	../src/nes.v \
	../src/mmu.v \
	../src/MicroCode.v \
	../src/hq2x.v \
	../src/dsp.v \
	../src/cpu.v \
	../src/compat.v \
	../src/apu.v \
	../rtl/osd/osd.vhd \
	../rtl/keyboard/hid.vhd \

# ROMs in reverse order
ROMS = ../rtl/loader/games/SuperMario3.hex \
	../rtl/loader/games/1943.hex \
	../rtl/loader/games/1942.hex \
	../rtl/loader/games/Robocop.hex \
	../rtl/loader/games/Airwolf.hex \
	../rtl/loader/games/Arkanoid.hex \
	../rtl/loader/games/Puzznic.hex \
	../rtl/loader/games/PacMan.hex \
	../rtl/loader/games/LodeRunner.hex \
	../rtl/loader/games/BattleTank.hex \
	../rtl/loader/games/Bomberman.hex \
	../rtl/loader/games/SuperMario.hex \


###################################################################
# Additional variables

QUARTUS_HOME := $(shell dirname `which quartus_pgm`)
PWD := $(shell pwd)
ASSIGNMENT_FILES = $(PROJECT)_$(BOARDFILE).qpf $(PROJECT)_$(BOARDFILE).qsf
SJASMPLUS_BIN := $(shell `which sjasmplus`)
BIN2HEX_BIN := $(shell `which bin2hex`)
CAT      := $(shell which cat)

###################################################################
# COF file contents
define newline


endef

define COF
<?xml version="1.0" encoding="US-ASCII" standalone="yes"?>
<cof>
	<eprom_name>$(FLASH_CONFIG)</eprom_name>
	<flash_loader_device>$(FLASH_LOADER)</flash_loader_device>
	<output_filename>$(PROJECT)_$(BOARDFILE).jic</output_filename>
	<n_pages>1</n_pages>
	<width>1</width>
	<mode>7</mode>
	$(foreach ROM, $(ROMS),
	<hex_block>
		<hex_filename>$(ROM)</hex_filename>
		<hex_addressing>relative</hex_addressing>
		<hex_offset>0</hex_offset>
	</hex_block>
	)
	<sof_data>
		<start_address>00000000</start_address>
		<user_name>Page_0</user_name>
		<page_flags>1</page_flags>
		<bit0>
			<sof_filename>$(PROJECT)_$(BOARDFILE).sof</sof_filename>
		</bit0>
	</sof_data>
	<version>9</version>
	<create_cvp_file>0</create_cvp_file>
	<auto_create_rpd>0</auto_create_rpd>
	<create_hps_iocsr>0</create_hps_iocsr>
	<create_fif_file>0</create_fif_file>
	<options>
		<map_file>1</map_file>
	</options>
	<advanced_options>
		<ignore_epcs_id_check>0</ignore_epcs_id_check>
		<ignore_condone_check>2</ignore_condone_check>
		<plc_adjustment>0</plc_adjustment>
		<post_chain_bitstream_pad_bytes>-1</post_chain_bitstream_pad_bytes>
		<post_device_bitstream_pad_bytes>-1</post_device_bitstream_pad_bytes>
		<bitslice_pre_padding>1</bitslice_pre_padding>
	</advanced_options>
</cof>
endef
export COF

define CDF
/* Quartus CDF */
JedecChain;
        FileRevision(JESD32A);
        DefaultMfr(6E);

        P ActionCode(Cfg)
                Device PartName($(FLASH_LOADER)) Path("$(PWD)/") File("$(PROJECT)_$(BOARDFILE).jic") MfrSpec(OpMask(1) SEC_Device($(FLASH_CONFIG)) Child_OpMask(1 1));

ChainEnd;

AlteraBegin;
        ChainType(JTAG);
AlteraEnd;
endef
export CDF

###################################################################
# Main Targets
#
# all: build everything
# clean: remove output files and database
# program: program your device with the compiled design
###################################################################

all: smart.log $(PROJECT)_$(BOARDFILE).asm.rpt $(PROJECT)_$(BOARDFILE).sta.rpt $(PROJECT)_$(BOARDFILE).cof

clean: 
	rm -rf *.rpt 
	rm -rf *.chg 
	rm -rf smart.log 
	rm -rf *.htm 
	rm -rf *.eqn 
	rm -rf *.pin 
	rm -rf *.sof 
	rm -rf *.pof 
	rm -rf *.jic 
	rm -rf db 
	rm -rf incremental_db
	rm -rf *.qsf
	rm -rf *.qpf
	rm -rf *.summary
	rm -rf *.smsg
	rm -rf *.cof
	rm -rf *.cdf
	rm -rf *.jdi
	rm -rf *.map
	rm -rf *.sld
	rm -rf PLLJ_PLLSPE_INFO.txt

map: smart.log $(PROJECT)_$(BOARDFILE).map.rpt
fit: smart.log $(PROJECT)_$(BOARDFILE).fit.rpt
asm: smart.log $(PROJECT)_$(BOARDFILE).asm.rpt
sta: smart.log $(PROJECT)_$(BOARDFILE).sta.rpt
smart: smart.log

###################################################################
# Executable Configuration
###################################################################

MAP_ARGS = --read_settings_files=on $(addprefix --source=,$(SRCS))

FIT_ARGS = --part=$(PART) --read_settings_files=on
ASM_ARGS =
STA_ARGS =

###################################################################
# Target implementations
###################################################################

STAMP = echo done >

$(PROJECT)_$(BOARDFILE).map.rpt: map.chg $(SOURCE_FILES) 
	quartus_map $(MAP_ARGS) $(PROJECT)_$(BOARDFILE)
	$(STAMP) fit.chg

$(PROJECT)_$(BOARDFILE).fit.rpt: fit.chg $(PROJECT)_$(BOARDFILE).map.rpt
	quartus_fit $(FIT_ARGS) $(PROJECT)_$(BOARDFILE)
	$(STAMP) asm.chg
	$(STAMP) sta.chg

$(PROJECT)_$(BOARDFILE).asm.rpt: asm.chg $(PROJECT)_$(BOARDFILE).fit.rpt
	quartus_asm $(ASM_ARGS) $(PROJECT)_$(BOARDFILE)

$(PROJECT)_$(BOARDFILE).sta.rpt: sta.chg $(PROJECT)_$(BOARDFILE).fit.rpt
	quartus_sta $(STA_ARGS) $(PROJECT)_$(BOARDFILE) 

smart.log: $(ASSIGNMENT_FILES)
	quartus_sh --determine_smart_action $(PROJECT)_$(BOARDFILE) > smart.log

###################################################################
# Project initialization
###################################################################

$(ASSIGNMENT_FILES):
	echo "$$COF" > $(PROJECT)_$(BOARDFILE).cof
	echo "$$CDF" > $(PROJECT)_$(BOARDFILE).cdf
	quartus_sh --prepare -f $(FAMILY) -t $(TOP_LEVEL_ENTITY) $(PROJECT)_$(BOARDFILE) 
	-cat $(BOARDFILE) >> $(PROJECT)_$(BOARDFILE).qsf
map.chg:
	$(STAMP) map.chg
fit.chg:
	$(STAMP) fit.chg
sta.chg:
	$(STAMP) sta.chg
asm.chg:
	$(STAMP) asm.chg

###################################################################
# Generate jic file
###################################################################

jic: $(PROJECT)_$(BOARDFILE).cof 
	quartus_cpf -c "$(PROJECT)_$(BOARDFILE).cof"

###################################################################
# Programming the device
###################################################################

programsof: $(PROJECT)_$(BOARDFILE).sof
	quartus_pgm --no_banner --mode=jtag -o "P;$(PROJECT)_$(BOARDFILE).sof"

program: $(PROJECT)_$(BOARDFILE).cdf
	quartus_pgm --no_banner "$(PROJECT)_$(BOARDFILE).cdf"

