`timescale 1ns / 1ps

module controller_fsm (
    input logic clk,
    input logic rst_n,

    // SPI interface
    input  logic [7:0] spi_rx_data,
    input  logic       spi_byte_valid,
    output logic       byte_taken,
    output logic       rx_enable,

    // Commands output signals
    output logic [3:0] status_code_reg,

    // Image Buffer
    input  logic buffer_full,
    input  logic buffer_empty,
    output logic clear,

    output logic buffer_write_request,
    input  logic buffer_write_ready,

    output logic [7:0] buffer_write_data,
    output logic [6:0] buffer_write_addr,

    // BNN interface
    input  logic result_ready,
    output logic bnn_enable
);
  // Receive codes
  parameter logic [7:0] CMD_IMG_SEND_REQUEST = 8'hFE;  // 11111101
  parameter logic [7:0] CMD_CLEAR = 8'hFD;  // 11111011

  // Status codes
  localparam logic [3:0] STATUS_IDLE = 4'b0000;  // 0 - FPGA idle, ready
  localparam logic [3:0] STATUS_RX_IMG_RDY = 4'b0001;  // 1 - Receiving image bytes
  localparam logic [3:0] STATUS_RX_IMG = 4'b0010;  // 2 - SPI bytes sent are being put in the buffer
  localparam logic [3:0] STATUS_BNN_BUSY = 4'b0100;  //  4 - Image received, BNN running
  localparam logic [3:0] STATUS_RESULT_RDY = 4'b1000;  // 8 - BNN result ready
  localparam logic [3:0] STATUS_ERROR = 4'b1110;  // 14 - Error occurred
  localparam logic [3:0] STATUS_UNKNOWN = 4'b1111;  // 15- busy

  // FSM states (now 4 bits)
  typedef enum logic [2:0] {
    S_IDLE,
    S_WAIT_IMAGE,
    S_IMG_RX,
    S_WAIT_FOR_BNN,
    S_RESULT_RDY,
    S_CLEAR
  } fsm_state_t;

  fsm_state_t current_state, next_state;

  logic [3:0] next_status_code_reg;

  logic [3:0] status_code_reg_ff1, status_code_reg_ff2;

  logic [6:0] buffer_write_addr_int;

  logic byte_taken_comb;
  logic prev_spi_byte_valid;
  logic new_spi_byte;
  logic buffer_full_sync;

  //===================================================
  // FSM Next, Status Code, Buffer Write Address Register
  //===================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= S_IDLE;
      status_code_reg_ff1 <= STATUS_IDLE;
      buffer_write_addr_int <= 0;
      byte_taken <= 0;
      prev_spi_byte_valid <= 0;
      buffer_full_sync <= 0;

    end else begin
      current_state       <= next_state;

      status_code_reg_ff1 <= next_status_code_reg;
      status_code_reg_ff2 <= status_code_reg_ff1;

      byte_taken          <= byte_taken_comb;
      prev_spi_byte_valid <= spi_byte_valid;
      buffer_full_sync    <= buffer_full;

      if (current_state == S_IDLE && spi_byte_valid && spi_rx_data == CMD_CLEAR)
        buffer_write_addr_int <= 0;
      else if (current_state == S_IMG_RX && new_spi_byte)
        buffer_write_addr_int <= buffer_write_addr_int + 1;
    end
  end

  assign status_code_reg = status_code_reg_ff2;
  assign new_spi_byte = spi_byte_valid && !prev_spi_byte_valid;

  //===================================================
  // FSM State
  //===================================================
  always_comb begin
    byte_taken_comb = 0;
    rx_enable = 0;
    buffer_write_data = 0;
    buffer_write_addr = buffer_write_addr_int;
    bnn_enable = 0;
    clear = 0;
    buffer_write_request = 0;

    next_state = current_state;
    next_status_code_reg = status_code_reg_ff2;

    case (current_state)
      S_IDLE: begin
        rx_enable = 1;
        next_status_code_reg = STATUS_IDLE;

        if (buffer_full_sync) begin
          next_state = S_WAIT_FOR_BNN;
          next_status_code_reg = STATUS_BNN_BUSY;

        end else if (new_spi_byte) begin
          if (spi_rx_data == CMD_CLEAR) begin
            next_state = S_CLEAR;
            next_status_code_reg = STATUS_IDLE;
            clear = 1;
            byte_taken_comb = 1;

          end else if (spi_rx_data == CMD_IMG_SEND_REQUEST) begin
            next_state = S_WAIT_IMAGE;
            next_status_code_reg = STATUS_RX_IMG_RDY;
            byte_taken_comb = 1;

          end else begin
            next_status_code_reg = STATUS_ERROR;
            byte_taken_comb = 1;
          end
        end else begin
          next_status_code_reg = STATUS_IDLE;
        end
      end

      S_WAIT_IMAGE: begin
        rx_enable = 1;
        next_status_code_reg = STATUS_RX_IMG_RDY;

        if (new_spi_byte) begin
          if (spi_byte_valid) begin
            next_state           = S_IMG_RX;
            next_status_code_reg = STATUS_RX_IMG;
            byte_taken_comb      = 1;
            buffer_write_request = 1;
            buffer_write_data    = spi_rx_data;
          end
        end
      end

      S_IMG_RX: begin
        rx_enable = 1;
        next_status_code_reg = STATUS_RX_IMG;

        if (buffer_full_sync) begin
          bnn_enable = 1;
          next_state = S_WAIT_FOR_BNN;
          next_status_code_reg = STATUS_BNN_BUSY;

        end else if (new_spi_byte) begin
          if (spi_rx_data == CMD_CLEAR) begin
            next_state = S_CLEAR;
            next_status_code_reg = STATUS_IDLE;
            clear = 1;
            byte_taken_comb = 1;

          end else begin
            buffer_write_request = 1;
            buffer_write_data = spi_rx_data;
            byte_taken_comb = 1;
            next_status_code_reg = STATUS_RX_IMG;
          end
        end
      end

      S_WAIT_FOR_BNN: begin
        rx_enable = 1;
        next_status_code_reg = STATUS_BNN_BUSY;

        if (result_ready) begin
          next_state = S_RESULT_RDY;
          next_status_code_reg = STATUS_RESULT_RDY;

        end else if (new_spi_byte) begin
          if (spi_rx_data == CMD_CLEAR) begin
            next_state = S_CLEAR;
            next_status_code_reg = STATUS_IDLE;
            clear = 1;
            byte_taken_comb = 1;
          end
        end
      end

      S_RESULT_RDY: begin
        rx_enable = 1;
        next_status_code_reg = STATUS_RESULT_RDY;

        if (new_spi_byte && spi_rx_data == CMD_CLEAR) begin
          next_state = S_CLEAR;
          next_status_code_reg = STATUS_IDLE;
          byte_taken_comb = 1;
        end
      end

      S_CLEAR: begin
        clear = 1;
        if (buffer_empty) begin
          next_state = S_IDLE;
          next_status_code_reg = STATUS_IDLE;
        end
      end

      default: begin
        next_state = S_IDLE;
        next_status_code_reg = STATUS_ERROR;
      end
    endcase
  end

endmodule
