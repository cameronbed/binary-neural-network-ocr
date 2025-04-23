`include "MaxPoolCore.sv"

module MaxPool2d #(
    parameter int IMG_IN_SIZE = 28,
    parameter int IMG_OUT_SIZE = IMG_IN_SIZE/2,
    parameter int IC = 10
)(
    input logic [IMG_IN_SIZE*IMG_IN_SIZE-1:0] img_in [0:IC-1],
    output logic [IMG_OUT_SIZE*IMG_OUT_SIZE-1:0] img_out [0:IC-1]
);

    genvar ic;
    generate
        for (ic=0; ic<IC; ic=ic+1) begin: maxpool_core_gen
            MaxPoolCore#(
                .IMG_IN_SIZE(IMG_IN_SIZE)
            )maxpool(
                .img_in(img_in[ic]),
                .img_out(img_out[ic])
            );
        end
    endgenerate

endmodule

