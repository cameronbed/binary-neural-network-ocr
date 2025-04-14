`timescale 1ns / 1ps
module spi_peripheral (
    input logic clk,  // System clock
    input logic rst_n,  // Active-low reset
    input logic SCLK,  // SPI clock
    input logic COPI,  // Controller-out-Peripheral-In
    input logic CS,  // Chip-select
    output logic CIPO,  // Controller-in-Peripheral-Out
    input logic [7:0] tx_byte,  // Byte to be transmitted
    output logic [7:0] rx_byte,  // Captured received byte
    output logic byte_valid,
    output logic spi_error,  // Error indication
    // Debug signals
    output logic [1:0] debug_state,  // Debug: current state
    output logic [3:0] debug_bit_count,  // Debug: bit count
    output logic [7:0] debug_rx_byte  // Debug: received byte
);
  // Add parameters for SPI mode (CPOL/CPHA) and debug flag
  parameter logic CPOL = 0;
  parameter logic CPHA = 0;
  parameter logic DEBUG = 0;  // Debug flag: 0 = off, 1 = on

  typedef enum logic [1:0] {
    IDLE,
    TRANSFER,
    BYTE_READY
  } spi_state_t;
  spi_state_t state, next_state;

  // Data Registers
  logic [7:0] rx_shift_reg;  // Shift register to hold the incoming data
  logic [7:0] rx_byte_next;
  logic [7:0] tx_shift_reg;  // Shift register to hold the outgoing data
  logic [3:0] bit_count;  // Change bit_count to 4 bits to match debug_bit_count

  // SCLK signals
  logic sclk_sync_0, sclk_sync_1, sclk_sync_2;
  logic sclk_prev;
  logic sclk_rising, sclk_falling;

  // Add synchronizers for CS and COPI signals
  logic cs_sync_0, cs_sync_1, cs_sync_2;
  logic copi_sync_0, copi_sync_1, copi_sync_2;

  // Add internal drive for CIPO and tri-state assignment
  logic cipo_drive;
  assign CIPO = (!cs_sync_2) ? cipo_drive : 1'bz;

  // Timeout counter for detecting stalled transfers
  logic [7:0] timeout_counter;
  localparam TIMEOUT_LIMIT = 8'd200;

  // always_ff block to synchronize SCLK with the system clock
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sclk_sync_0 <= CPOL;
      sclk_sync_1 <= CPOL;
      sclk_sync_2 <= CPOL;
      sclk_prev   <= CPOL;
    end else begin
      sclk_sync_0 <= SCLK;  // waiting three clock cycles to synchronize SCLK
      sclk_sync_1 <= sclk_sync_0;
      sclk_sync_2 <= sclk_sync_1;
      sclk_prev   <= sclk_sync_2;
    end
  end
  assign sclk_rising = (CPOL == 0) ? (sclk_sync_1 && !sclk_sync_2) : (!sclk_sync_1 && sclk_sync_2);
  assign sclk_falling = (CPOL == 0) ? (!sclk_sync_1 && sclk_sync_2) : (sclk_sync_1 && !sclk_sync_2);

  // Add new always_ff block to synchronize CS and COPI signals
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cs_sync_0   <= 1'b1;  // inactive (active-low)
      cs_sync_1   <= 1'b1;
      cs_sync_2   <= 1'b1;
      copi_sync_0 <= 1'b0;
      copi_sync_1 <= 1'b0;
      copi_sync_2 <= 1'b0;
    end else begin
      cs_sync_0   <= CS;
      cs_sync_1   <= cs_sync_0;
      cs_sync_2   <= cs_sync_1;  // filtered CS signal used below
      copi_sync_0 <= COPI;
      copi_sync_1 <= copi_sync_0;
      copi_sync_2 <= copi_sync_1;  // filtered COPI signal used below
    end
  end

  // always_ff block to handle the SPI communication and FSM
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      rx_shift_reg    <= 8'd0;
      tx_shift_reg    <= 8'd0;
      bit_count       <= 4'd0;
      cipo_drive      <= 1'b0;
      rx_byte         <= 8'd0;
      byte_valid      <= 1'b0;
      spi_error       <= 1'b0;
      timeout_counter <= 0;
      // Debug signals
      debug_state     <= 2'b00;
      debug_bit_count <= 4'd0;
      debug_rx_byte   <= 8'd0;
    end else begin
      // Update debug signals
      debug_state     <= state;
      debug_bit_count <= bit_count;
      debug_rx_byte   <= rx_byte;

      // Increment timeout in TRANSFER state; reset otherwise
      if (state == TRANSFER) timeout_counter <= timeout_counter + 8'd1;
      else timeout_counter <= 8'd0;

      // Timeout check
      if (timeout_counter >= TIMEOUT_LIMIT) begin
        spi_error <= 1'b1;
        state <= IDLE;
        timeout_counter <= 0;
        if (DEBUG) $display("[SPI_PERIPH] Timeout error, resetting FSM at time=%0t", $time);
      end

      case (state)
        IDLE: begin
          bit_count    <= 4'd0;
          rx_shift_reg <= 8'd0;
          byte_valid   <= 1'b0;
          if (!cs_sync_2) begin  // CS active low
            state        <= TRANSFER;
            tx_shift_reg <= tx_byte;
            if (DEBUG) $display("[SPI_PERIPH] Transition IDLE -> TRANSFER at time=%0t", $time);
          end
        end

        TRANSFER: begin
          byte_valid <= 1'b0;  // Ensure byte_valid remains deasserted during transfer
          if (sclk_rising) begin
            logic [7:0] new_rx;
            new_rx = {rx_shift_reg[6:0], copi_sync_2};
            rx_shift_reg <= new_rx;
            if (DEBUG)
              $display(
                  "[SPI_PERIPH] SCLK rising: CS=%b, COPI=%b, bit_count=%0d, new_rx=%h, time=%0t",
                  cs_sync_2,
                  copi_sync_2,
                  bit_count,
                  new_rx,
                  $time
              );
            if (bit_count == 4'd7) begin
              rx_byte   <= new_rx;
              // Transition to new state to hold byte_valid for one full cycle
              state     <= BYTE_READY;
              bit_count <= 4'd0;
              if (DEBUG)
                $display(
                    "[SPI_PERIPH] BYTE VALID! Completed 8 bits, rx_byte=%h at time=%0t",
                    new_rx,
                    $time
                );
            end else begin
              bit_count <= bit_count + 4'd1;
              if (DEBUG) $display("[SPI_PERIPH] Incremented bit_count to %0d", bit_count + 1);
            end
          end

          if (sclk_falling) begin
            cipo_drive   <= tx_shift_reg[7];
            tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
          end

          if (cs_sync_2) begin
            state <= IDLE;
            if (DEBUG) $display("[SPI_PERIPH] Transfer aborted, CS inactive at time=%0t", $time);
          end
        end

        BYTE_READY: begin
          // Hold byte_valid high for one full clock cycle
          byte_valid <= 1'b1;
          // Prepare for next byte transfer: reset counter
          bit_count <= 4'd0;
          // Remain in TRANSFER if CS still active, else go to IDLE
          state <= (!cs_sync_2) ? TRANSFER : IDLE;
        end

        default: begin
          state     <= IDLE;
          spi_error <= 1'b1;
          if (DEBUG)
            $display("[SPI_PERIPH] Unknown state encountered; resetting FSM at time=%0t", $time);
        end
      endcase
    end
  end

  // No longer need the separate comb logic since we handle transitions directly
  assign next_state = state;  // For compatibility

endmodule
