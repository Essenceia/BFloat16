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
CONF := conf
DEBUG_FLAG := $(if $(debug), debug=1)
DEFINES := $(if $(wave),wave=1)
WAIVER_FILE := waiver.vlt
WAVE_DIR := waves
TOP := $(if $(top),$(top),b16_add)

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

# Cleanup
clean:
	rm -f vgcore.* vgd.log*
	rm -f callgrind.out.*
	rm -fr $(WAVE_DIR)/*
	$(MAKE) -C $(FPGA_DIR) clean

