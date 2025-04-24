/*
    Comparator module, 
    compares the outputs from the FC layer to decide the final classification output
    the inputs should be in the form of Q8.8 fixed-point array
*/

module Comparator#(
    parameter int IC = 10,
    parameter int OUTPUT_BIT = $clog2(IC+1) // num of bits to enumerate each class
)(
    input logic clk,
    input logic data_in_ready,
    input logic signed [15:0] in [0:IC-1],
    output logic [OUTPUT_BIT-1:0] out,
    output logic data_out_ready
);
    logic signed [15:0] max;
    logic [OUTPUT_BIT-1:0] max_ind;
    integer cur_ic;

    always_ff @(posedge clk) begin
        if (!data_in_ready) begin
            max <= in[0];
            max_ind <= 0;
            cur_ic <= 0;
            data_out_ready <= 0;
            out <= 0;
        end
        else if (data_out_ready) begin end
        else begin
            if (max < in[cur_ic]) begin
                max <= in[cur_ic];
                max_ind <= cur_ic[OUTPUT_BIT-1:0];
            end
            cur_ic <= cur_ic + 1;
            if (cur_ic == IC) begin
                data_out_ready <= 1;
                out <= max_ind;
            end
        end
    end

endmodule

