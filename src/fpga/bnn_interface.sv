`timescale 1ns / 1ps

`ifndef SYNTHESIS
`include "bnn_module/bnn_top.sv"
`endif


module bnn_interface (
    input logic clk,
    input logic rst_n,

    // Data
    input  logic [903:0] img_in,
    output logic [  3:0] result_out,

    // Control
    input  logic img_buffer_full,
    output logic result_ready,
    input  logic bnn_enable,
    input  logic bnn_clear
);

  parameter int CONV1_IMG_IN_SIZE = 30;
  parameter int CONV1_IC = 1;

  typedef enum logic [1:0] {
    IDLE,
    INFERENCE,
    DONE
  } bnn_state_t;

  bnn_state_t state, next_state;

  logic result_ready_internal;

  logic [899:0] img_in_truncated;
  assign img_in_truncated = img_in[903:4];

  // Repack as 2D input to BNN
  logic [CONV1_IMG_IN_SIZE*CONV1_IMG_IN_SIZE-1:0] conv1_img_in[0:CONV1_IC-1];
  assign conv1_img_in[0] = img_in_truncated;

  // ----------------- BNN Module Instantiation -----------------
  bnn_top u_bnn_top (
      .clk(clk),
      .conv1_img_in('{img_in_truncated}),
      .data_in_ready(bnn_enable),
      .result(result_out),
      .data_out_ready(result_ready_internal)
  );

  // ----------------------- FSM Next-State Logic ----------------------
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (img_buffer_full && bnn_enable) next_state = INFERENCE;
      end

      INFERENCE: begin
        if (result_ready_internal == 1) next_state = DONE;
      end

      DONE: begin
        if (bnn_clear) next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Main sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_ready <= 1'b0;
      state <= IDLE;

    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          result_ready <= 1'b0;
        end

        INFERENCE: begin
          if (result_ready_internal == 1) begin
            result_ready <= 1'd1;
          end
        end

        DONE: begin
          if (bnn_clear) begin
            result_ready <= 1'b0;  // clear result ready
          end else begin
            result_ready <= 1'b1;  // hold ready until clear
          end
        end

        default: result_ready <= 1'b0;
      endcase
    end
  end

endmodule
