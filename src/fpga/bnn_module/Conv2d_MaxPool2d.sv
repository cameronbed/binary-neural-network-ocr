`include "ConvCore.sv"
`include "MaxPoolCore.sv"

module Conv2d_MaxPool2d #(
    parameter int IC = 4,
    parameter int OC = 8, 
    parameter int CONV_IMG_IN_SIZE = 30,
    parameter int CONV_IMG_OUT_SIZE = CONV_IMG_IN_SIZE-2,
    parameter int POOL_IMG_OUT_SIZE = CONV_IMG_OUT_SIZE/2
)(
    input logic clk,
    input logic data_in_ready,
    input logic [CONV_IMG_IN_SIZE*CONV_IMG_IN_SIZE-1:0] img_in [0:IC-1],
    input logic [IC*9-1:0] weights [0:OC-1],
    output logic [POOL_IMG_OUT_SIZE*POOL_IMG_OUT_SIZE-1:0] img_out [0:OC-1], /* verilator lint_off UNUSEDSIGNAL */
    output logic data_out_ready
);
    logic [IC*9-1:0] core_weight;
    logic [CONV_IMG_OUT_SIZE*CONV_IMG_OUT_SIZE-1:0] core_img_out;
    logic [POOL_IMG_OUT_SIZE*POOL_IMG_OUT_SIZE-1:0] pool_img_out;
    logic core_data_in_ready;
    logic core_data_out_ready;
    integer cur_oc;

    always_ff @( posedge clk ) begin : ConvBlock
        if (!data_in_ready) begin
            cur_oc <= 0;
            data_out_ready <= 0;
            core_data_in_ready <= 0;
            core_weight <= weights[0];
            for (int i=0; i<OC; i=i+1) begin
                img_out[i] <= 0;
            end
        end
        else if (data_out_ready) begin end
        else begin
            if (core_data_out_ready) begin
                core_data_in_ready <= 0;
                if (cur_oc == OC) begin
                    data_out_ready <= 1;
                end
                else begin
                    cur_oc <= cur_oc + 1;
                    core_weight <= weights[cur_oc+1];
                    img_out[cur_oc] <= pool_img_out;
                end
            end
            else begin
                core_data_in_ready <= 1;
            end
        end
    end

    ConvCore#(
        .IC(IC),
        .IMG_IN_SIZE(CONV_IMG_IN_SIZE)
    ) core (
        .clk(clk),
        .data_in_ready(core_data_in_ready),
        .img_in(img_in),
        .weights(core_weight),
        .img_out(core_img_out),
        .data_out_ready(core_data_out_ready)
    );

    MaxPoolCore#(
        .IMG_IN_SIZE(CONV_IMG_OUT_SIZE)
    ) pool (
        .img_in(core_img_out),
        .img_out(pool_img_out)
    );

endmodule



