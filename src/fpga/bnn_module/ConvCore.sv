`ifndef CONVCORE_SV
`define CONVCORE_SV
/*
    binary convolutional module, accepts binary input, 
    performs xnor with float32 weights
        kenel_size = 3x3
        padding = 0
        stride = 1
*/
`timescale 1ns / 1ps

module ConvCore #(
    parameter int IC = 8,
    parameter int IMG_IN_SIZE = 30,
    parameter int IMG_OUT_SIZE = IMG_IN_SIZE - 2
) (
    input logic clk,
    input logic data_in_ready,
    input logic [IMG_IN_SIZE*IMG_IN_SIZE-1:0] img_in[0:IC-1],
    input logic [IC*9-1:0] weights,  // 3x3 kernel
    output logic [IMG_OUT_SIZE*IMG_OUT_SIZE-1:0] img_out,
    output logic data_out_ready
);

  logic signed [7:0] popcount;
  integer cur_ic, row, col, adder_count;
  integer img_ind[0:8];
  integer weights_ind[0:8];

  logic signed [7:0] patch_val;
  always_comb begin
    case (adder_count)
      0: patch_val = (img_in[cur_ic][img_ind[0]] == weights[weights_ind[0]]) ? 8'sh01 : 8'shFF;
      1: patch_val = (img_in[cur_ic][img_ind[1]] == weights[weights_ind[1]]) ? 8'sh01 : 8'shFF;
      2: patch_val = (img_in[cur_ic][img_ind[2]] == weights[weights_ind[2]]) ? 8'sh01 : 8'shFF;
      3: patch_val = (img_in[cur_ic][img_ind[3]] == weights[weights_ind[3]]) ? 8'sh01 : 8'shFF;
      4: patch_val = (img_in[cur_ic][img_ind[4]] == weights[weights_ind[4]]) ? 8'sh01 : 8'shFF;
      5: patch_val = (img_in[cur_ic][img_ind[5]] == weights[weights_ind[5]]) ? 8'sh01 : 8'shFF;
      6: patch_val = (img_in[cur_ic][img_ind[6]] == weights[weights_ind[6]]) ? 8'sh01 : 8'shFF;
      7: patch_val = (img_in[cur_ic][img_ind[7]] == weights[weights_ind[7]]) ? 8'sh01 : 8'shFF;
      8: patch_val = (img_in[cur_ic][img_ind[8]] == weights[weights_ind[8]]) ? 8'sh01 : 8'shFF;
      default: patch_val = 0;
    endcase
  end

  always_ff @(posedge clk) begin
    if (!data_in_ready) begin
      img_out <= 0;
      data_out_ready <= 0;
      cur_ic <= 0;
      row <= 0;
      col <= 0;
      popcount <= 0;
      adder_count <= 0;
      img_ind <= {
        0,
        1,
        2,
        IMG_IN_SIZE,
        IMG_IN_SIZE + 1,
        IMG_IN_SIZE + 2,
        IMG_IN_SIZE * 2,
        IMG_IN_SIZE * 2 + 1,
        IMG_IN_SIZE * 2 + 2
      };
      weights_ind <= {0, 1, 2, 3, 4, 5, 6, 7, 8};
    end else if (data_out_ready) begin
      data_out_ready <= 0;
    end else begin
      if (adder_count == 9) begin
        adder_count <= 0;
        if (cur_ic == IC - 1) begin
          cur_ic <= 0;
          weights_ind <= {0, 1, 2, 3, 4, 5, 6, 7, 8};
          img_out[row*IMG_OUT_SIZE+col] <= ~popcount[7];
          popcount <= 0;
          if (col == IMG_OUT_SIZE - 1) begin
            col <= 0;
            img_ind <= {
              row * IMG_IN_SIZE,
              row * IMG_IN_SIZE + 1,
              row * IMG_IN_SIZE + 2,
              (row + 1) * IMG_IN_SIZE,
              (row + 1) * IMG_IN_SIZE + 1,
              (row + 1) * IMG_IN_SIZE + 2,
              (row + 2) * IMG_IN_SIZE,
              (row + 2) * IMG_IN_SIZE + 1,
              (row + 2) * IMG_IN_SIZE + 2
            };
            if (row == IMG_OUT_SIZE - 1) begin
              row <= 0;
              img_ind <= {
                0,
                1,
                2,
                IMG_IN_SIZE,
                IMG_IN_SIZE + 1,
                IMG_IN_SIZE + 2,
                IMG_IN_SIZE * 2,
                IMG_IN_SIZE * 2 + 1,
                IMG_IN_SIZE * 2 + 2
              };
              data_out_ready <= 1;
            end else begin
              row <= row + 1;
              img_ind[0] <= (row + 1) * IMG_IN_SIZE + col;
              img_ind[1] <= (row + 1) * IMG_IN_SIZE + col + 1;
              img_ind[2] <= (row + 1) * IMG_IN_SIZE + col + 2;
              img_ind[3] <= (row + 2) * IMG_IN_SIZE + col;
              img_ind[4] <= (row + 2) * IMG_IN_SIZE + col + 1;
              img_ind[5] <= (row + 2) * IMG_IN_SIZE + col + 2;
              img_ind[6] <= (row + 3) * IMG_IN_SIZE + col;
              img_ind[7] <= (row + 3) * IMG_IN_SIZE + col + 1;
              img_ind[8] <= (row + 3) * IMG_IN_SIZE + col + 2;
            end
          end else begin
            col <= col + 1;
            img_ind[0] <= row * IMG_IN_SIZE + (col + 1);
            img_ind[1] <= row * IMG_IN_SIZE + (col + 1) + 1;
            img_ind[2] <= row * IMG_IN_SIZE + (col + 1) + 2;
            img_ind[3] <= (row + 1) * IMG_IN_SIZE + (col + 1);
            img_ind[4] <= (row + 1) * IMG_IN_SIZE + (col + 1) + 1;
            img_ind[5] <= (row + 1) * IMG_IN_SIZE + (col + 1) + 2;
            img_ind[6] <= (row + 2) * IMG_IN_SIZE + (col + 1);
            img_ind[7] <= (row + 2) * IMG_IN_SIZE + (col + 1) + 1;
            img_ind[8] <= (row + 2) * IMG_IN_SIZE + (col + 1) + 2;
          end
        end else begin
          cur_ic <= cur_ic + 1;
          weights_ind[0] <= (cur_ic + 1) * 9;
          weights_ind[1] <= (cur_ic + 1) * 9 + 1;
          weights_ind[2] <= (cur_ic + 1) * 9 + 2;
          weights_ind[3] <= (cur_ic + 1) * 9 + 3;
          weights_ind[4] <= (cur_ic + 1) * 9 + 4;
          weights_ind[5] <= (cur_ic + 1) * 9 + 5;
          weights_ind[6] <= (cur_ic + 1) * 9 + 6;
          weights_ind[7] <= (cur_ic + 1) * 9 + 7;
          weights_ind[8] <= (cur_ic + 1) * 9 + 8;
        end
      end else begin
        popcount <= popcount + patch_val;
        adder_count <= adder_count + 1;
      end
    end
  end

endmodule

`endif
