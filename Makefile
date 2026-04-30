# paths
VENV 		:= .venv/bin/python3
IVERILOG 	:= iverilog
VVP			:= vvp
SBY			:= sby

RTL_SRC		:= $(wildcard rtl/*.sv)
TB_TOP		:= tb/uart_tb/tb_top.sv

# default
.PHONY: all
all: lint

# lint
.PHONY: lint
lint:
	@echo ">>> LINT: QUICK RTL CHECK..."
	$(VERILOG) -g2012 -tnull $(RTL_SRC)
	@echo ">>> LINT: OK!"

# simulation
.PHONY: sim
sim:
	@if [ ! -f "$(TB_TOP)" ]; then \
		echo ">>> SIM [WARN]: No TB found... SKIPPING..."; \
		exit 0; \
	fi
	@echo ">>> SIM: COMPILING..."
	$(IVERILOG) -g2012 -o sim.vvp $(RTL_SRC) $(TB_TOP)
	@echo ">>> SIM: RUNNING SIMULATION..."
	$(VVP) sim.vvp

# formal verif
.PHONY: formal
formal:
	@echo ">>> FORMAL: RUNNING FORMAL CHECK..."
	$(SBY) -f formal/uart.sby
	$(SBY) -f formal/gpio.sby
	$(SBY) -f formal/dds.sby

# code gen
.PHONY: regen
regen:
	@echo ">>> REGEN: RAL and C headers from regs.yaml ..."
	$(VENV) scripts/reggen/gen_ral.py
	$(VENV) scripts/reggen/gen_c_header.py
	$(VENV) scripts/reggen/gen_sine_lut.py
	@echo ">>> REGEN: DONE!"

# regression
.PHONY: regression
regression:
	@echo ">>> RGN: RUNNING FULL REGRESSION..."
	$(VENV) scripts/mutagen/run_mutagen.py

# cleanup
.PHONY: clean
clean:
	rm -f sim.vvp *.vcd *.vvp
	rm -rf __pycache__ */__pycache__
	rm -rf *_bmc/ *_prove/
	@echo ">>> CLEAN: DONE!"
#
