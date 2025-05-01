`ifndef CONVCORE_SV
`define CONVCORE_SV
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
    input logic clk,
    input logic data_in_ready,
    input logic [IMG_IN_SIZE*IMG_IN_SIZE-1:0] img_in [0:IC-1],
    input logic [IC*9-1:0] weights,  // 3x3 kernel
    output logic [IMG_OUT_SIZE*IMG_OUT_SIZE-1:0] img_out,
    output logic data_out_ready
);

    logic signed [7:0] popcount [0:IMG_OUT_SIZE*IMG_OUT_SIZE-1];
    integer cur_ic;

    always_ff @(posedge clk) begin
        if (!data_in_ready) begin
            img_out <= 0;
            data_out_ready <= 0;
            cur_ic <= 0;
        end
        else if (data_out_ready) begin 
            data_out_ready <= 0;
        end
        else begin
            cur_ic <= cur_ic + 1;
            if (cur_ic == IC) begin
                for (int i=0; i<IMG_OUT_SIZE*IMG_OUT_SIZE; i=i+1) begin
                    img_out[i] <= (popcount[i][7]?1'b0:1'b1);
                end
                data_out_ready <= 1;
            end
        end
    end

    genvar row, col;
    generate
    for (row=0; row<IMG_OUT_SIZE; row=row+1) begin: out_row_gen
        for (col=0; col<IMG_OUT_SIZE; col=col+1) begin: out_col_gen
            always_ff @(posedge clk) begin
                if (!data_in_ready) begin
                    popcount[row*IMG_OUT_SIZE+col] <= 0;
                end
                else if (data_out_ready) begin end
                else begin
                    popcount[row*IMG_OUT_SIZE+col] <= popcount[row*IMG_OUT_SIZE+col] + 
                                                    ((img_in[cur_ic][row*IMG_IN_SIZE+col] == weights[cur_ic*9+0])?8'sh01 : 8'shFF) + 
                                                    ((img_in[cur_ic][row*IMG_IN_SIZE+col+1] == weights[cur_ic*9+1])?8'sh01 : 8'shFF) + 
                                                    ((img_in[cur_ic][row*IMG_IN_SIZE+col+2] == weights[cur_ic*9+2])?8'sh01 : 8'shFF) + 
                                                    ((img_in[cur_ic][(row+1)*IMG_IN_SIZE+col] == weights[cur_ic*9+3])?8'sh01 : 8'shFF) + 
                                                    ((img_in[cur_ic][(row+1)*IMG_IN_SIZE+col+1] == weights[cur_ic*9+4])?8'sh01 : 8'shFF) + 
                                                    ((img_in[cur_ic][(row+1)*IMG_IN_SIZE+col+2] == weights[cur_ic*9+5])?8'sh01 : 8'shFF) + 
                                                    ((img_in[cur_ic][(row+2)*IMG_IN_SIZE+col] == weights[cur_ic*9+6])?8'sh01 : 8'shFF) + 
                                                    ((img_in[cur_ic][(row+2)*IMG_IN_SIZE+col+1] == weights[cur_ic*9+7])?8'sh01 : 8'shFF) + 
                                                    ((img_in[cur_ic][(row+2)*IMG_IN_SIZE+col+2] == weights[cur_ic*9+8])?8'sh01 : 8'shFF);
                end
            end
        end
    end
    endgenerate

endmodule

`endif
