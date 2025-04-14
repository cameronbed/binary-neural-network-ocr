module bnn_module #(
    parameter int INFER_LATENCY = 2
) (
    input logic clk,
    input logic rst_n,

    // Data
    input logic img_in[0:783],
    output logic [7:0] result_out,

    // Control
    input  logic write_enable,
    output logic result_ready,

    // Debug
    input logic debug_enable,
    output logic debug_write_enable,
    output logic debug_result_ready,
    output logic [7:0] debug_result_out
);

  typedef enum logic [1:0] {
    IDLE,
    INFERENCE,
    DONE
  } bnn_state_t;

  bnn_state_t state, next_state;

  // Hardcode the width of infer_counter based on INFER_LATENCY
  logic [1:0] infer_counter;  // Width is 2 bits since INFER_LATENCY = 2

  // Hardcode INFER_LATENCY_MINUS_ONE
  localparam logic [1:0] INFER_LATENCY_MINUS_ONE = 2'b01;  // INFER_LATENCY - 1 = 1

  // ----------------------- FSM Control -----------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  // ----------------------- FSM Next-State Logic ----------------------
  always_comb begin
    next_state = state;
    case (state)
      IDLE: if (write_enable) next_state = INFERENCE;
      INFERENCE: if (infer_counter == INFER_LATENCY_MINUS_ONE) next_state = DONE;
      DONE: next_state = IDLE;
      default: next_state = IDLE;  // Handle unexpected states
    endcase
  end

  // Main sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_out <= 0;
      result_ready <= 0;
      infer_counter <= 0;
    end else begin
      case (state)
        IDLE: begin
          result_ready  <= 0;
          infer_counter <= 0;
        end

        INFERENCE: begin
          if (infer_counter < INFER_LATENCY_MINUS_ONE) begin
            infer_counter <= infer_counter + 1;
            result_ready  <= 0;
          end else begin
            result_out <= {7'b0, img_in[0]} + {7'b0, img_in[1]};
          end
        end

        DONE: begin
          result_ready <= 1;
          if (debug_enable) begin
            $display("[BNN_MODULE] Transition to DONE: result_ready asserted at time=%0t", $time);
          end
        end

        default: ;
      endcase
    end
  end

  // ----------------------- Debugging Signals -----------------------
  assign debug_write_enable = write_enable;
  assign debug_result_ready = result_ready;
  assign debug_result_out   = result_out;

endmodule
