`timescale 1ns / 1ps
// `include "bnn_module/bnn_top.sv"
module bnn_interface (
    input logic clk,
    input logic rst_n,

    // Data
    input  logic [903:0] img_in,
    output logic [  3:0] result_out,

    // Control
    input  logic img_buffer_full,
    output logic result_ready,
    input  logic bnn_start
);

  // ----------------- Internal Signals -----------------
  parameter int CONV1_IMG_IN_SIZE = 30;  // Match the parameter in bnn_top
  parameter int CONV1_IC = 1;  // Match the parameter in bnn_top

  logic [CONV1_IMG_IN_SIZE*CONV1_IMG_IN_SIZE-1:0] img_in_truncated[0:CONV1_IC-1];

  // Truncate the last 4 bits and reshape img_in
  assign img_in_truncated[0] = img_in[903:4]; // Truncate last 4 bits and assign to the first channel

  // ----------------- BNN Module Instantiation -----------------
  bnn_top u_bnn_top (
      .clk(clk),
      .img_in(img_in_truncated),
      .data_in_ready(data_out_ready_int),
      .result(result_out),
      .data_out_ready(result_ready_int)
  );

  typedef enum logic [1:0] {
    IDLE,
    INFERENCE,
    DONE
  } bnn_state_t;

  bnn_state_t state, next_state;

  logic data_out_ready_int;
  logic result_ready_int;

  // ----------------------- FSM Next-State Logic ----------------------
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (img_buffer_full) next_state = INFERENCE;
      end

      INFERENCE: begin
        if (result_ready_int == 1) next_state = DONE;
      end

      DONE: begin

      end

      default: next_state = IDLE;
    endcase
  end

  // Main sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // result_out <= 4'd0;
      result_ready <= 1'b0;
      state <= IDLE;
    end else begin
      state <= next_state;  // Only update state here
      case (state)
        IDLE: begin
        end

        INFERENCE: begin
          if (result_ready_int == 1) begin
            result_ready <= 1'd1;
          end
        end

        DONE: begin

        end


        default: ;
      endcase
    end
  end

endmodule
