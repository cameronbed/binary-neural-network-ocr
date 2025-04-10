# Set the minimum required CMake version and project name
cmake_minimum_required(VERSION 3.13)
project(bnn_sim LANGUAGES CXX)

# Find the Verilator binary. This just checks that verilator is on your system.
find_program(VERILATOR verilator REQUIRED)

# === Custom rule to build a Verilator-based simulation ===

# Set names and paths
set(TEST_NAME bnn_controller_tb)                         # The name of the testbench (and final binary)
set(TESTBENCH_CPP ${CMAKE_SOURCE_DIR}/tests/${TEST_NAME}.cpp)  # Path to the C++ testbench
set(VERILOG_FILE   ${CMAKE_SOURCE_DIR}/src/fpga/bnn_controller.sv) # Path to the SystemVerilog top module
set(OBJ_DIR        ${CMAKE_BINARY_DIR}/obj_${TEST_NAME})  # Verilator output dir
set(EXECUTABLE     ${CMAKE_BINARY_DIR}/${TEST_NAME})      # Final built sim binary

# Add a custom command to:
# 1. Run Verilator to generate the C++ model
# 2. Compile the model + testbench into an executable
add_custom_command(
    OUTPUT ${EXECUTABLE}
    COMMAND ${VERILATOR}
        -cc                                  # Generate C++ output
        --exe                                # Tell Verilator to build the testbench too
        ${TESTBENCH_CPP}                     # Your C++ testbench
        ${VERILOG_FILE}                      # Your Verilog or SystemVerilog source
        --top-module bnn_controller          # Top-level module name
        --sv                                 # Enable SystemVerilog parsing
        --public                             # Generate public class methods
        --trace                              # Enable VCD tracing
        --Mdir ${OBJ_DIR}                    # Where Verilator writes C++ outputs
        -o ${EXECUTABLE}                     # Final output binary
        --build                              # Compile it too
    DEPENDS ${TESTBENCH_CPP} ${VERILOG_FILE} # Rebuild if source changes
    COMMENT "Verilating and building ${TEST_NAME}"
    VERBATIM
)

# Create a custom target you can build manually via `make bnn_controller_tb`
add_custom_target(${TEST_NAME} DEPENDS ${EXECUTABLE})
