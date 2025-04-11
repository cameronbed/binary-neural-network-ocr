`timescale 1ns / 1ps
module spi_peripheral (
    input logic clk,  // System clock
    input logic rst,  // Active-low reset
    input logic SCLK,  // SPI clock
    input logic COPI,  // Controller-out-Peripheral-In
    input logic CS,  // Chip-select
    output logic CIPO,  // Controller-in-Peripheral-Out
    input logic [7:0] tx_byte,  // Byte to be transmitted
    output logic [7:0] rx_byte,  // Captured received byte
    output logic byte_valid,
    // Debug signals
    output logic [1:0] debug_state,  // Debug: current state
    output logic [3:0] debug_bit_count,  // Debug: bit count
    output logic [7:0] debug_rx_byte  // Debug: received byte
);
  typedef enum logic [1:0] {
    IDLE,
    TRANSFER,
    BYTE_READY
  } spi_state_t;
  spi_state_t state, next_state;

  // Data Registers
  logic [7:0] rx_shift_reg;  // Shift register to hold the incoming data
  logic [7:0] tx_shift_reg;  // Shift register to hold the outgoing data
  logic [3:0] bit_count;  // Change bit_count to 4 bits to match debug_bit_count

  // SCLK signals
  logic sclk_sync_0, sclk_sync_1;
  logic sclk_prev;
  logic sclk_rising, sclk_falling;

  // always_ff block to synchronize SCLK with the system clock
  always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
      sclk_sync_0 <= 1'b0;
      sclk_sync_1 <= 1'b0;
      sclk_prev   <= 1'b0;
    end else begin
      sclk_sync_0 <= SCLK;  // waiting two clock cycles to synchronize SCLK
      sclk_sync_1 <= sclk_sync_0;
      sclk_prev   <= sclk_sync_1;
    end
  end
  assign sclk_rising  = (sclk_sync_1 && !sclk_prev);
  assign sclk_falling = (!sclk_sync_1 && sclk_prev);

  // always_ff block to handle the SPI communication and FSM
  always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
      state           <= IDLE;
      rx_shift_reg    <= 8'd0;
      tx_shift_reg    <= 8'd0;
      bit_count       <= 0;
      CIPO            <= 1'b0;
      byte_valid      <= 1'b0;
      rx_byte         <= 8'd0;
      // Debug signals
      debug_state     <= 2'b00;  // Reset debug state
      debug_bit_count <= 4'd0;  // Reset debug bit count
      debug_rx_byte   <= 8'd0;  // Reset debug received byte
    end else begin
      // First, update the debug signals
      debug_state <= state;
      debug_bit_count <= bit_count;
      debug_rx_byte <= rx_byte;

      // Default - clear byte_valid
      byte_valid <= 1'b0;

      case (state)
        IDLE: begin
          bit_count <= 4'd0;
          rx_shift_reg <= 8'd0;

          if (!CS) begin
            state <= TRANSFER;
            tx_shift_reg <= tx_byte;  // Load transmit data
            $display("SPI: Starting new transfer, CS active");
          end
        end

        TRANSFER: begin
          if (sclk_rising) begin
            // Sample data on rising edge
            rx_shift_reg <= {rx_shift_reg[6:0], COPI};
            bit_count <= bit_count + 4'd1;
            $display("SPI: Bit %d received: %b, shift_reg=%h", bit_count, COPI, {rx_shift_reg[6:0],
                                                                                 COPI});

            // When we've received 8 bits, go to BYTE_READY state
            if (bit_count == 4'd7) begin
              // Note: The 8th bit is captured on this rising edge
              state <= BYTE_READY;
              // Capture the full byte (including the 8th bit we just sampled)
              rx_byte <= {rx_shift_reg[6:0], COPI};
              byte_valid <= 1'b1;  // Signal byte is valid
              $display("SPI: BYTE READY - rx_byte=%h", {rx_shift_reg[6:0], COPI});
            end
          end

          if (sclk_falling) begin
            // Transmit data on falling edge
            CIPO <= tx_shift_reg[7];
            tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
          end

          // If CS deasserted, go back to IDLE
          if (CS) begin
            state <= IDLE;
            $display("SPI: Transfer aborted, CS inactive");
          end
        end

        BYTE_READY: begin
          // Reset bit counter for next byte
          bit_count <= 4'd0;

          // Start a new transfer or go back to IDLE
          if (!CS) begin
            state <= TRANSFER;
            tx_shift_reg <= tx_byte;  // Load new transmit data
            $display("SPI: Starting next byte transfer");
          end else begin
            state <= IDLE;
            $display("SPI: Transfer complete, going to IDLE");
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

  // No longer need the separate comb logic since we handle transitions directly
  assign next_state = state;  // For compatibility

endmodule
