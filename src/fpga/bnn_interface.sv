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
  typedef enum logic [1:0] {
    IDLE,
    INFERENCE,
    DONE
  } bnn_state_t;
  bnn_state_t state, next_state;

  logic [899:0] img_to_bnn[0:0];
  assign img_to_bnn[0] = img_in[903:4];
  logic [899:0] img_to_bnn_stage1[0:0];
  logic [899:0] img_to_bnn_stage2[0:0];

  logic data_in_ready_stage1, data_in_ready_stage2;

  logic result_ready_stage1, result_ready_stage2;

  logic [3:0] result_out_stage1, result_out_stage2;

  logic data_in_ready_int;
  logic result_ready_internal;
  logic [3:0] result_out_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_in_ready_int <= 1'b0;
    end else begin
      if (img_buffer_full && bnn_enable) data_in_ready_int <= 1'b1;
      else if (result_ready_internal) data_in_ready_int <= 1'b0;
    end
  end

  (* USE_DSP = "no", SHREG_EXTRACT = "no" *) logic [1:0] clk_div;
  logic bnn_clk_en;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) clk_div <= 0;
    else clk_div <= clk_div + 1;
  end

  assign bnn_clk_en = (clk_div == 2'b00);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      img_to_bnn_stage1[0] <= '0;
      img_to_bnn_stage2[0] <= '0;
      data_in_ready_stage1 <= 1'b0;
      data_in_ready_stage2 <= 1'b0;
    end else if (bnn_clk_en) begin
      img_to_bnn_stage1[0] <= img_to_bnn[0];
      img_to_bnn_stage2[0] <= img_to_bnn_stage1[0];
      data_in_ready_stage1 <= data_in_ready_int;
      data_in_ready_stage2 <= data_in_ready_stage1;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_out_stage1   <= 4'b0;
      result_out_stage2   <= 4'b0;
      result_ready_stage1 <= 1'b0;
      result_ready_stage2 <= 1'b0;
    end else begin
      result_ready_stage1 <= result_ready_internal;
      result_ready_stage2 <= result_ready_stage1;

      if (result_ready_internal) begin
        result_out_stage1   <= result_out_reg;
        result_ready_stage1 <= 1'b1;
      end else begin
        result_ready_stage1 <= 1'b0;
      end

      result_out_stage2   <= result_out_stage1;
      result_ready_stage2 <= result_ready_stage1;
    end
  end

  // ----------------- BNN Module Instantiation -----------------
  bnn_top u_bnn_top (
      .clk           (clk),
      .conv1_img_in  (img_to_bnn_stage2),
      .data_in_ready (data_in_ready_stage2),
      .result        (result_out_reg),
      .data_out_ready(result_ready_internal)
  );

  // ======================= MOCK MODULE ========================
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
  // ======================= END MOCK MODULE =========================

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

    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          result_ready <= 1'b0;
        end

        INFERENCE: begin
          if (result_ready_internal == 1) begin
            //$display("[BNN_INTERFACE] @%0t result=%0d", $time, result_out);
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
