`include "ConvCore.sv"

module Conv2d #(
    parameter int IC = 4,
    parameter int OC = 8, 
    parameter int IMG_IN_SIZE = 30,
    parameter int IMG_OUT_SIZE = IMG_IN_SIZE-2
)(
    input logic [IMG_IN_SIZE*IMG_IN_SIZE-1:0] img_in [0:IC-1],
    input logic [IC*9-1:0] weights [0:OC-1],
    // input logic signed [15:0] threshold [0:OC-1],   // Q8.8 fixed-point threshold

    output logic [IMG_OUT_SIZE*IMG_OUT_SIZE-1:0] img_out [0:OC-1] /* verilator lint_off UNUSEDSIGNAL */
);

genvar oc;
generate
    for (oc=0; oc<OC; oc=oc+1) begin: conv_core_gen
        ConvCore#(
            .IC(IC),
            .IMG_IN_SIZE(IMG_IN_SIZE)
        ) core (
            .img_in(img_in),
            .weights(weights[oc]),
            // .threshold(threshold[oc]),
            .img_out(img_out[oc])
        );
    end
endgenerate
endmodule






