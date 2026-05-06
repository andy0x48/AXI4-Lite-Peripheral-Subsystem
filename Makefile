# tooling
VENV 	:= .venv/bin/python3
VERL	:= verilator
IV 		:= iverilog
FLAGS	:= -g2012 -Wall
VVP		:= vvp
SBY		:= sby

# include path
INCL	:= -Irtl -Itb/common -Itb/interfaces

# sources
AXI_CORE 	:= rtl/axi4_lite_if.sv
AXI_XBAR	:= $(AXI_CORE) rtl/axi4_lite_xbar.sv
UART_RTL	:= $(AXI_CORE) rtl/axi_uart_ctrl.sv
GPIO_RTL	:= $(AXI_CORE) rtl/axi_gpio.sv
DDS_RTL		:= $(AXI_CORE) rtl/axi_dds.sv
ALL_RTL		:= $(wildcard rtl/*.sv)
TOP_RTL		:= rtl/axi_periph_top.sv

# testbench path
UART_TB		:= tb/common/axi4_lite_tasks.sv \
			   tb/uart_tb/tb_uart_directed.sv

# register generation path
REGS_YAML	:= scripts/reggen/regs.yaml
REG_SV_OUT	:= tb/uart_tb/uart_reg_model.sv
REG_H_OUT	:= sw/drivers/generated/periph_regs.h

# formal path
# SBY		:= $(wildcard formal/*.sby)

# ================================================ #

# default
.PHONY: all
all: sanity

# sanity (fast)
.PHONY: sanity
sanity:
	@if [ -z "$(ALL_RTL) " ]; then \
		echo ">>> SANITY [WARN]: No RTL files found; skipping!"; \
		exit 0; \
	fi
	@echo ">>> SANITY: Icarus syntax check..."
	@$(IV) $(FLAGS) $(INCL) -tnull $(ALL_RTL)
	@echo ">>> SANITY: OK!"


# strict
# .PHONY: lint
# lint:
# 	@echo ">>> LINT: RTL strict lint check..."
# 	@if [ -z "$(RTL) "]; then echo ">>> LINT [WARN]: No RTL source found; skipping!"; \
# 		exit 0; \
# 	fi
# 	@$(IV) $(FLAGS) -tnull $(RTL)
# 	@$(VERL) --lint-only -Wall --top-module $(TB_TOP) $(RTL)
# 	@echo ">>> LINT: OK!"

# simulation
# .PHONY: sim
# sim: $(SIM)
# 	@echo ">>> SIM: Running..."
# 	@$(VVP) $(SIM)
#
# $(SIM): $(RTL) $(TB_TOP)
# 	@if [ ! -f "$(TB_TOP)" ]; then \
# 		echo ">>> SIM [WARN]: No TB source found; skipping build!" \
# 		exit 0; \
# 	fi 
# 	@echo ">>> SIM: Compiling..."
# 	$(IV) $(FLAGS) -o $(SIM) $(RTL) $(TB_TOP)

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
	rm -rf work/
	rm -f *.vvp *.vcd
	rm -rf __pycache__ */__pycache__
	rm -rf *_bmc/ *_prove/
	@echo ">>> CLEAN: DONE!"
#
