`timescale 1ns / 1ps
module spi_peripheral (
    input logic clk,  // System clock
    input logic rst,  // Active-low reset
    input logic SCLK,  // SPI clock
    input logic COPI,  // Controller-out-Peripheral-In
    input logic CS,  // Chip-select
    output logic CIPO,  // Controller-in-Peripheral-Out
    output logic [7:0] rx_byte,  // Captured received byte
    output logic byte_valid
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
  int bit_count;

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
      state        <= IDLE;
      rx_shift_reg <= 8'd0;
      tx_shift_reg <= 8'd0;
      bit_count    <= 0;
      CIPO         <= 1'b0;
      byte_valid   <= 1'b0;
      rx_byte      <= 8'd0;
    end else begin
      state <= next_state;
      byte_valid <= 1'b0;  // Reset byte_valid at the start of each cycle
      case (state)
        IDLE: begin
          bit_count    <= 0;
          rx_shift_reg <= 8'd0;
          CIPO         <= 1'b0;
        end

        TRANSFER: begin
          if (!CS) begin
            if (sclk_rising) begin
              // Shift data into the rx_shift_reg on sclk rising edge
              rx_shift_reg <= {rx_shift_reg[6:0], COPI};
              bit_count <= bit_count + 1;
            end
            if (sclk_falling) begin
              // Shift out the next bit on sclk falling edge
              CIPO <= tx_shift_reg[7];
              tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};  // Shift left and fill with 0.
            end
          end
        end

        BYTE_READY: begin
          rx_byte <= rx_shift_reg;  // Capture the received byte
          byte_valid <= 1'b1;  // Indicate that a byte is ready
          bit_count <= 0;  // Reset the bit counter for the next byte.
          rx_shift_reg <= 8'd0;  // Reset the shift register

          if (!CS) begin
            tx_shift_reg <= 8'hA5;  // Load the shift register with a default value (e.g., 0xA5)
          end else begin
            CIPO <= 1'b0;  // Deactivate CIPO when CS is high
          end
        end
      endcase
    end
  end

  //FSM Logic
  always_comb begin
    case (state)
      IDLE: begin
        if (!CS) begin
          next_state = TRANSFER;
        end else begin
          next_state = IDLE;
        end
      end

      // Check for a finished state and check for CS high to reset the state
      TRANSFER: begin
        if (CS) begin
          next_state = IDLE;
        end else if (bit_count == 8) begin
          next_state = BYTE_READY;
        end else begin
          next_state = TRANSFER;
        end
      end

      BYTE_READY: begin
        if (CS) begin
          next_state = IDLE;  // Go back to IDLE when CS is high
        end else begin
          next_state = TRANSFER;  // Continue transferring data if CS is low
        end
      end

      default: next_state = IDLE;  // Default case to avoid latches
    endcase
  end


endmodule
