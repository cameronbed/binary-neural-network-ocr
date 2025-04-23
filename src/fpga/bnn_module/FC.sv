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
    input logic [IC-1:0] in,
    input logic signed [15:0] weights [0:IC*OC-1],
    output logic signed [15:0] out [0:OC-1]
);

    genvar oc;
    generate
        for (oc=0; oc<OC; oc=oc+1) begin
            logic signed [15:0] temp_out;
            always_comb begin
                temp_out = 0;
                for (int i=0; i<IC; i=i+1) begin
                    temp_out = temp_out + ((in[i])?weights[oc*IC+i]:-weights[oc*IC+i]);
                end
            end
            assign out[oc] = temp_out;
        end
    endgenerate

endmodule

