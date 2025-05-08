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
  localparam DIV = 4;

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
  logic [899:0] img_to_bnn_stage3[0:0];

  logic data_in_ready_stage1, data_in_ready_stage2, data_in_ready_stage3;

  logic result_ready_stage1, result_ready_stage2, result_ready_stage3;

  logic [3:0] result_out_stage1, result_out_stage2, result_out_stage3;

  logic [3:0] result_from_bnn;
  logic       result_ready_internal;
  logic       data_in_ready_int;

  logic       data_in_req;

  logic       result_ready_reg;
  logic [3:0] result_out_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_ready_reg <= 1'b0;
      result_out_reg   <= 4'b0;
    end else begin
      // latch the very first ready & data event
      if (result_ready_stage3) begin
        result_ready_reg <= 1'b1;
        result_out_reg   <= result_out_stage3;
      end  // clear on request
      else if (bnn_clear) begin
        result_ready_reg <= 1'b0;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_in_ready_int <= 1'b0;
    end else if (bnn_clk_en) begin
      if (img_buffer_full && bnn_enable) data_in_ready_int <= 1'b1;
      else if (result_ready_internal) data_in_ready_int <= 1'b0;
      // else                                 data_in_ready_int <= data_in_ready_int;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_in_req <= 1'b0;
    end else begin
      if (img_buffer_full && bnn_enable) data_in_req <= 1'b1;
      else if (result_ready_internal) data_in_req <= 1'b0;
    end
  end

  logic result_ready_req;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) result_ready_req <= 1'b0;
    else begin
      if (result_ready_internal) result_ready_req <= 1'b1;
      else if (result_ready_stage3) result_ready_req <= 1'b0;
    end
  end

  // 1) Full-rate latch of BNN’s output data
  logic [3:0] result_data_req;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) result_data_req <= 4'b0;
    else if (result_ready_internal) result_data_req <= result_from_bnn;
    // else keep the old data until you’ve pipelined it out
  end

  // =============== Clock Enable
  (* USE_DSP = "no", SHREG_EXTRACT = "no" *)logic [1:0] clk_div;
  logic       bnn_clk_en;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) clk_div <= 0;
    else clk_div <= clk_div + 1;
  end
  assign bnn_clk_en = (clk_div == 2'b00);
  // ======================

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_ready_stage1 <= 1'b0;
      result_ready_stage2 <= 1'b0;
      result_ready_stage3 <= 1'b0;

      result_out_stage1   <= 4'b0;
      result_out_stage2   <= 4'b0;
      result_out_stage3   <= 4'b0;

    end else if (bnn_clk_en) begin
      result_out_stage1   <= result_data_req;
      result_out_stage2   <= result_out_stage1;
      result_out_stage3   <= result_out_stage2;

      result_ready_stage1 <= result_ready_req;
      result_ready_stage2 <= result_ready_stage1;
      result_ready_stage3 <= result_ready_stage2;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      img_to_bnn_stage1[0] <= '0;
      img_to_bnn_stage2[0] <= '0;
      img_to_bnn_stage3[0] <= '0;

      data_in_ready_stage1 <= 1'b0;
      data_in_ready_stage2 <= 1'b0;
      data_in_ready_stage3 <= 1'b0;
    end else if (bnn_clk_en) begin
      data_in_ready_stage1 <= data_in_req;
      data_in_ready_stage2 <= data_in_ready_stage1;
      data_in_ready_stage3 <= data_in_ready_stage2;

      img_to_bnn_stage1[0] <= img_to_bnn[0];
      img_to_bnn_stage2[0] <= img_to_bnn_stage1[0];
      img_to_bnn_stage3[0] <= img_to_bnn_stage2[0];
    end
  end

  assign result_out   = result_out_reg;
  assign result_ready = result_ready_reg;

  // ----------------- BNN Module Instantiation -----------------
  bnn_top u_bnn_top (
      .clk           (bnn_clk_en),
      .conv1_img_in  (img_to_bnn_stage3),
      .data_in_ready (data_in_ready_stage3),
      .result        (result_from_bnn),
      .data_out_ready(result_ready_internal)
  );

  // ----------------------- FSM Next-State Logic ----------------------
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (data_in_ready_stage3) next_state = INFERENCE;
      end

      INFERENCE: begin
        if (result_ready_req) next_state = DONE;
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
      //result_ready <= 1'b0;
      state <= IDLE;

    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          //result_ready <= 1'b0;
        end

        INFERENCE: begin
          if (result_ready_stage3) begin
            //$display("[BNN_INTERFACE] @%0t result=%0d", $time, result_out);
            //result_ready <= 1'd1;
          end else begin
            //result_ready <= 1'b0;  // hold ready until result is available
          end
        end

        DONE: begin
          if (bnn_clear) begin
            //result_ready <= 1'b0;  // clear result ready
          end else begin
            //result_ready <= 1'b1;  // hold ready until clear
          end
        end

        default: begin
          //result_ready <= 1'b0;
        end
      endcase
    end
  end

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

endmodule
