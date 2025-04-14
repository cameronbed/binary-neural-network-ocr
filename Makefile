# Vivado Paths
VIVADO := "C:/Xilinx/Vivado/2024.2/bin/vivado.bat"
VIVADO_BIN := "C:/Xilinx/Vivado/2024.2/bin"

# Verbose build option
VERBOSE=1

all:
	@echo "Running CMake build..."
	cmake -S . -B build
	cmake --build build

# Run the test with verbose output
test: all
	@echo "Running test..."
	@./build/bnn_controller_tb || (echo "Test failed. Check the logs above for details." && exit 1)

# Clean the build output
clean:
	@echo "Cleaning..."
	@rm -rf build

# ============== Vivado Targets ==============

# Synthesis and simulation targets
.PHONY: bitstream flash
bitstream:
	@echo "==> Synthesizing and generating bitstream..."
	$(VIVADO) -mode batch -source scripts/run_vivado.tcl

# Program the Basys3 board
flash: bitstream
	@echo "==> Programming Basys3 board..."
	$(VIVADO) -mode batch -source scripts/flash_vivado.tcl
