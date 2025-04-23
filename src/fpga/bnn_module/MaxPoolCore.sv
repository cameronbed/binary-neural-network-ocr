module MaxPoolCore #(
    parameter int IMG_IN_SIZE = 28,
    parameter int IMG_OUT_SIZE = IMG_IN_SIZE/2
)(
    input logic [IMG_IN_SIZE*IMG_IN_SIZE-1:0] img_in,
    output logic [IMG_OUT_SIZE*IMG_OUT_SIZE-1:0] img_out
);
    genvar row, col;
    generate
        for (row=0; row<IMG_OUT_SIZE; row=row+1) begin: out_row_gen // stride = 1 (output dimension)
            for (col=0; col<IMG_OUT_SIZE; col=col+1) begin: out_col_gen
                // Calculate input window start indices (stride = 2)
                localparam int IN_ROW = 2 * row;
                localparam int IN_COL = 2 * col;
                // OR the 2x2 window (max for binary values)
                assign img_out[row*IMG_OUT_SIZE + col] = 
                    img_in[IN_ROW * IMG_IN_SIZE + IN_COL]       | // (2r, 2c)
                    img_in[IN_ROW * IMG_IN_SIZE + (IN_COL + 1)] | // (2r, 2c+1)
                    img_in[(IN_ROW + 1) * IMG_IN_SIZE + IN_COL] | // (2r+1, 2c)
                    img_in[(IN_ROW + 1) * IMG_IN_SIZE + (IN_COL + 1)]; // (2r+1, 2c+1)
            end
        end
    endgenerate
endmodule

