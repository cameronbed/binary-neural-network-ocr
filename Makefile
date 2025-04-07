# Vivado Paths
VIVADO := "C:/Xilinx/Vivado/2024.2/bin/vivado.bat"
VIVADO_BIN := "C:/Xilinx/Vivado/2024.2/bin"

# HDL sources
HDL_SRC := src/fpga/blinky.v

# Testbench C++ files
TEST_CPP := tests/blinky_tb.cpp

# Testbench HDL files
SIM_TOP := blinky_tb
SIM_SRC := $(HDL_SRC) tests/blinky_tb.v

# Verilator config
VERILATOR := verilator
BUILD_DIR := build

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

.PHONY: bitstream flash
bitstream:
	@echo "==> Synthesizing and generating bitstream..."
	$(VIVADO) -mode batch -source scripts/run_vivado.tcl

flash: bitstream
	@echo "==> Programming Basys3 board..."
	$(VIVADO) -mode batch -source scripts/flash_vivado.tcl

.PHONY: clean
clean:
	@echo "==> Cleaning build files..."
	rm -rf $(BUILD_DIR) work xsim.dir *.log *.jou *.wdb

.PHONY: sim wave
sim:
	@echo "▶ Simulating with Vivado..."
	mkdir -p build work
	$(VIVADO_BIN)/xvlog --nolog --incr --work work $(SIM_SRC)
	$(VIVADO_BIN)/xelab --nolog $(SIM_TOP) -s sim_out
	$(VIVADO_BIN)/xsim sim_out --runall --tclbatch scripts/run_wave.tcl

wave:
	gtkwave build/blinky_tb.vcd &

.PHONY: configure
configure:
	@echo "⚙️  Configuring CMake..."
	cmake -S . -B $(BUILD_DIR)

.PHONY: test
test: clean configure
ifndef TEST
	$(error ❌ You must provide TEST=<test_name> (e.g. make test TEST=blinky_tb))
endif
	@echo "Building and running test: $(TEST)"
	cmake --build $(BUILD_DIR) --target run_$(TEST)
	ctest --test-dir $(BUILD_DIR) -R ^$(TEST) --output-on-failure
