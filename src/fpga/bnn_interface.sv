`timescale 1ns / 1ps
module bnn_interface (
    input logic clk,
    input logic rst_n,

    // Data
    input  logic [903:0] img_in,
    output logic [  3:0] result_out, // Ensure this is 4 bits

    // Control
    input  logic img_buffer_full,
    output logic result_ready,
    input  logic bnn_start
);


  typedef enum logic [1:0] {
    IDLE,
    INFERENCE,
    DONE
  } bnn_state_t;

  bnn_state_t state, next_state;

  parameter int DONE_CYCLES = 128;  // Configurable number of cycles for DONE state
  logic [6:0] done_counter;  // Counter width based on DONE_CYCLES

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
        if ({25'b0, done_counter} == DONE_CYCLES - 1)
          next_state = IDLE;  // Transition after DONE_CYCLES
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
      done_counter <= 0;  // Initialize counter
    end else begin
      state <= next_state;  // Only update state here
      case (state)
        IDLE: begin
          done_counter <= 0;  // Reset counter in IDLE
        end

        INFERENCE: begin
          result_out   <= 4'd1;
          result_ready <= 1'b1;
        end

        DONE: begin
          if ({25'b0, done_counter} < DONE_CYCLES - 1) begin
            done_counter <= done_counter + 1;  // Increment counter
          end
        end

        default: ;
      endcase
    end
  end

endmodule
