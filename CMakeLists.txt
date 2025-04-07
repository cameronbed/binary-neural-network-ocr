cmake_minimum_required(VERSION 3.13)
project(binary_neural_network_ocr LANGUAGES CXX)

# Required globally
enable_testing()

# Locate Verilator binary
find_program(VERILATOR verilator REQUIRED)

# Function to add a Verilator testbench
function(add_verilator_test TEST_NAME)
    message(STATUS "Adding Verilator testbench: ${TEST_NAME}")

    file(GLOB ALL_FPGA_VERILOG
        "${CMAKE_SOURCE_DIR}/src/fpga/*.v"
        "${CMAKE_SOURCE_DIR}/src/fpga/*.sv"
    )
    set(VERILOG_SOURCE "${ALL_FPGA_VERILOG}")

    set(TESTBENCH_CPP "${CMAKE_SOURCE_DIR}/tests/${TEST_NAME}.cpp")
    set(OBJ_DIR "${CMAKE_BINARY_DIR}/obj_${TEST_NAME}")
    set(EXECUTABLE "${CMAKE_BINARY_DIR}/${TEST_NAME}")
    
    # Verilate + compile using a custom command
    add_custom_command(
        OUTPUT ${EXECUTABLE}
        COMMAND ${VERILATOR}
            -cc
            --exe ${TESTBENCH_CPP}
            ${VERILOG_SOURCE}
            --top-module spi_peripheral
            --timing
            --public
            -o ${EXECUTABLE}
            --Mdir ${OBJ_DIR}
            --build
        DEPENDS ${VERILOG_SOURCE} ${TESTBENCH_CPP}
        COMMENT "Verilating and building ${TEST_NAME}"
        VERBATIM
    )

    add_custom_target(run_${TEST_NAME} DEPENDS ${EXECUTABLE})
    add_test(NAME ${TEST_NAME} COMMAND ${EXECUTABLE})
endfunction()

# Add testbenches here
# add_verilator_test(blinky_tb)
add_verilator_test(spi_peripheral_tb)
