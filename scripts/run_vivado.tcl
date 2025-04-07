# scripts/run_vivado.tcl
read_verilog src/fpga/blinky.v
read_xdc src/fpga/Basys3.xdc
synth_design -top blinky -part xc7a35tcpg236-1
opt_design
place_design
route_design
write_bitstream -force build/blinky.bit
