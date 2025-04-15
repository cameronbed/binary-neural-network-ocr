`timescale 1ns / 1ps

module controller_fsm (
    input logic clk,
    input logic rst_n,

    // Inputs from submodules / external
    input  logic CS,            // Chip Select from SPI master
    input  logic byte_valid,    // SPI byte received
    output logic byte_ready,    // SPI byte ready signal
    input  logic spi_error,     // SPI error flag
    input  logic buffer_full,
    input  logic buffer_empty,
    input  logic result_ready,

    // Outputs to control other modules
    output logic       rx_enable,            // Enables SPI RX
    output logic       tx_enable,            // Enables SPI TX
    output logic       clear_buffer,         // Resets buffer
    output logic       buffer_write_enable,  // Enables inference/load
    output logic [2:0] current_state         // Expose state for debug
);

  // -------------------------
  // State Definition
  // -------------------------
  typedef enum logic [2:0] {
    IDLE,
    RX,
    IMG_RX,
    INFERENCE,
    RESULT_RDY,
    TX,
    CLEAR
  } system_state_t;
  system_state_t fsm_state, fsm_next_state, fsm_prev_state;

  // -------------------------
  // State Register
  // -------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) fsm_state <= IDLE;
    else fsm_state <= fsm_next_state;
  end

  // -------------------------
  // Next-State Logic
  // -------------------------
  always_comb begin
    fsm_next_state = fsm_state;
    case (fsm_state)
      IDLE: if (!CS) fsm_next_state = RX;  // Ensure transition to RX on CS low

      RX: begin
        if (CS) fsm_next_state = IDLE;  // CS high, go to IDLE
        else if (byte_valid) fsm_next_state = IMG_RX;  // Byte received, go to IMG_RX
      end

      IMG_RX: begin
        if (buffer_full) fsm_next_state = INFERENCE;  // Buffer full, go to INFERENCE
        else if (CS) fsm_next_state = IDLE;  // CS high, go to IDLE
        else if (byte_valid) fsm_next_state = IMG_RX;  // Byte received, stay in IMG_RX
      end

      INFERENCE: if (result_ready) fsm_next_state = RESULT_RDY;

      RESULT_RDY: if (CS) fsm_next_state = CLEAR;

      TX: begin
        if (CS) fsm_next_state = IDLE;  // CS high, go to IDLE
        else if (buffer_empty) fsm_next_state = IDLE;  // Buffer empty, go to IDLE
      end

      CLEAR: if (buffer_empty) fsm_next_state = IDLE;

      default: fsm_next_state = IDLE;  // Add default case to handle incomplete coverage
    endcase
  end

  // -------------------------
  // Output / Control Logic
  // -------------------------
  always_comb begin
    // Default values
    rx_enable           = 1'b0;
    tx_enable           = 1'b0;
    clear_buffer        = 1'b0;
    buffer_write_enable = 1'b0;
    byte_ready          = 1'b0;

    case (fsm_state)
      IDLE: begin
        rx_enable = 1'b0;  // Disable RX in IDLE
        buffer_write_enable = 1'b0;  // Disable BNN write in IDLE
      end

      RX: begin
        rx_enable = 1'b1;  // Enable RX when in RX state
        buffer_write_enable = 1'b0;  // Disable BNN write in RX
      end

      IMG_RX: begin
        rx_enable = byte_valid;
        buffer_write_enable = byte_valid;  // Write each valid byte into image buffer
      end

      INFERENCE: begin
      end

      RESULT_RDY: begin
      end

      TX: begin
        tx_enable  = 1'b1;
        byte_ready = 1'b1;  // Tell SPI to begin shifting out the byte
      end

      CLEAR: begin
        clear_buffer = 1'b1;
      end

      default: ;
    endcase
  end

endmodule
