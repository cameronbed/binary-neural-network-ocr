`ifndef SYNTHESIS
`include "spi_peripheral.sv"
`include "bnn_interface.sv"
`include "debug_module.sv"
`include "fsm_controller.sv"
`include "image_buffer.sv"
`endif`timescale 1ns / 1ps

module system_controller (
    input logic clk,
    input logic rst_n_pin,

    // SPI
    input logic SCLK,
    input logic COPI,
    input logic spi_cs_n,

    // System Outputs
    output logic [3:0] status_code_reg,
    output logic [6:0] seg,
    output logic decimalPoint,
    output logic [3:0] an,

    output logic heartbeat,

    // `ifndef SYNTHESIS
    input logic debug_trigger
    // `endif
);
  //===================================================
  // Internal Signals
  //===================================================
  logic result_ready;

  // ----------------- Synchronous Reset -----------------
  logic rst_sync_ff1;
  logic rst_sync_ff2;
  logic rst_n_pin_reg;
  logic rst_n;

  always_ff @(edge rst_n_pin) begin
    if (rst_n_pin) begin
      rst_n_pin_reg <= 1;
    end else begin
      rst_n_pin_reg <= 0;
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n_pin_reg) begin
      rst_sync_ff1 <= 1'b0;
      rst_sync_ff2 <= 1'b0;
    end else begin
      rst_sync_ff1 <= 1'b1;
      rst_sync_ff2 <= rst_sync_ff1;
    end
  end
  assign rst_n = rst_sync_ff2;

  // ---------------------- Cycle Counter ----------------------
`ifndef SYNTHESIS
  logic [31:0] main_cycle_cnt, sclk_cycle_cnt;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      main_cycle_cnt <= 0;
      sclk_cycle_cnt <= 0;
    end else begin
      main_cycle_cnt <= main_cycle_cnt + 1;
      if (SCLK) sclk_cycle_cnt <= sclk_cycle_cnt + 1;
    end
  end
`endif

  //------------------ Heartbeat Signal -----------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) heartbeat <= 0;
    else begin
      heartbeat <= ~heartbeat;
    end
  end

  //===================================================
  // 7-Segment Display
  //===================================================
  logic [3:0] result_out;
  logic [3:0] result_reg;
  logic       result_reg_valid;

  logic [6:0] seg_reg_stage1;
  logic [6:0] seg_reg_stage2;

  logic [3:0] digit_0, digit_1, digit_2, digit_3;
  logic [3:0] digit_vals[3:0];
  logic [1:0] digit_sel;
  logic [6:0] seg_out;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_reg       <= 4'd0;
      result_reg_valid <= 1'b0;
    end else begin
      result_reg_valid <= result_ready;
      if (result_ready) result_reg <= result_out;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      digit_3 <= 4'd0;
    end else if (result_reg_valid) begin
      digit_3 <= result_reg;
    end
  end

  always_comb begin
    digit_vals[0] = digit_0;
    digit_vals[1] = digit_1;
    digit_vals[2] = digit_2;
    digit_vals[3] = digit_3;
  end

  // multiplexer counter
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) digit_sel <= 2'd0;
    else digit_sel <= digit_sel + 1;
  end

  // drive the segments & anodes
  always_comb begin
    an            = 4'b1111;
    an[digit_sel] = 1'b0;  // active-low
    seg_out       = seven_segment_encode(digit_vals[digit_sel]);
    decimalPoint  = 1'b0;  // or control per digit_sel if you like
  end

  assign seg = seg_out;

  function logic [6:0] seven_segment_encode(input logic [3:0] v);
    case (v)
      4'd0: seven_segment_encode = 7'b100_0000;
      4'd1: seven_segment_encode = 7'b111_1001;
      4'd2: seven_segment_encode = 7'b010_0100;
      4'd3: seven_segment_encode = 7'b011_0000;
      4'd4: seven_segment_encode = 7'b001_1001;
      4'd5: seven_segment_encode = 7'b001_0010;
      4'd6: seven_segment_encode = 7'b000_0010;
      4'd7: seven_segment_encode = 7'b111_1000;
      4'd8: seven_segment_encode = 7'b000_0000;
      4'd9: seven_segment_encode = 7'b001_0000;
      default: seven_segment_encode = 7'b111_1111;
    endcase
  endfunction

  //===================================================
  // FSM Controller
  //===================================================
  logic spi_rx_enable;
  logic buffer_full, buffer_empty, clear_internal;
  logic [6:0] buffer_write_addr;
  logic [7:0] buffer_write_data;
  logic       bnn_enable;
  logic       buffer_write_request;
  logic       buffer_write_ready;
  logic [7:0] spi_rx_data;
  logic       spi_byte_valid;
  logic       byte_taken;
  logic       buffer_write_ack;

  controller_fsm u_controller_fsm (
      .clk  (clk),
      .rst_n(rst_n),

      // SPI
      .spi_rx_data(spi_rx_data),
      .spi_byte_valid(spi_byte_valid),
      .byte_taken(byte_taken),
      .rx_enable(spi_rx_enable),

      // Commands
      .status_code_reg(status_code_reg),
      .clear(clear_internal),

      // Image Buffer
      .buffer_full (buffer_full),
      .buffer_empty(buffer_empty),

      .buffer_write_request(buffer_write_request),
      .buffer_write_ready  (buffer_write_ready),
      .write_ack           (buffer_write_ack),

      .buffer_write_data(buffer_write_data),
      .buffer_write_addr(buffer_write_addr),

      // BNN Interface
      .result_ready(result_ready),
      .bnn_enable  (bnn_enable)
  );

  //===================================================
  // SPI Peripheral
  //===================================================
  logic spi_rx_data_is_zero;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) digit_1 <= 4'd0;
    else if (spi_rx_data_is_zero) digit_1 <= 4'd0;
  end

  spi_peripheral spi_peripheral_inst (
      .rst_n(rst_n),
      .clk  (clk),

      // SPI Pins
      .SCLK(SCLK),
      .COPI(COPI),
      .spi_cs_n(spi_cs_n),

      // Data Interface
      .spi_rx_data(spi_rx_data),
      .rx_data_is_zero(spi_rx_data_is_zero),


      // Control Signals
      .rx_enable (spi_rx_enable),
      .byte_valid(spi_byte_valid),
      .byte_taken(byte_taken)
  );

  //===================================================
  // Image Buffer
  //===================================================
  logic [899:0] image_buffer_internal;


  image_buffer u_image_buffer (
      .clk  (clk),
      .rst_n(rst_n),

      // inputs
      .write_request(buffer_write_request),
      .write_ready  (buffer_write_ready),
      .write_ack    (buffer_write_ack),

      .clear_buffer(clear_internal),
      .data_in     (buffer_write_data),

      //outputs
      .buffer_full (buffer_full),
      .buffer_empty(buffer_empty),
      .img_out     (image_buffer_internal)
  );

  //===================================================
  // BNN Interface 
  //===================================================
  bnn_interface u_bnn_interface (
      .clk  (clk),
      .rst_n(rst_n),

      // Data
      .img_in(image_buffer_internal),  // Packed vector matches declaration
      .result_out(result_out),  // Match 4-bit width

      // Control signals
      .result_ready(result_ready),
      .bnn_enable(bnn_enable),
      .bnn_clear(clear_internal)
  );

`ifndef SYNTHESIS
  // ----------------- Debug Module Instantiation -----------------
  debug_module u_debug_module (
      .clk         (clk),
      .rst_n       (rst_n),         // <<< added rst_n connection
      .debug_enable(debug_trigger),

      // FSM
      .spi_rx_data(spi_rx_data),
      .spi_byte_valid(spi_byte_valid),
      .byte_taken(byte_taken),
      .spi_rx_enable(spi_rx_enable),
      .status_code_reg(status_code_reg),
      .clear_internal(clear_internal),
      .buffer_full(buffer_full),
      .buffer_empty(buffer_empty),
      .buffer_write_data(buffer_write_data),
      .buffer_write_addr(buffer_write_addr),
      .result_ready(result_ready),
      .result_out(result_out),
      .bnn_enable(bnn_enable),

      // SPI
      .SCLK(SCLK),
      .COPI(COPI),
      .spi_cs_n(spi_cs_n),

      // Image buffer
      .clear_buffer(clear_internal),
      .data_in     (buffer_write_data),

      // BNN
      .img_in(image_buffer_internal),

      // Control signals
      .img_buffer_full(buffer_full),
      .bnn_clear(clear_internal),

      // Sync
      .src_clk  (SCLK),
      .src_pulse(spi_byte_valid),
      .dst_clk  (clk),
      .dst_pulse(byte_taken),

      // Cycles
      .main_cycle_cnt(main_cycle_cnt),
      .sclk_cycle_cnt(sclk_cycle_cnt)
  );
`endif

endmodule
