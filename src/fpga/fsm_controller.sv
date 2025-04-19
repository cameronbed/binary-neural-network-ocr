`timescale 1ns / 1ps

module controller_fsm (
    input logic clk,
    input logic rst_n,

    // SPI interface
    input  logic       spi_cs_n,
    input  logic [7:0] spi_rx_data,
    input  logic       spi_byte_valid,
    output logic       byte_taken,
    output logic       rx_enable,

    // Commands
    output logic send_image,
    output logic status_ready,

    // Image Buffer
    input  logic buffer_full,
    input  logic buffer_empty,
    output logic clear_buffer,
    output logic buffer_write_enable,

    // BNN interface
    input logic result_ready,
    input logic [3:0] result_out,
    output logic bnn_start,

    output logic [2:0] fsm_state
);

  // FSM states
  typedef enum logic [2:0] {
    S_IDLE,
    S_RX_CMD,
    S_CMD_LATCH,
    S_IMG_RX,
    S_CMD_DISPATCH,
    S_STATUS_READY,
    S_WAIT_INFERENCE,
    S_CLEAR
  } fsm_state_t;

  fsm_state_t ctrl_state, next_state;

  logic [7:0] command_byte;

  // Constants
  parameter int IMG_BIT_SIZE = 900;
  parameter logic [9:0] IMG_BYTE_SIZE = 10'd113;
  parameter int TIMEOUT_LIMIT = 100_000;
  parameter logic [7:0] STATUS_REQUEST_CODE = 8'hFE;
  parameter logic [7:0] IMG_TX_REQUEST_CODE = 8'hBF;

  // Internal state
  logic [31:0] cycle_cnt;
  logic [31:0] rx_timeout_cnt;
  logic [ 9:0] bytes_received;
  logic [ 9:0] debug_bytes_received;  // Explicitly declare debug_bytes_received

  // Async synchronizers
  logic cs_sync1, cs_sync2;
  logic byte_valid_sync1, byte_valid_sync2;
  logic result_ready_sync1, result_ready_sync2;
  logic buffer_empty_sync1, buffer_empty_sync2;

  // one‑cycle‑back copy for edge detect
  logic prev_byte_valid_sync2_ff;

  // Command latch
  logic status_request_reg;
  logic img_tx_request_reg;
  logic prev_status_request_reg, prev_img_tx_request_reg;  // Track previous values

  // Edge detection
  wire cs_falling = ~cs_sync1 && cs_sync2;
  wire cs_rising = cs_sync1 && ~cs_sync2;

  assign debug_bytes_received = bytes_received;

  logic status_ready_reg;
  logic send_image_reg;
  assign status_ready = status_ready_reg;
  assign send_image   = send_image_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      status_ready_reg <= 0;
    end else if (ctrl_state == S_STATUS_READY) begin
      status_ready_reg <= 1;
    end else if (ctrl_state == S_IDLE && next_state == S_RX_CMD) begin
      status_ready_reg <= 0;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      send_image_reg <= 0;
    end else if (ctrl_state == S_CMD_DISPATCH && img_tx_request_reg) begin
      send_image_reg <= 1;
    end else if (next_state == S_IDLE) begin
      send_image_reg <= 0;
    end
  end

  //===================================================
  // FSM Register
  //===================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) ctrl_state <= S_IDLE;
    else ctrl_state <= next_state;
  end

  //===================================================
  // Command Decoding
  //===================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      status_request_reg      <= 0;
      img_tx_request_reg      <= 0;
      prev_status_request_reg <= 0;
      prev_img_tx_request_reg <= 0;

    end else if (ctrl_state == S_RX_CMD && byte_valid_sync2) begin
      command_byte <= spi_rx_data;

    end else if (ctrl_state == S_CMD_LATCH) begin
      status_request_reg <= (command_byte == STATUS_REQUEST_CODE);
      img_tx_request_reg <= (command_byte == IMG_TX_REQUEST_CODE);

      $display("[FSM] Decoding command_byte = 0x%02X", command_byte);

      // Only print when there’s a change and the command is recognized
      if ((img_tx_request_reg != prev_img_tx_request_reg || status_request_reg != prev_status_request_reg) &&
        (img_tx_request_reg || status_request_reg)) begin
        $display("[FSM] Recognized command: IMG_TX=%b, STATUS=%b", img_tx_request_reg,
                 status_request_reg);
      end

      // Only print once for unrecognized commands
      if (!img_tx_request_reg && !status_request_reg &&
        (prev_img_tx_request_reg || prev_status_request_reg)) begin
        $display("[FSM] Unrecognized command: 0x%02X at cycle %0d", command_byte, cycle_cnt);
      end

      prev_status_request_reg <= status_request_reg;
      prev_img_tx_request_reg <= img_tx_request_reg;

    end else if (ctrl_state == S_IDLE) begin
      status_request_reg      <= 0;
      img_tx_request_reg      <= 0;
      prev_status_request_reg <= 0;
      prev_img_tx_request_reg <= 0;
    end
  end



  //===================================================
  // Byte Counter
  //===================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) bytes_received <= 0;
    else if (ctrl_state == S_IMG_RX && byte_valid_sync2 && !prev_byte_valid_sync2_ff)
      bytes_received <= bytes_received + 1;
    else if (ctrl_state == S_IDLE) bytes_received <= 0;
  end

  //===================================================
  // Timeout + Debug Counter
  //===================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_timeout_cnt <= 0;
      cycle_cnt <= 0;
    end else begin
      cycle_cnt <= cycle_cnt + 1;
      if (ctrl_state == S_RX_CMD || ctrl_state == S_IMG_RX) rx_timeout_cnt <= rx_timeout_cnt + 1;
      else rx_timeout_cnt <= 0;
    end
  end

  //===================================================
  // FSM Next State Logic
  //===================================================
  always_comb begin
    next_state = ctrl_state;

    case (ctrl_state)
      S_IDLE: if (cs_falling) next_state = S_RX_CMD;

      S_RX_CMD: begin
        if (rx_timeout_cnt >= TIMEOUT_LIMIT) next_state = S_IDLE;
        else if (byte_valid_sync2) next_state = S_CMD_LATCH;
      end

      S_CMD_LATCH: next_state = S_CMD_DISPATCH;

      S_CMD_DISPATCH:
      if (img_tx_request_reg) next_state = S_IMG_RX;
      else if (status_request_reg) next_state = S_STATUS_READY;

      S_STATUS_READY: next_state = S_IDLE;

      S_IMG_RX: begin
        if (bytes_received == IMG_BYTE_SIZE) begin
          next_state = S_WAIT_INFERENCE;  // Transition only after receiving all bytes
        end else if (rx_timeout_cnt >= TIMEOUT_LIMIT) begin
          next_state = S_IDLE;  // Handle timeout
        end else begin
          next_state = S_IMG_RX;  // Stay in S_IMG_RX until all bytes are received
        end
      end

      S_WAIT_INFERENCE: if (result_ready_sync2) next_state = S_CLEAR;

      S_CLEAR: if (buffer_empty_sync2) next_state = S_IDLE;

      default: next_state = S_IDLE;
    endcase
  end

  //===================================================
  // Capture previous valid sync for edge detect
  //===================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) prev_byte_valid_sync2_ff <= 1'b0;
    else prev_byte_valid_sync2_ff <= byte_valid_sync2;
  end

  //===================================================
  // FSM Output Control
  //===================================================
  always_comb begin
    rx_enable           = 0;
    clear_buffer        = 0;
    buffer_write_enable = 0;
    bnn_start           = 0;
    byte_taken          = 0;

    unique case (ctrl_state)
      S_RX_CMD: begin
        rx_enable = 1;
        // only on the synced-byte rising edge
        if (byte_valid_sync2 && !prev_byte_valid_sync2_ff) byte_taken = 1;
      end

      S_IMG_RX: begin
        rx_enable = 1;
        // only when buffer not full
        if (!buffer_full && byte_valid_sync2 && !prev_byte_valid_sync2_ff) begin
          buffer_write_enable = 1;
          byte_taken          = 1;
        end
      end

      S_WAIT_INFERENCE: bnn_start = 1;
      S_CLEAR:          clear_buffer = 1;

      default: ;
    endcase
  end

  //===================================================
  // Synchronizers
  //===================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cs_sync1 <= 1'b1;
      cs_sync2 <= 1'b1;
      byte_valid_sync1 <= 1'b0;
      byte_valid_sync2 <= 1'b0;
      buffer_empty_sync1 <= 1'b0;
      buffer_empty_sync2 <= 1'b0;
      result_ready_sync1 <= 1'b0;
      result_ready_sync2 <= 1'b0;
    end else begin
      cs_sync1 <= spi_cs_n;
      cs_sync2 <= cs_sync1;
      byte_valid_sync1 <= spi_byte_valid;
      byte_valid_sync2 <= byte_valid_sync1;
      buffer_empty_sync1 <= buffer_empty;
      buffer_empty_sync2 <= buffer_empty_sync1;
      result_ready_sync1 <= result_ready;
      result_ready_sync2 <= result_ready_sync1;
    end
  end

  //===================================================
  // Optional Debug
  //===================================================
`ifndef SYNTHESIS
  logic prev_result_ready_sync2;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      prev_result_ready_sync2 <= 0;
    end else begin
      prev_result_ready_sync2 <= result_ready_sync2;
    end
  end

  always_ff @(posedge clk) begin
    // Debug timeout counter
    // if (rx_timeout_cnt > 0)
    //   $display("[FSM]    (%0d): Timeout Counter: rx_timeout_cnt = %0d", cycle_cnt, rx_timeout_cnt);

    // Debug FSM state transitions
    if (ctrl_state != next_state)
      $display(
          "[FSM]    (%0d): State Transition: %s -> %s",
          cycle_cnt,
          ctrl_state.name(),
          next_state.name()
      );

    // Debug when SPI command is received
    // Removed debug for S_WAIT_BYTE:
    // if (ctrl_state == S_WAIT_BYTE) begin
    //   $display("[FSM]    (%0d): SPI Command Received: spi_rx_data = 0x%02X", cycle_cnt,
    //            spi_rx_data);
    //   $display("[FSM]    (%0d): status_request_reg = %b, img_tx_request_reg = %b", cycle_cnt,
    //            status_request_reg, img_tx_request_reg);
    // end

    if (ctrl_state == S_RX_CMD && byte_valid_sync2)
      $display("[FSM] Sampling command: 0x%02X in S_RX_CMD", spi_rx_data);

    // if (ctrl_state == S_CMD_DISPATCH)
    //   $display(
    //       "[FSM] img_tx_request_reg=%b, status_request_reg=%b",
    //       img_tx_request_reg,
    //       status_request_reg
    //   );


    // Debug byte counter during image reception
    if (ctrl_state == S_IMG_RX && byte_valid_sync2)
      $display("[FSM]    (%0d): Byte Received: bytes_received = %0d", cycle_cnt, bytes_received);

    // Debug when status_ready is asserted
    if (ctrl_state == S_STATUS_READY)
      $display("[FSM]   (%0d): Status Ready Asserted: cycle_cnt = %0d", cycle_cnt, cycle_cnt);

    // Debug buffer clearing
    if (ctrl_state == S_CLEAR)
      $display(
          "[FSM]    (%0d): Clearing Buffer: buffer_empty_sync2 = %b", cycle_cnt, buffer_empty_sync2
      );

    // Debug waiting for inference
    if (ctrl_state == S_WAIT_INFERENCE && result_ready_sync2 != prev_result_ready_sync2) begin
      $display("[FSM]    (%0d): Waiting for Inference: result_ready_sync2 = %b", cycle_cnt,
               result_ready_sync2);
    end
  end
`endif

endmodule
