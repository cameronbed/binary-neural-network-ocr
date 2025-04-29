# scripts/run_vivado.tcl
read_verilog src/fpga/system_controller.sv
read_xdc Basys-3-Constraints.xdc
synth_design -top system_controller -part xc7a35tcpg236-1
opt_design
place_design
route_design
write_bitstream -force build/bnn_ocr.bit
