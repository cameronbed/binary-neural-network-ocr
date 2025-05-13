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
    output logic result_ready,
    input  logic bnn_enable,
    input  logic bnn_clear,
    output logic bnn_ready_for_input
);
  //------------------------------------------------------------------
  // Parameters / types
  //------------------------------------------------------------------
  parameter int CONV1_IMG_IN_SIZE = 30;
  parameter int CONV1_IC = 1;

  typedef enum logic [1:0] {
    IDLE,
    INFERENCE,
    DONE
  } bnn_state_t;

  //------------------------------------------------------------------
  // Slow-clock enable (divide-by-4 for example)
  //------------------------------------------------------------------
  (* USE_DSP = "no", SHREG_EXTRACT = "no" *)
  logic [1:0] clk_div;
  logic       bnn_clk_en;

  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) clk_div <= 2'd0;
    else clk_div <= clk_div + 2'd1;

  assign bnn_clk_en = (clk_div == 2'b00);

  //------------------------------------------------------------------
  // Internal / intermediate signals
  //------------------------------------------------------------------
  // Top-level Module signals
  logic [899:0] img_in_internal;
  logic         result_ready_internal;
  logic [  3:0] result_out_internal;

  // BNN Module signals
  logic [899:0] img_to_bnn_raw;
  logic         data_in_ready_raw;
  logic [  3:0] result_out_from_bnn_raw;
  logic         data_out_ready_raw;

  // Intermediate signals
  logic         data_in_ready_stage;
  logic         data_out_ready_stage;

  logic start_sys, start_sync1, start_sync2;
  wire h2b_pulse;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_sys <= 1'b0;
    end else if (bnn_clear) begin
      start_sys <= 1'b0;  // explicit clear
    end else if (state == IDLE && bnn_enable) begin
      start_sys <= 1'b1;  // arm on bnn_enable in IDLE
    end else if (data_out_ready_stage) begin
      start_sys <= 1'b0;  // drop once BNN signals done
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_sync1 <= 1'b0;
      start_sync2 <= 1'b0;
    end else if (bnn_clk_en) begin
      start_sync1 <= start_sys;
      start_sync2 <= start_sync1;
    end
  end

  assign h2b_pulse = start_sync1 & ~start_sync2;
  assign data_in_ready_raw = start_sync2;

  logic data_out_ready_sync1, data_out_ready_sync2;

  logic [3:0] result_out_sync;
  logic [3:0] result_out_clk_sync1, result_out_clk_sync2;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_out_ready_sync1 <= 1'b0;
      data_out_ready_sync2 <= 1'b0;
      result_out_clk_sync1 <= 4'd0;
      result_out_clk_sync2 <= 4'd0;
    end else begin
      data_out_ready_sync1 <= data_out_ready_raw;
      data_out_ready_sync2 <= data_out_ready_sync1;
      result_out_clk_sync1 <= result_out_sync;
      result_out_clk_sync2 <= result_out_clk_sync1;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_out_sync <= 4'd0;
    end else if (bnn_clk_en && data_out_ready_raw) begin
      result_out_sync <= result_out_from_bnn_raw;
    end
  end

  assign result_out           = (|img_in_stage) ? result_out_internal : 4'd10;
  assign result_out_internal  = result_out_stage;
  assign result_ready         = result_ready_internal;
  assign data_out_ready_stage = data_out_ready_sync2;

  //------------------------------------------------------------------
  // BNN-core instantiation
  //------------------------------------------------------------------
  bnn_top u_bnn_top (
      .clk(bnn_clk_en),
      .conv1_img_in('{img_to_bnn_raw}),
      .data_in_ready(data_in_ready_raw),
      .result(result_out_from_bnn_raw),
      .data_out_ready(data_out_ready_raw)
  );

  //------------------------------------------------------------------
  // FSM
  //------------------------------------------------------------------
  bnn_state_t state, next_state;

  logic [899:0] img_in_stage;
  logic [  3:0] result_out_stage;

  always_comb begin
    next_state = state;
    case (state)
      IDLE: if (data_in_ready_stage) next_state = INFERENCE;
      INFERENCE: if (data_out_ready_stage) next_state = DONE;
      DONE: if (bnn_clear) next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Main sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;

      result_ready_internal <= 1'b0;
      data_in_ready_stage <= 1'b0;
      result_out_stage <= 4'd0;

      img_in_stage <= 900'd0;
      img_to_bnn_raw <= 900'd0;
    end else if (bnn_clear) begin
      state <= IDLE;

      result_ready_internal <= 1'b0;
      data_in_ready_stage <= 1'b0;
      result_out_stage <= 4'd0;

      img_in_stage <= 900'd0;
      img_to_bnn_raw <= 900'd0;
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          data_in_ready_stage   <= 1'b0;
          result_ready_internal <= 1'b0;
          img_to_bnn_raw        <= 900'd0;

          if (h2b_pulse) begin
            img_in_stage        <= img_in;
            img_to_bnn_raw      <= img_in;
            data_in_ready_stage <= 1'b1;
          end
        end

        INFERENCE: begin
          data_in_ready_stage <= 1'b0;
          if (data_out_ready_stage) begin
            result_out_stage <= result_out_clk_sync2;
            result_ready_internal <= 1'b1;
          end else data_in_ready_stage <= 1'b0;
        end

        DONE: begin
          if (bnn_clear) begin
            result_ready_internal <= 1'b0;  // clear result ready
          end else begin
            result_ready_internal <= 1'b1;  // hold ready until clear
          end
        end

        default: begin
          result_ready_internal <= 1'b0;
        end
      endcase
    end
  end

endmodule
