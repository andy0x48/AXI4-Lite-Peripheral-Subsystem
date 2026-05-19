# tooling
VENV 	:= source .venv/bin/activate &&
VERL	:= verilator
IV 		:= iverilog
VVP		:= vvp
SBY		:= sby

IFLAGS	:= -g2012 -Wall
VFLAGS	:= --lint-only -Wall -Wno-UNUSEDSIGNAL

# include path
INCL	:= -Irtl -Itb/common -Itb/interfaces

# build path
WORK	:= work
SIM		:= $(WORK)/sim.vvp

# rtl sources
RTL			:= $(wildcard rtl/*.sv)
TOP			:= axi_periph_top

# testbench sources
TB_COMMON	:= $(wildcard tb/common/*.sv)
TB_IF		:= $(wildcard tb/interfaces/*.sv)
TB_UVM		:= $(wildcard tb/uvm/*.sv)

# select directed
TEST 		?= uart			# default
TB_DIRECT	= tb/$(TEST)_tb/tb_$(TEST)_directed.sv

# sim source set (icarus safe)
SIM_SET	= $(RTL) $(TB_COMMON) $(TB_DIRECT)

# full source set (verilator)
FULL_SET 	= $(RTL) $(TB_COMMON) $(TB_IF) $(TB_DIRECT)

# register generation path
# REGS_YAML	:= scripts/reggen/regs.yaml
# REG_SV_OUT	:= tb/uart_tb/uart_reg_model.sv
# REG_H_OUT	:= sw/drivers/generated/periph_regs.h

# formal path
# SBY		:= $(wildcard formal/*.sby)

# ================================================ #

# default
.PHONY: all
all: lint

# sanity check (local only)
.PHONY: sanity
sanity:
	@echo ">>> SANITY: Syntax check (Icarus)..."
	@$(IV) $(IFLAGS) $(INCL) -tnull $(RTL)
	@echo ">>> SANITY: OK!"


# strict check
.PHONY: lint
lint:
	@echo ">>> LINT: RTL Verilator ($(TOP))..."
	@$(VERL) $(VFLAGS) $(INCL) \
		--top-module $(TOP) \
		$(RTL)
	@echo ">>> LINT: OK!"

# build simulation
$(SIM): $(SIM_SET)
	@mkdir -p $(WORK)
	@echo ">>> SIM: Compiling ($(TEST))..."
	$(IV) $(FLAGS) $(INCL) -o $(SIM) \
		$(SIM_SET)

# run simulation
.PHONY: sim
sim: $(SIM)
	@echo ">>> SIM: Running ($(TEST))..."
	@$(VVP) $(SIM)

# formal verif
# .PHONY: formal
# formal:
# 	@echo ">>> FORMAL: Running SymbiYosys..."
# 	@for f in formal/*.sby; do \
# 		echo "	>> $$f"; \
# 		$(SBY) -f $$f || exit 1; \
# 	done
# 	@echo ">>> FORMAL: OK!"

# script: register generation
# REGS_YAML	:= scripts/reggen/regs.yaml
# REG_SV_OUT	:= tb/uart/generated/periph_regs.h
# REG_H_OUT	:= sw/drivers/generated/periph_regs.h
#
# .PHONY: reggen
# reggen: $(REG_SV_OUT) $(REG_H_OUT)
#
# $(REG_SV_OUT) $(REG_H_OUT): $(REGS_YAML)
# 	@echo ">>> REGGEN: Generating from $(REGS_YAML)..."
# 	@mkdir -p sw/drivers/generated
# 	@$(VENV) python3 scripts/reggen/gen_ral.py
# 	@$(VENV) python3 scripts/reggen/gen_c_header.py
# 	@$(VENV) python3 scripts/reggen/gen_sine_lut.py
# 	@echo ">>> REGGEN: OK!"

# regression
.PHONY: regression
regression:
	@echo ">>> REGRESSION: Running..."
	$(VENV) python3 scripts/regression/regression.py --sim icarus
	@echo ">>> REGRESSION: OK!"

# cleanup
.PHONY: clean
clean:
	rm -rf $(WORK)
	rm -f *.vvp *.vcd
	rm -rf __pycache__ */__pycache__
	rm -rf *_bmc/ *_prove/
	@echo ">>> CLEAN: DONE!"
#
