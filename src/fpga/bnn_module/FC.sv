/*
    fully-connected layer
    this layer is NOT binarized
    use Q8.8 fixed-point weights
    expects inputs to have values in range {-1, 1}

    this layer is intended to use as the last layer for image classification
*/
module FC#(
    parameter int IC = 288,
    parameter int OC = 10
)(
    input logic clk,
    input logic data_in_ready,
    input logic [IC-1:0] in,
    input logic signed [15:0] weights [0:IC*OC-1],
    output logic signed [15:0] out [0:OC-1],
    output logic data_out_ready
);

    integer cur_ic;
    integer cur_oc;
    logic signed [15:0] temp_out;

    always_ff @(posedge clk) begin
        if (!data_in_ready) begin
            cur_oc <= 0;
            cur_ic <= 0;
            temp_out <= 0;
            data_out_ready <= 0;
            for (int i=0; i<OC; i=i+1) begin
                out[i] <= 0;
            end
        end
        else if (data_out_ready) begin end
        else begin
            if (cur_ic == IC) begin
                cur_ic <= 0;
                cur_oc <= cur_oc + 1;
                out[cur_oc] <= temp_out;
                temp_out <= 0;
            end else begin
                cur_ic <= cur_ic + 1;
                temp_out <= temp_out + ((in[cur_ic])?weights[cur_oc*IC+cur_ic]:-weights[cur_oc*IC+cur_ic]);
            end
            if (cur_oc == OC) begin
                data_out_ready <= 1;
            end
        end
    end

endmodule

