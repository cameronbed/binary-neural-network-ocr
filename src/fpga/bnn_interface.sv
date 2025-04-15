`timescale 1ns / 1ps
module bnn_interface #(
    parameter int INFER_LATENCY = 2
) (
    input logic clk,
    input logic rst_n,

    // Data
    input logic img_in[0:783],
    output logic [3:0] result_out,

    // Control
    input  logic img_buffer_full,
    output logic result_ready
);

  typedef enum logic [1:0] {
    IDLE,
    INFERENCE,
    DONE
  } bnn_state_t;

  bnn_state_t state, next_state;

  // ----------------------- FSM Next-State Logic ----------------------
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (img_buffer_full) next_state = INFERENCE;
      end

      INFERENCE: begin
        next_state = DONE;
      end
      DONE: begin
        next_state = IDLE;
      end

      default: next_state = IDLE;  // Handle unexpected states
    endcase
  end

  // Main sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_out <= 4'd0;
      result_ready <= 1'b0;
      state <= IDLE;
    end else begin
      state <= next_state;  // Only update state here
      case (state)
        IDLE: begin
        end

        INFERENCE: begin
          result_out   <= 4'd1;
          result_ready <= 1'b1;
        end

        DONE: begin
        end

        default: ;
      endcase
    end
  end

endmodule
