VIVADO = "C:/Xilinx/Vivado/2024.2/bin/vivado.bat"
BUILD_DIR = build
BIT_FILE = $(BUILD_DIR)/blinky.bit
VIVADO_BIN = "C:/Xilinx/Vivado/2024.2/bin"
VIVADO_UNWRAPPED = /c/Xilinx/Vivado/2024.2/bin/unwrapped


.PHONY: all build flash clean

all: build flash

build:
	@echo "==> Synthesizing and generating bitstream..."
	$(VIVADO) -mode batch -source scripts/run_vivado.tcl

flash: $(BIT_FILE)
	@echo "==> Programming Basys3 board..."
	$(VIVADO) -mode batch -source scripts/flash_vivado.tcl

$(BIT_FILE): build

clean:
	@echo "==> Cleaning build files..."
	rm -rf $(BUILD_DIR)
	rm -rf work xsim.dir *.log *.jou *.wdb


SIM_BUILD = build
SIM_TOP = blinky_tb
SIM_SRC = src/fpga/blinky.v tests/blinky_tb.v
SIM_SNAPSHOT = sim_out

sim:
	@echo "==> Setting up simulation environment..."
	mkdir -p build work

	@echo "==> Compiling sources..."
	$(VIVADO_BIN)/xvlog --nolog --incr --work work $(SIM_SRC)

	@echo "==> Elaborating..."
	$(VIVADO_BIN)/xelab --nolog $(SIM_TOP) -s sim_out

	@echo "==> Running simulation..."
	$(VIVADO_BIN)/xsim sim_out --runall --tclbatch scripts/run_wave.tcl

wave:
	gtkwave build/blinky_tb.vcd &
