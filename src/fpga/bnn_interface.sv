`timescale 1ns / 1ps

`ifndef SYNTHESIS
`include "bnn_module/bnn_top.sv"
`endif

module bnn_interface (
    input logic clk,
    input logic rst_n,

    // Data
    input  logic [899:0] img_in,
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

  // =================== Internal Signals ==========
  logic       result_ready_internal;
  logic       data_in_ready_int;
  logic [3:0] result_out_reg;

  // ======================= MOCK MODULE
  // Mock behavior: Generate a pseudo-random result based on img_in_truncated
  // logic [3:0] lfsr;
  // always_ff @(posedge clk or negedge rst_n) begin
  //   if (!rst_n) begin
  //     lfsr <= 4'b0001;  // Initialize LFSR
  //   end else if (bnn_enable) begin
  //     // Simple LFSR for pseudo-random number generation
  //     lfsr <= {lfsr[2:0], ^(lfsr[3:2] ^ img_in_truncated[0])};
  //   end
  // end
  // assign result_out = lfsr % 10;  // Random number between 0-9
  // assign result_ready_internal = bnn_enable;  // Simulate ready signal
  // ======================= END MOCK MODULE

  // =============== Clock Enable
  (* USE_DSP = "no", SHREG_EXTRACT = "no" *)logic [1:0] clk_div;
  logic       bnn_clk_en;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) clk_div <= 0;
    else clk_div <= clk_div + 1;
  end
  assign bnn_clk_en = (clk_div == 2'b00);
  // ======================

  // logic [3:0] check_sum;
  // always_ff @(posedge clk) begin
  //   if (data_in_ready_int) begin
  //     // for (int i = 0; i < 225; i = i + 1) begin
  //     //   check_sum <= check_sum + img_to_bnn[0][4*i+:4];
  //     // end
  //     if (img_in[0] == 0) begin
  //       check_sum <= 0;
  //     end else check_sum <= 1;
  //   end
  // end
  // // assign result_out = check_sum;

  // ----------------- BNN Module Instantiation -----------------
  bnn_top u_bnn_top (
      .clk(bnn_clk_en),
      .conv1_img_in('{img_in}),
      .data_in_ready(data_in_ready_int),
      .result(result_out_reg),
      .data_out_ready(result_ready_internal)
  );

  assign result_out = (|img_in) ? result_out_reg : 4'd10;

  // ----------------------- FSM Next-State Logic ----------------------
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (data_in_ready_int) next_state = INFERENCE;
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
      data_in_ready_int <= 1'b0;

    end else if (bnn_clear) begin
      result_ready <= 1'b0;
      state <= IDLE;
      data_in_ready_int <= 1'b0;

    end else begin

      if (img_buffer_full && bnn_enable) begin
        data_in_ready_int <= 1'b1;
      end else if (result_ready_internal) begin
        data_in_ready_int <= 1'b0;
      end

      state <= next_state;
      case (state)
        IDLE: begin
          result_ready <= 1'b0;
        end

        INFERENCE: begin
          if (result_ready_internal == 1) begin
            result_ready <= 1'd1;
          end else begin
            result_ready <= 1'b0;  // hold ready until result is available
          end
        end

        DONE: begin
          if (bnn_clear) begin
            result_ready <= 1'b0;  // clear result ready
          end else begin
            result_ready <= 1'b1;  // hold ready until clear
          end
        end

        default: begin
          result_ready <= 1'b0;
        end
      endcase
    end
  end

endmodule
