`timescale 1ns / 1ps

`ifndef SYNTHESIS
`include "spi_peripheral.sv"
`include "bnn_interface.sv"
`include "debug_module.sv"
`include "fsm_controller.sv"
`include "image_buffer.sv"
`endif

module system_controller (
    input logic clk,
    input logic rst_n_pin,
    input logic rst_n_sw_input,

    // SPI
    input logic SCLK,
    input logic COPI,
    input logic spi_cs_n,

    // System Outputs
    output logic [3:0] status_code_reg,
    output logic [6:0] seg,

    output logic heartbeat,

`ifndef SYNTHESIS
    input logic debug_trigger
`endif
);
  //===================================================
  // Internal Signals
  //===================================================
  logic rst_n;
  logic result_ready;

  assign rst_n = rst_n_pin;

  // -------------- Debounch the switch ---------------------
  logic sw_sync_0, sw_sync_1;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sw_sync_0 <= 0;
      sw_sync_1 <= 0;
    end else begin
      sw_sync_0 <= rst_n_sw_input;
      sw_sync_1 <= sw_sync_0;
    end
  end

  // ---------------------- Cycle Counters ----------------------
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
  logic [6:0] seg_next;

  always_comb begin
    if (!result_ready) begin
      seg_next = 7'b111_1111;  // blank when no result
    end else begin
      case (result_out)
        4'b0000: seg_next = 7'b100_0000;  // Display 0
        4'b0001: seg_next = 7'b111_1001;  // Display 1
        4'b0010: seg_next = 7'b010_0100;  // Display 2
        4'b0011: seg_next = 7'b011_0000;  // Display 3
        4'b0100: seg_next = 7'b001_1001;  // Display 4
        4'b0101: seg_next = 7'b001_0010;  // Display 5
        4'b0110: seg_next = 7'b000_0010;  // Display 6
        4'b0111: seg_next = 7'b111_1000;  // Display 7
        4'b1000: seg_next = 7'b000_0000;  // Display 8
        4'b1001: seg_next = 7'b001_0000;  // Display 9
        default: seg_next = 7'b111_1111;  // Blank
      endcase
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) seg <= 7'b1111111;
    else seg <= seg_next;
  end

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

      .buffer_write_data(buffer_write_data),
      .buffer_write_addr(buffer_write_addr),

      // BNN Interface
      .result_ready(result_ready),
      .bnn_enable  (bnn_enable)
  );

  //===================================================
  // SPI Peripheral
  //===================================================

  logic spi_byte_valid;
  logic byte_taken;

  spi_peripheral spi_peripheral_inst (
      .rst_n(rst_n),
      .clk  (clk),

      // SPI Pins
      .SCLK(SCLK),
      .COPI(COPI),
      .spi_cs_n(spi_cs_n),

      // Data Interface
      .spi_rx_data(spi_rx_data),

      // Control Signals
      .rx_enable (spi_rx_enable),
      .byte_valid(spi_byte_valid),
      .byte_taken(byte_taken)
  );

  //===================================================
  // Image Buffer
  //===================================================
  logic [903:0] image_buffer_internal;


  image_buffer u_image_buffer (
      .clk  (clk),
      .rst_n(rst_n),

      // inputs
      .write_request(buffer_write_request),
      .write_ready  (buffer_write_ready),

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
      .img_buffer_full(buffer_full),
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
