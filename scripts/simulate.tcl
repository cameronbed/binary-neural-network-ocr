# scripts/simulate.tcl

# Read design and testbench
read_verilog src/fpga/blinky.v
read_verilog tests/blinky_tb.v

# Set top module
set_property top blinky_tb [current_fileset]

# Run simulation
launch_simulation
run all
