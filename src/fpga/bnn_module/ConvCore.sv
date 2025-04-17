/*
    binary convolutional module, accepts binary input, 
    performs xnor with float32 weights
        kenel_size = 3x3
        padding = 0
        stride = 1
*/

module ConvCore#(
    parameter int IC = 8,
    parameter int IMG_IN_SIZE = 30,
    parameter int IMG_OUT_SIZE = IMG_IN_SIZE-2
)(
    input logic [IMG_IN_SIZE*IMG_IN_SIZE-1:0] img_in [0:IC-1],
    input logic [IC*9-1:0] weights, // 3x3 kernel
    // input logic signed [15:0] threshold,
    
    output logic [IMG_OUT_SIZE*IMG_OUT_SIZE-1:0] img_out
);

    // logic signed [7:0] popcount [0:IMG_OUT_SIZE-1][0:IMG_OUT_SIZE-1];
    genvar row, col, ic, kr, kc;
    generate
        for (row=0; row<IMG_OUT_SIZE; row=row+1) begin: out_row_gen
            for (col=0; col<IMG_OUT_SIZE; col=col+1) begin: out_col_gen
                logic [IC*9-1:0] patch; // image patch for one convolution
                for (ic=0; ic<IC; ic=ic+1) begin: ic_gen
                    for (kr=0; kr<3; kr=kr+1) begin: kr_gen
                        for (kc=0; kc<3; kc=kc+1) begin: kc_gen
                            assign patch[ic*9+kr*3+kc] = img_in[ic][(row+kr)*IMG_IN_SIZE+(col+kc)];
                        end
                    end
                end
                logic signed [7:0] popcount;
                always_comb begin: adder_block
                    popcount = 8'b0;
                    for (int i=0; i<IC*9; i=i+1) begin: loop_add
                        popcount = popcount + ((patch[i] == weights[i])?8'h1:-8'h1);
                    end
                end   
                // assign img_out[row*IMG_OUT_SIZE+col] = ($signed({popcount, 8'b0}) >= threshold)?1'b1:1'b0;
                assign img_out[row*IMG_OUT_SIZE+col] = ((popcount[7])?1'b0:1'b1);
            end
        end
    endgenerate
endmodule

