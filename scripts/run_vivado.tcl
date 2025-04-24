# scripts/run_vivado.tcl
read_verilog src/fpga/top.sv
read_xdc src/fpga/Basys3.xdc
synth_design -top top -part xc7a35tcpg236-1
opt_design
place_design
route_design
write_bitstream -force build/bnn_ocr.bit
