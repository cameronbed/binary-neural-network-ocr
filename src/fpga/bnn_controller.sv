`timescale 1ns / 1ps
//`include "spi_peripheral.sv"
//`include "bnn_module.sv"
module bnn_controller (
    input logic clk,   // System clock
    input logic rst_n, // Active-low rst_n

    // SPI
    input logic SCLK,  // SPI clock
    input logic COPI,  // Controller-out-Peripheral-In
    input logic CS,  // Chip Select
    output logic CIPO,  // Controller-in-Peripheral-Out
    output logic byte_ready,  // Added byte_ready signal

    // ---------- DEBUG --------------
    input  logic       debug_enable,        // Debug enable signal
    output logic [2:0] debug_state,         // Debug: current state
    output logic [7:0] debug_rx_byte,       // Debug: received byte
    output logic       debug_buffer_full,   // Debug: buffer full status
    output logic       debug_buffer_empty,  // Debug: buffer empty status
    output logic       debug_result_ready,  // Debug: result ready status
    output logic [3:0] debug_bit_count,     // Debug: SPI bit counter
    output logic [9:0] debug_write_addr,    // Debug: Image buffer write address
    output logic [7:0] debug_result_out,    // Debug: BNN result value
    output logic       debug_write_enable,  // New debug output for write enable
    output logic       debug_byte_valid,    // New debug output for byte_valid
    output logic       debug_spi_error,     // New debug output for SPI error

    // Exposed inputs
    input logic image_write_enable,  // Expose image_write_enable as input
    input logic [7:0] image_write_data,  // Expose image_write_data as input
    input logic clear_buffer  // Expose clear_buffer as input
);

  typedef enum logic [2:0] {
    IDLE,
    IMG_RX,
    INFERENCE,
    RESULT_TX,
    CLEAR
  } bnn_state_t;
  bnn_state_t state, next_state;

  // SPI Data
  logic [7:0] rx_byte;
  logic [7:0] tx_byte;  // Byte to be transmitted

  // SPI Control Signals
  logic byte_valid;
  logic buffer_full;
  logic buffer_empty;
  logic result_ready;
  logic valid_and_receiving;
  assign valid_and_receiving = byte_valid && (state == IMG_RX);

  // Add missing signal definitions
  logic rx_enable;  // Define rx_enable
  logic tx_enable;  // Define tx_enable

  // New signal for bnn_module write_enable
  logic bnn_write_enable;
  assign bnn_write_enable = (state == IMG_RX) ? valid_and_receiving : (state == INFERENCE);

  // New signals for result latching and tx blocking
  logic [7:0] tx_latched_result;  // Latches result_out at end of INFERENCE
  logic tx_sent;  // Flag to gate one-time transmission

  // SPI Debug Signals
  logic spi_error;  // Error indication

  logic [7:0] result_out;
  logic bnn_debug_write_enable;
  logic bnn_debug_result_ready;
  logic [7:0] bnn_debug_result_out;
  logic [1:0] spi_debug_state;
  logic [3:0] spi_debug_bit_count;
  logic [7:0] spi_debug_rx_byte;

  // Internal image buffer
  logic image_buffer_flat[0:783];  // Each pixel is a single bit
  logic [9:0] write_addr_counter;  // Internal counter for write address

  // ----------------------- DEBUG Latching -----------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      debug_state        <= 3'b0;
      debug_rx_byte      <= 8'd0;
      debug_result_ready <= 1'b0;
      debug_result_out   <= 0;
    end else begin
      debug_state        <= state;  // Now mirrors actual current state
      debug_rx_byte      <= rx_byte;
      debug_result_ready <= result_ready;
    end
    if (result_ready) begin
      debug_result_out <= result_out;
    end
  end

  // ----------------------- FSM Control -----------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;  // Ensure FSM starts in IDLE state
      debug_state <= IDLE;  // Ensure debug_state matches FSM state
    end else begin
      state <= next_state;
      debug_state <= state;  // Update debug_state to reflect current FSM state
    end
  end

  // ----------------------- Image Buffer Write Logic -----------------------
  // ----------------------- Buffer Status Logic -----------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || clear_buffer) begin
      write_addr_counter <= 10'd0;
      buffer_full <= 1'b0;
      buffer_empty <= 1'b1;

      // Clear entire image buffer
      for (int i = 0; i < 784; i++) begin
        image_buffer_flat[i] = 1'b0;  // Blocking is okay here
      end

      if (debug_enable) begin
        $display("[BNN_CTRL] Reset or clear_buffer: write_addr_counter reset to 0 at time=%0t",
                 $time);
      end

    end else if (image_write_enable && !buffer_full) begin
      if (write_addr_counter < 10'd784) begin
        image_buffer_flat[write_addr_counter] <= image_write_data[0];
        write_addr_counter <= write_addr_counter + 10'd1;
      end else begin
        if (debug_enable) $display("[BNN_CTRL] Warning: Write past buffer limit.");
      end

      // Update buffer flags
      buffer_full  <= (write_addr_counter + 1 == 10'd784);  // +1 because we're writing now
      buffer_empty <= 1'b0;

    end else begin
      // Maintain flags if no write
      buffer_full  <= (write_addr_counter == 10'd784);
      buffer_empty <= (write_addr_counter == 10'd0);
    end
  end

  // ----------------------- FSM Next-State Logic ----------------------
  always_comb begin
    next_state = state;  // Default: remain in current state
    case (state)
      IDLE: begin
        if (!CS) next_state = IMG_RX;
      end
      IMG_RX: begin
        if (buffer_full) begin
          next_state = INFERENCE;
          if (debug_enable)
            $display("[BNN_CTRL] Transition: IMG_RX -> INFERENCE at time=%0t", $time);
        end
      end
      INFERENCE: begin
        if (result_ready) begin
          next_state = RESULT_TX;
          if (debug_enable)
            $display("[BNN_CTRL] Transition: INFERENCE -> RESULT_TX at time=%0t", $time);
        end
      end
      RESULT_TX: begin
        if (CS) begin
          next_state = CLEAR;
          if (debug_enable)
            $display("[BNN_CTRL] Transition: RESULT_TX -> CLEAR at time=%0t", $time);
        end
      end
      CLEAR: begin
        if (buffer_empty) begin
          next_state = IDLE;
          if (debug_enable) $display("[BNN_CTRL] Transition: CLEAR -> IDLE at time=%0t", $time);
        end
      end
      default: ;
    endcase
    // Optional: Soft SPI reset when error occurs during IMG_RX
    if (spi_error && state == IMG_RX) begin
      if (debug_enable)
        $display("[BNN_CTRL] Soft SPI reset triggered due to spi_error at time=%0t", $time);
      next_state = IDLE;
    end
  end

  // ----------------------- Result Latching -----------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) tx_latched_result <= 8'd0;
    // Latch result when transitioning to RESULT_TX
    else if (next_state == RESULT_TX && result_ready) tx_latched_result <= result_out;
  end

  // ----------------------- tx_sent Flag -----------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) tx_sent <= 1'b0;
    else if (state != RESULT_TX) tx_sent <= 1'b0;
    // Guard with byte_valid to confirm transmission
    else if (state == RESULT_TX && byte_valid && !byte_ready && !tx_sent) tx_sent <= 1'b1;
  end

  // ----------------------- SPI + BNN Control Signals -----------------------
  always_comb begin
    // Default values
    rx_enable = 1'b0;
    tx_enable = 1'b0;
    tx_byte   = 8'd0;

    case (state)
      IMG_RX: begin
        rx_enable = byte_valid;
      end
      RESULT_TX: begin
        if (!byte_ready && !tx_sent) begin
          tx_enable = 1'b1;
          tx_byte   = tx_latched_result;
        end
      end
      default: begin
        rx_enable = 1'b0;
        tx_enable = 1'b0;
      end
    endcase
  end

  // ----------------------- Debugging Signals -----------------------
  always_comb begin
    debug_write_addr   = write_addr_counter;
    debug_write_enable = image_write_enable;
    debug_buffer_full  = buffer_full;
    debug_buffer_empty = buffer_empty;
    debug_byte_valid   = byte_valid;
    debug_bit_count    = spi_debug_bit_count;
    debug_spi_error    = spi_error;  // Expose the SPI error status for debug
  end

  // Connect byte_ready to SPI peripheral
  assign byte_ready = (state == IMG_RX) && !buffer_full;

  // ----------------------- Submodule Instantiations -----------------------
  spi_peripheral spi_peripheral_inst (
      .clk  (clk),
      .rst_n(rst_n),
      .SCLK (SCLK),
      .COPI (COPI),
      .CS   (CS),
      .CIPO (CIPO),

      // Control signals input
      .byte_ready(byte_ready),  // Byte ready signal
      .rx_enable (rx_enable),   // Enable for receiving data
      .tx_enable (tx_enable),   // Enable for transmitting data

      // Control signals output
      .tx_byte   (tx_byte),     // Byte to be transmitted
      .rx_byte   (rx_byte),     // PI data output
      .byte_valid(byte_valid),  // valid indicator
      .spi_error (spi_error),   // Error indication

      // Add debug connections
      .debug_enable   (debug_enable),         // Debug enable signal
      .debug_state    (spi_debug_state),      // 2 bits
      .debug_bit_count(spi_debug_bit_count),  // 4 bits
      .debug_rx_byte  (spi_debug_rx_byte)     // 8 bits
  );

  bnn_module bnn_module_inst (
      .clk  (clk),
      .rst_n(rst_n),

      // Data
      .img_in(image_buffer_flat),  // Use unpacked array
      .result_out(result_out),  // 8 bits

      // Control signals
      .write_enable(bnn_write_enable),
      .result_ready(result_ready),

      // ------------- Debug signals ---------------
      .debug_enable(debug_enable),  // Debug enable signal
      .debug_write_enable(bnn_debug_write_enable),
      .debug_result_ready(bnn_debug_result_ready),
      .debug_result_out(bnn_debug_result_out)  // 8 bits
  );

endmodule
