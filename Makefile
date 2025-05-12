# -------------------------------------------------------------------
# Paths & tools
# -------------------------------------------------------------------
VIVADO      := C:/Xilinx/Vivado/2024.2/bin/vivado.bat
VIVADO_BIN  := C:/Xilinx/Vivado/2024.2/bin

INCLUDE_DIRS := -Isrc/fpga -Isrc/fpga/bnn_module -Itests

VERILATOR   := verilator
VERILATOR_FLAGS = --cc --exe --top-module tb --sv \
                  -CFLAGS "-std=c++17" -LDFLAGS "-pthread" \
                  $(INCLUDE_DIRS) \
				  --timing

# -------------------------------------------------------------------
# Sources
# -------------------------------------------------------------------
SV_SRCS = \
    src/fpga/system_controller.sv \
    src/fpga/spi_peripheral.sv   \
    src/fpga/bnn_interface.sv    \
    src/fpga/debug_module.sv     \
    src/fpga/fsm_controller.sv   \
    src/fpga/image_buffer.sv     \
    src/fpga/bnn_module/bnn_top.sv      \
    src/fpga/bnn_module/Comparator.sv   \
    src/fpga/bnn_module/Conv2d_MaxPool2d.sv       \
    src/fpga/bnn_module/ConvCore.sv     \
    src/fpga/bnn_module/FC.sv           \
    src/fpga/bnn_module/MaxPoolCore.sv

DPI_SRCS = tests/external.cpp

TB_SV    = tests/tb.sv

# -------------------------------------------------------------------
# Default (CMake-based)
# -------------------------------------------------------------------
.PHONY: all test clean
all:
	@echo "Running CMake build..."
	cmake -S . -B build
	cmake --build build

test: all
	@echo "Running C++ unit tests..."
	@./build/main_test \
	  || (echo "Test failed. Check logs above." && exit 1)

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf build obj_dir

# -------------------------------------------------------------------
# Verilator‐driven SV simulation
# -------------------------------------------------------------------
.PHONY: sim
sim: obj_dir/Vtb
	@echo "Launching Verilator simulation..."
	@obj_dir/Vtb

obj_dir/Vtb: tests/tb.sv tests/external.cpp
	@echo "=== Verilating design ==="
	$(VERILATOR) $(VERILATOR_FLAGS) \
	  tests/tb.sv \
	  tests/external.cpp \
	  tests/main.cpp
	@echo "=== Building simulation executable ==="
	@make -C obj_dir -f Vtb.mk Vtb


# -------------------------------------------------------------------
# Vivado targets
# -------------------------------------------------------------------
.PHONY: bitstream flash size
bitstream:
	@echo "Synthesizing and generating bitstream..."
	"$(VIVADO)" -mode batch -source scripts/run_vivado.tcl

flash:
	@echo "Programming Basys3 board..."
	"$(VIVADO)" -mode batch -source scripts/flash_vivado.tcl

size:
	@echo "Checking bitstream size..."
	@if [ -f build/bnn_ocr.bit ]; then \
	  ls -lh build/bnn_ocr.bit; \
	else \
	  echo "No bitstream found. Run 'make bitstream' first."; \
	fi