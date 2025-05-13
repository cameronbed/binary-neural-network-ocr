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
    input  logic bnn_clear
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
  // *** cosmetic aliases deleted ***
  // logic [899:0] img_in_internal;
  // logic         bnn_enable_internal;
  // logic         bnn_clear_internal;

  logic         result_ready_internal;
  logic [  3:0] result_out_internal;

  // BNN-core interface
  logic [899:0] img_to_bnn_raw;
  logic         data_in_ready_raw;
  logic [  3:0] result_out_from_bnn_raw;
  logic         data_out_ready_raw;

  // Handshake and staging
  logic [  3:0] result_out_stage;
  logic         data_in_ready_stage;
  logic         data_out_ready_stage;
  logic [899:0] img_in_stage;

  //------------------------------------------------------------------
  // Handshake: host → BNN  (request)  and  BNN → host  (done)
  //------------------------------------------------------------------
  //   Two independent toggle/acknowledge channels:
  //   h2b_req_tog_*  : flips once when host wants a new inference
  //   b2h_done_tog_* : flips once when BNN finishes that inference

  // Toggles in the host clock domain
  logic         h2b_req_tog_clk;  // host request
  logic         b2h_ack_tog_clk;  // host ack back to BNN
  logic         b2h_done_tog_clk;  // BNN-done, synchronised
  // Toggles in the BNN (slow) domain
  logic         h2b_req_tog_bnn;
  logic         b2h_ack_tog_bnn;
  logic         b2h_done_tog_bnn;

  //---------------- Host generates request toggle ------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) h2b_req_tog_clk <= 1'b0;
    else if (bnn_clear) h2b_req_tog_clk <= 1'b0;
    else if (state==IDLE && bnn_enable &&
             (h2b_req_tog_clk == b2h_ack_tog_clk))   // previous job acked
      h2b_req_tog_clk <= ~h2b_req_tog_clk;
  end

  //---------------- Sync request into BNN domain -------------------
  logic [1:0] h2b_sync;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) h2b_sync <= 2'b00;
    else if (bnn_clk_en) h2b_sync <= {h2b_sync[0], h2b_req_tog_clk};
  end
  assign h2b_req_tog_bnn = h2b_sync[1];

  //---------------- BNN flips done toggle when finished ------------

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) b2h_done_tog_bnn <= 1'b0;
    else if (bnn_clk_en && data_out_ready_raw) b2h_done_tog_bnn <= ~b2h_done_tog_bnn;
  end

  //---------------- Sync done into host domain ---------------------
  logic [1:0] b2h_sync;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) b2h_sync <= 2'b00;
    else b2h_sync <= {b2h_sync[0], b2h_done_tog_bnn};
  end
  assign b2h_done_tog_clk = b2h_sync[1];

  //---------------- Host sends acknowledge back to BNN -------------
  // Acknowledge once we have captured the result in the INFERENCE state
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) b2h_ack_tog_clk <= 1'b0;
    else if (state == INFERENCE && (b2h_done_tog_clk != b2h_ack_tog_clk))
      b2h_ack_tog_clk <= b2h_done_tog_clk;
  end

  // Sync ack into BNN domain
  logic [1:0] ack_h2b_sync;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) ack_h2b_sync <= 2'b00;
    else if (bnn_clk_en) ack_h2b_sync <= {ack_h2b_sync[0], b2h_ack_tog_clk};
  end
  assign b2h_ack_tog_bnn = ack_h2b_sync[1];

  //------------------------------------------------------------------
  // Level equivalents used by the FSM
  //------------------------------------------------------------------
  wire data_in_ready_stage = (h2b_req_tog_clk != b2h_ack_tog_clk);
  wire data_out_ready_stage = (b2h_done_tog_clk != b2h_ack_tog_clk);

  // Handshake to the slow domain
  assign data_in_ready_raw = (h2b_req_tog_bnn != b2h_ack_tog_bnn);

  //------------------------------------------------------------------
  // Result-bus capture (same as original design, still pulse-based)
  //------------------------------------------------------------------
  logic [3:0] result_out_sync;
  logic [3:0] result_out_clk_sync1, result_out_clk_sync2;

  // Capture in slow (BNN) domain
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) result_out_sync <= 4'd0;
    else if (bnn_clk_en && data_out_ready_raw) result_out_sync <= result_out_from_bnn_raw;
  end
  // Two-FF sync into host domain
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_out_clk_sync1 <= 4'd0;
      result_out_clk_sync2 <= 4'd0;
    end else begin
      result_out_clk_sync1 <= result_out_sync;
      result_out_clk_sync2 <= result_out_clk_sync1;
    end
  end

  //------------------------------------------------------------------
  // Core BNN instantiation
  //------------------------------------------------------------------
  bnn_top u_bnn_top (
      .clk           (bnn_clk_en),
      .conv1_img_in  ('{img_to_bnn_raw}),
      .data_in_ready (data_in_ready_raw),
      .result        (result_out_from_bnn_raw),
      .data_out_ready(data_out_ready_raw)
  );

  //------------------------------------------------------------------
  // FSM
  //------------------------------------------------------------------
  bnn_state_t state, next_state;

  logic [899:0] img_in_stage;
  logic [  3:0] result_out_stage;

  // Next-state logic
  always_comb begin
    next_state = state;
    unique case (state)
      IDLE:      if (data_in_ready_stage) next_state = INFERENCE;
      INFERENCE: if (data_out_ready_stage) next_state = DONE;
      DONE:      if (bnn_clear) next_state = IDLE;
      default:   next_state = IDLE;
    endcase
  end

  // Sequential part
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= IDLE;
      result_ready     <= 1'b0;
      result_out_stage <= 4'd0;
      img_in_stage     <= 900'd0;
      img_to_bnn_raw   <= 900'd0;
    end else if (bnn_clear) begin
      state            <= IDLE;
      result_ready     <= 1'b0;
      result_out_stage <= 4'd0;
      img_in_stage     <= 900'd0;
      img_to_bnn_raw   <= 900'd0;
    end else begin
      state <= next_state;

      unique case (state)
        //----------------------------------------------------------
        IDLE: begin
          result_ready          <= 1'b0;
          img_to_bnn_raw        <= 900'd0;
          result_ready_internal <= 1'b0;
          img_to_bnn_raw        <= 900'd0;

          if (data_in_ready_stage) begin  // new inference armed
            img_in_stage   <= img_in;
            img_to_bnn_raw <= img_in;
          end
        end

        //----------------------------------------------------------
        INFERENCE: begin
          data_in_ready_stage <= 1'b0;
          if (data_out_ready_stage) begin
            result_out_stage      <= result_out_clk_sync2;
            result_ready_internal <= 1'b1;
          end
        end

        //----------------------------------------------------------
        DONE: begin
          if (bnn_clear) result_ready_internal <= 1'b0;
          else result_ready_internal <= 1'b1;
        end
        //----------------------------------------------------------
        default: result_ready <= 1'b0;
      endcase
    end
  end

  //------------------------------------------------------------------
  // Output data mux (keeps the old “10 if image all-zero” rule)
  //------------------------------------------------------------------
  assign result_out = (|img_in_stage) ? result_out_stage : 4'd10;

endmodule
