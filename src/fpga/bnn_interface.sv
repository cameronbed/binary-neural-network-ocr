`timescale 1ns / 1ps

`include "bnn_module/bnn_top.sv"

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

  logic [CONV1_IMG_IN_SIZE*CONV1_IMG_IN_SIZE-1:0] img_in_truncated[0:CONV1_IC-1];

  assign img_in_truncated[0] = img_in[903:4];

  // ----------------- BNN Module Instantiation -----------------
  bnn_top u_bnn_top (
      .clk(clk),
      .img_in(img_in_truncated),
      .data_in_ready(bnn_enable),
      .result(result_out),
      .data_out_ready(result_ready_internal)
  );

  // ----------------------- FSM Next-State Logic ----------------------
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (img_buffer_full && bnn_enable) begin
          $display("[BNN_INTERFACE] Transitioning to INFERENCE state.");
          next_state = INFERENCE;
        end
      end

      INFERENCE: begin
        if (result_ready_internal == 1) begin
          $display("[BNN_INTERFACE] Transitioning to DONE state. Result ready internal: %b",
                   result_ready_internal);
          next_state = DONE;
        end
      end

      DONE: begin
        if (bnn_clear) begin
          $display("[BNN_INTERFACE] Transitioning to IDLE state. Clear signal received.");
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  // Main sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      $display("[BNN_INTERFACE] Reset asserted. Returning to IDLE state.");
      result_ready <= 1'b0;
      state <= IDLE;

    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          result_ready <= 1'b0;
          $display("[BNN_INTERFACE] In IDLE state. img_buffer_full: %b, bnn_enable: %b",
                   img_buffer_full, bnn_enable);
        end

        INFERENCE: begin
          if (result_ready_internal == 1) begin
            result_ready <= 1'd1;
            $display("[BNN_INTERFACE] Inference complete. Result ready: %b", result_ready);
          end
        end

        DONE: begin
          if (bnn_clear) begin
            result_ready <= 1'b0;  // clear result ready
            $display("[BNN_INTERFACE] Clearing result_ready signal.");
          end else begin
            result_ready <= 1'b1;  // hold ready until clear
            $display(
                "[BNN_INTERFACE] Holding result_ready signal. Result (binary): %b, Result (decimal): %d",
                result_out, result_out);
            $display("[BNN_INTERFACE] Inference done. Result: %b", result_out);
          end
        end

        default: result_ready <= 1'b0;
      endcase
    end
  end

endmodule
