`include "MaxPoolCore.sv"

module MaxPool2d #(
    parameter int IMG_IN_SIZE = 28,
    parameter int IMG_OUT_SIZE = IMG_IN_SIZE/2,
    parameter int IC = 10
)(
    input logic clk,
    input logic data_in_ready,
    input logic [IMG_IN_SIZE*IMG_IN_SIZE-1:0] img_in [0:IC-1],
    output logic [IMG_OUT_SIZE*IMG_OUT_SIZE-1:0] img_out [0:IC-1],
    output logic data_out_ready
);

    integer cur_oc;
    logic [IMG_IN_SIZE*IMG_IN_SIZE-1:0] core_img_in;
    logic [IMG_OUT_SIZE*IMG_OUT_SIZE-1:0] core_img_out;

    always_ff @(posedge clk) begin
        if (!data_in_ready) begin
            cur_oc <= 0;
            data_out_ready <= 0;
            core_img_in <= img_in[0];
            for (int i=0; i<IC; i=i+1) begin
                img_out[i] <= 0;
            end
        end
        else if (data_out_ready) begin end
        else begin
            core_img_in <= img_in[cur_oc+1];
            img_out[cur_oc] <= core_img_out;
            cur_oc <= cur_oc + 1;
            if (cur_oc == IC-1) begin
                data_out_ready <= 1;
            end
        end
    end

    MaxPoolCore#(
        .IMG_IN_SIZE(IMG_IN_SIZE)
    )maxpool(
        .img_in(core_img_in),
        .img_out(core_img_out)
    );

endmodule

