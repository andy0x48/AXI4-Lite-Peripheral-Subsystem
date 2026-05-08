# tooling
VENV 	:= .venv/bin/python3
VERL	:= verilator
IV 		:= iverilog
FLAGS	:= -g2012 -Wall
VVP		:= vvp
SBY		:= sby

# include path
INCL	:= -Irtl -Itb/common -Itb/interfaces

# build path
WORK	:= work
SIM		:= $(WORK)/sim.vvp

# sources
RTL			:= $(wildcard rtl/*.sv)
TOP			:= axi_periph_top

# testbench path
TB_COMMON	:= $(wildcard tb/common/*.sv)
TB_IF		:= $(wildcard tb/interfaces/*.sv)
TB_UVM		:= $(wildcard tb/uvm/*.sv)

# select directed
TEST 		?= uart
TB_DIRECT	= tb/$(TEST)_tb/tb_$(TEST)_directed.sv

# sanity source set (icarus only)
SANITY_SET	= $(RTL) $(TB_COMMON) $(TB_DIRECT)

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
all: sanity

# sanity check (fast)
.PHONY: sanity
sanity:
	@echo ">>> SANITY: Syntax check (Icarus)..."
	@$(IV) $(FLAGS) $(INCL) -tnull $(SANITY_SET)
	@echo ">>> SANITY: OK!"


# strict check
.PHONY: lint
lint:
	@echo ">>> LINT: RTL strict lint check (Verilator)..."
	@$(VERL) --lint-only \
		-Wall \
		--top-module $(TOP) \
		$(RTL)
	@echo ">>> LINT: OK!"

# build simulation
$(SIM): $(SANITY_SET)
	@mkdir -p $(WORK)
	@echo ">>> SIM: Compiling ($(TEST))..."
	$(IV) $(FLAGS) $(INCL) -o $(SIM) \
		$(SANITY_SET)

# run simulation
.PHONY: sim
sim: $(SIM)
	@echo ">>> SIM: Running ($(TEST))..."
	@$(VVP) $(SIM)

# formal verif
# .PHONY: formal
# formal:
# 	@if [ -z "$(SBY) "]; then \
# 		echo ">>> FORMAL [WARN]: No .sby source(s) found; skipping!"; \
# 		exit 0; 
# 	fi
# 	@for f in $(SBY); do \
# 		echo ">>> FORMAL: $$f"; \
# 		$(SBY) -f $$f; \
# 	done

# script: register generation
# .PHONY: reggen
# reggen:
# 	@if [ ! -f "scripts/reggen/regs.yaml" ]; then \
# 		echo ">>> REGGEN [WARN]: missing regs.yaml; skipping!"; \
# 		exit 0; \
# 	fi
# 	@echo ">>> REGGEN: Running..."
# 	@$(VENV) scripts/reggen/gen_ral.py
# 	@$(VENV) scripts/reggen/gen_c_header.py
# 	@$(VENV) scripts/reggen/gen_sine_lut.py

# regression
# .PHONY: regression
# regression:
# 	@if [ ! -f "scripts/mutagen/run_mutagen.py" ]; then \
# 		@echo ">>> REGRESSION [WARN]: Not ready for staging; skipping!"; \
# 		exit 0; \
# 	fi
# 	@echo ">>> REGRESSION: Running..."
# 	$(VENV) scripts/mutagen/run_mutagen.py

# cleanup
.PHONY: clean
clean:
	rm -rf $(WORK)
	rm -f *.vvp *.vcd
	rm -rf __pycache__ */__pycache__
	rm -rf *_bmc/ *_prove/
	@echo ">>> CLEAN: DONE!"
#
