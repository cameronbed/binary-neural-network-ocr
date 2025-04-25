`timescale 1ns / 1ps
`ifdef SYNTHESIS
    `include "spi_peripheral.sv"
    `include "bnn_interface.sv"
    `include "debug_module.sv"
    `include "fsm_controller.sv"
    `include "image_buffer.sv"
`endif
module system_controller (
    input logic clk,
    input logic rst_n_pin,
    input logic rst_n_btn,

    // SPI
    input logic SCLK,
    input logic COPI,
    input logic spi_cs_n,
    output logic [6:0] seg,

    // Control Signals
    output logic result_ready_pin,
    output logic send_image_pin,
    output logic status_ready_pin,

    // FPGA Output
    output logic result_ready_led,
    output logic send_image_led,
    output logic status_ready_led,

    output logic heartbeat

`ifndef SYNTHESIS,
    input logic debug_trigger
`endif
);
  //===================================================
  // Internal Signals
  //===================================================
    logic rst_n;
    logic result_ready;
    logic send_image;
    logic status_ready;

    assign rst_n = rst_n_pin || rst_n_btn;

    assign result_ready_pin = result_ready;
    assign result_ready_led = result_ready;

    assign send_image_led = send_image;
    assign send_image_pin = send_image;

    assign status_ready_led = status_ready;
    assign status_ready_pin = status_ready;

  // ------------------------ FSM Controller ---------------
  logic rx_enable;
  logic infer_start;
  logic buffer_full, buffer_empty, clear_buffer;
  logic [3:0] fsm_state; 

  // ------------------------ SPI Peripheral ---------------
  logic [  7:0] spi_rx_data; 
  logic         spi_byte_valid;
  logic         byte_taken;

  // ---------------------- Image Buffer ---------------
  logic [903:0] image_flat;
  logic [  9:0] write_addr;
  logic         buffer_write_enable;

  // ------------------- BNN Interface
  logic         bnn_start;
  logic [3:0]  result_out_int;
  logic [3:0] result_out_latched;

  // ---------------------- Hearbeat
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) heartbeat <= 0;
    else heartbeat <= ~heartbeat;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        result_out_latched <= 4'b0000; // Reset to 0
    end else if (result_ready) begin
        result_out_latched <= result_out; // Latch the result
    end
  end

// 7-segment decoder logic
always_comb begin
    case (result_out_latched)
        4'b0000: seg = 7'b1000000; // Display 0
        4'b0001: seg = 7'b1111001; // Display 1
        4'b0010: seg = 7'b0100100; // Display 2
        4'b0011: seg = 7'b0110000; // Display 3
        4'b0100: seg = 7'b0011001; // Display 4
        4'b0101: seg = 7'b0010010; // Display 5
        4'b0110: seg = 7'b0000010; // Display 6
        4'b0111: seg = 7'b1111000; // Display 7
        4'b1000: seg = 7'b0000000; // Display 8
        4'b1001: seg = 7'b0010000; // Display 9
        default: seg = 7'b1111111; // Blank
    endcase
end

  // ----------------------- FSM Controller Instantiation -----------------------
  controller_fsm u_controller_fsm (
      .clk(clk),
      .rst_n(rst_n),
      .heartbeat(heartbeat),

      // SPI
      .spi_cs_n(spi_cs_n),
      .spi_byte_valid(spi_byte_valid),
      .spi_rx_data(spi_rx_data), 
      .rx_enable(rx_enable),
      .byte_taken(byte_taken),

      // Commands
      .send_image  (send_image),
      .status_ready(status_ready),

      // Image Buffer
      .buffer_full(buffer_full),
      .buffer_empty(buffer_empty),
      .clear_buffer(clear_buffer),
      .buffer_write_enable(buffer_write_enable),

      // BNN Interface
      .result_ready(result_ready),
      .result_out(result_out),
      .bnn_start(bnn_start),

      .fsm_state(fsm_state)
  );

  // ----------------------- Submodule Instantiations -----------------------
  spi_peripheral spi_peripheral_inst (
      .clk(clk),
      .rst_n(rst_n),

      // SPI Pins
      .SCLK(SCLK),
      .COPI(COPI),
      .spi_cs_n(spi_cs_n),

      // Data Interface
      .spi_rx_data(spi_rx_data), 

      // Control Signals
      .rx_enable(rx_enable), 
      .spi_byte_valid(spi_byte_valid),
      .byte_taken(byte_taken)
  );

  //===================================================
  // BNN Interface 
  //===================================================
  bnn_interface u_bnn_interface (
      .clk  (clk),
      .rst_n(rst_n),

      // Data
      .img_in(image_flat),  // Packed vector matches declaration
      .result_out(result_out),  // Match 4-bit width

      // Control signals
      .img_buffer_full(buffer_full),
      .result_ready(result_ready),
      .bnn_start(bnn_start)
  );

  // -------------- Image Buffer  --------------
  image_buffer u_image_buffer (
      .clk         (clk),
      .rst_n       (rst_n),
      //
      .clear_buffer(clear_buffer),         // Pass clear_buffer to image_buffer
      .write_addr  (write_addr),
      .data_in     (spi_rx_data),
      .full        (buffer_full),
      .empty       (buffer_empty),
      .write_enable(buffer_write_enable),
      .img_out     (image_flat)            // Packed vector matches declaration
  );

`ifndef SYNTHESIS
  // ----------------- Debug Module Instantiation -----------------
  debug_module u_debug_module (
      .clk         (clk),
      .rst_n       (rst_n),         // <<< added rst_n connection
      .debug_enable(debug_trigger),

      // FSM
      .fsm_state(fsm_state),

      // SPI
      .spi_byte_valid(spi_byte_valid),
      .spi_rx_byte(spi_rx_data),

      // Image buffer
      .buffer_full        (buffer_full),
      .buffer_empty       (buffer_empty),
      .write_addr         (write_addr),
      .buffer_write_enable(buffer_write_enable),
      .buffer_data_in     (spi_rx_data),
      .img_in             (image_flat),

      // BNN
      .bnn_result_ready(result_ready),
      .bnn_result_out  (result_out)
  );
`endif

endmodule
