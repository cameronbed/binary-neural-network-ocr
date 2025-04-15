# Set the minimum required CMake version and project name
cmake_minimum_required(VERSION 3.13)
project(bnn_sim LANGUAGES CXX)

# Find the Verilator binary. This just checks that verilator is on your system.
find_program(VERILATOR verilator REQUIRED)

# Set the C++ standard
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add all RTL source files
set(RTL_SOURCES
    ${CMAKE_SOURCE_DIR}/src/fpga/system_controller.sv
    ${CMAKE_SOURCE_DIR}/src/fpga/spi_peripheral.sv
    ${CMAKE_SOURCE_DIR}/src/fpga/bnn_interface.sv
    ${CMAKE_SOURCE_DIR}/src/fpga/debug_module.sv
    ${CMAKE_SOURCE_DIR}/src/fpga/fsm_controller.sv
    ${CMAKE_SOURCE_DIR}/src/fpga/top.sv
    ${CMAKE_SOURCE_DIR}/src/fpga/image_buffer.sv
)

# Set up paths
set(TEST_NAME main_test)
set(TESTBENCH_CPP 
    ${CMAKE_SOURCE_DIR}/tests/${TEST_NAME}.cpp
    ${CMAKE_SOURCE_DIR}/tests/test_helpers.cpp
    ${CMAKE_SOURCE_DIR}/tests/test_image_buffer.cpp
    ${CMAKE_SOURCE_DIR}/tests/test_spi.cpp
)
set(OBJ_DIR ${CMAKE_BINARY_DIR}/obj_dir)
set(EXECUTABLE ${CMAKE_BINARY_DIR}/${TEST_NAME})

# Custom command to run verilator
add_custom_command(
    OUTPUT ${EXECUTABLE}
    COMMAND ${VERILATOR} 
        -cc
        --exe
        --build
        -j 0
        --trace
        --timing
        --top-module top
        -I${CMAKE_SOURCE_DIR}/src/fpga  # Add include path
        --Mdir ${OBJ_DIR}
        -CFLAGS "-I${CMAKE_SOURCE_DIR}/include"
        -o ${EXECUTABLE}
        ${TESTBENCH_CPP}
        ${RTL_SOURCES}
    DEPENDS ${TESTBENCH_CPP} ${RTL_SOURCES}
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Verilating ${TEST_NAME}"
    VERBATIM
)

# Custom target
add_custom_target(${TEST_NAME} ALL DEPENDS ${EXECUTABLE})

# Add test target
add_custom_target(test
    COMMAND ${EXECUTABLE}
    DEPENDS ${TEST_NAME}
)
