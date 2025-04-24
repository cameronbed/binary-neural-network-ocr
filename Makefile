# Vivado Paths
VIVADO := /mnt/c/Xilinx/Vivado/2024.2/bin/vivado.bat

WIN_PWD := $(shell wslpath -w $(shell pwd))

VIVADO_BATCH := cmd.exe /c $(WIN_PWD)\$(notdir $(VIVADO))

# Verbose build option
VERBOSE=1

all:
	@echo "Running CMake build..."
	cmake -S . -B build
	cmake --build build

# Run the test with verbose output
test: all
	@echo "Running test..."
	@./build/main_test || (echo "Test failed. Check the logs above for details." && exit 1)

# Clean the build output
clean:
	@echo "Cleaning..."
	@rm -rf build

# ============== Vivado Targets ==============

# Synthesis and simulation targets
.PHONY: bitstream flash
bitstream:
	@echo "==> Synthesizing and generating bitstream..."
	@cd $(WIN_PWD) && cmd.exe /c $(VIVADO) -mode batch -source scripts/run_vivado.tcl
	
# Program the Basys3 board
flash: bitstream
	@echo "==> Programming Basys3 board..."
	@cd $(WIN_PWD) && cmd.exe /c $(VIVADO) -mode batch -source scripts/flash_vivado.tcl