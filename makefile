###########
# Configs #
###########

ifndef debug
debug :=
endif

ifndef wireshark
wireshark:=
endif

# Enable waves by default
ifndef wave
wave:=1
endif

# Coverage, enabled by default
ifndef cov
cov:=1
endif

# Asserts, enabled by default
ifndef assert
assert:=1
endif

############
# Sim type #
############

# Define simulator we are using, priority to iverilog
SIM ?= verilator
$(info Using simulator: $(SIM))

###########
# Globals #
###########

# Global configs.
SRC_DIR := src
TB_DIR := tb
CONF := conf
DEBUG_FLAG := $(if $(debug), debug=1)
DEFINES := $(if $(wave),wave=1)
WAIVER_FILE := waiver.vlt
WAVE_DIR := wave
TOP := $(if $(top),$(top),bf16_add)

.PHONY: lint

########
# Lint #
########

# Lint variables.
LINT_FLAGS :=
ifeq ($(SIM),icarus)
LINT_FLAGS +=-Wall -g2012 $(if $(assert),-gassertions) -gstrict-expr-width
LINT_FLAGS +=$(if $(debug),-DDEBUG) 
else
LINT_FLAGS += -Wall -Wpedantic -Wno-GENUNNAMED -Wno-LATCH -Wno-IMPLICIT
LINT_FLAGS += -Wno-DECLFILENAME
LINT_FLAGS +=$(if $(wip),-Wno-UNUSEDSIGNAL)
LINT_FLAGS += -Ilib
endif

# Lint commands.
ifeq ($(SIM),icarus)
define LINT
	mkdir -p build
	iverilog $(LINT_FLAGS) -s $2 -o $(BUILD_DIR)/$2 $1
endef
else
	
define LINT
	mkdir -p build
	verilator $(CONF)/$(WAIVER_FILE) --lint-only $(LINT_FLAGS) --no-timing $1 --top $2
endef
endif

########
# Lint #
########

entry_deps := $(wildcard $(SRC_DIR)/*.v)

$(info Top set to: $(TOP))

lint: $(entry_deps)
	$(call LINT,$^,$(TOP))

###############
# Build flags #
###############

# Build variables.
ifeq ($(SIM),I)
BUILD_DIR := build
BUILD_FLAGS := $(if $(wave),-DWAVE)  
BUILD_FLAGS += $(if $(assert),,-DINTERACTIVE)  
else
BUILD_DIR := obj_dir
BUILD_FLAGS := 
BUILD_FLAGS += $(if $(assert),--assert)
BUILD_FLAGS += $(if $(wave), --trace --trace-underscore) 
BUILD_FLAGS += $(if $(cov), --coverage --coverage-underscore) 
BUILD_FLAGS += --timing
BUILD_FLAGS += --x-initial-edge
MAKE_THREADS = 4 
BUILD_FLAGS += -j $(MAKE_THREADS)
endif


#########
# Build #
#########

# Build commands.
ifeq ($(SIM),I)
define BUILD
	mkdir -p $(BUILD_DIR)
	mkdir -p $(WAIVER_FILE)
	iverilog $(LINT_FLAGS) -s $2 $(BUILD_FLAGS) -o $(BUILD_DIR)/$2 $1
endef
else
define BUILD
	mkdir -p $(BUILD_DIR)
	mkdir -p $(WAIVER_FILE)
	verilator --binary $(LINT_FLAGS) -j 0 $(BUILD_FLAGS) -o $2 $1  
endef
endif

#######
# Run #
#######

# Run commands.
ifeq ($(SIM),I)
define RUN
	vvp $(BUILD_DIR)/$1
endef
define RUN_VPI
	vvp -M $(VPI_DIR)/$(BUILD_VPI_DIR) -mtb $(BUILD_DIR)/$1
endef
else
define RUN
	./$(BUILD_DIR)/$1 $(if $(wave),+trace) 
endef
define RUN_VPI
	$(call RUN,$1)
endef
endif


#############
# Testbench #
#############

# The list of testbenches.
tbs := lzc bf16_add

# Dependencies for each testbench
lzc_deps += $(TB_DIR)/lzc_tb.sv $(SRC_DIR)/lzc.v
bf16_add_deps += $(TB_DIR)/bf16_add_tb.sv $(SRC_DIR)/lzc.v $(SRC_DIR)/bf16_add.v

# Standard run recipe to build a given testbench
define build_recipe
$1_tb: $$($(1)_deps)
	$$(call BUILD,$$^,$$@)

endef

# Standard run recipe to run a given testbench
define run_recipe
run_$1: $1_tb
	$$(call RUN,$$^)

endef

# Generate run recipes for each testbench.
$(eval $(foreach x,$(tbs),$(call run_recipe,$x)))


# Generate build recipes for each testbench.
$(eval $(foreach x,$(tbs),$(call build_recipe,$x)))


# Cleanup
clean:
	rm -f vgcore.* vgd.log*
	rm -f callgrind.out.*
	rm -fr $(WAVE_DIR)/*
	rm -fr build/*
	rm -fr obj_dir/*
	$(MAKE) -C $(FPGA_DIR) clean#
