`include "ConvCore.sv"

module Conv2d #(
    parameter int IC = 4,
    parameter int OC = 8, 
    parameter int IMG_IN_SIZE = 30,
    parameter int IMG_OUT_SIZE = IMG_IN_SIZE-2
)(
    input logic clk,
    input logic data_in_ready,
    input logic [IMG_IN_SIZE*IMG_IN_SIZE-1:0] img_in [0:IC-1],
    input logic [IC*9-1:0] weights [0:OC-1],
    output logic [IMG_OUT_SIZE*IMG_OUT_SIZE-1:0] img_out [0:OC-1], /* verilator lint_off UNUSEDSIGNAL */
    output logic data_out_ready
);
    logic [IC*9-1:0] core_weight;
    logic [IMG_OUT_SIZE*IMG_OUT_SIZE-1:0] core_img_out;
    integer cur_oc;

    always_ff @( posedge clk ) begin : ConvBlock
        if (!data_in_ready) begin
            cur_oc <= 0;
            data_out_ready <= 0;
            core_weight <= weights[0];
            for (int i=0; i<OC; i=i+1) begin
                img_out[i] <= 0;
            end
        end
        else if (data_out_ready) begin end
        else begin
            core_weight <= weights[cur_oc+1];
            img_out[cur_oc] <= core_img_out;
            cur_oc <= cur_oc + 1;
            if (cur_oc == OC-1) begin
                data_out_ready <= 1;
            end
        end
    end

    ConvCore#(
        .IC(IC),
        .IMG_IN_SIZE(IMG_IN_SIZE)
    ) core (
        .img_in(img_in),
        .weights(core_weight),
        .img_out(core_img_out)
    );

endmodule



