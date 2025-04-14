`timescale 1ns / 1ps
module spi_peripheral (
    input logic clk,   // System clock
    input logic rst_n, // Active-low reset

    // SPI
    input  logic SCLK,  // SPI clock
    input  logic COPI,  // Controller-out-Peripheral-In
    input  logic CS,    // Chip-select
    output logic CIPO,  // Controller-in-Peripheral-Out

    // Data
    input  logic [7:0] tx_byte,  // Byte to be transmitted
    output logic [7:0] rx_byte,  // Captured received byte

    // Control signals input
    input logic byte_ready,
    input logic rx_enable,
    input logic tx_enable,

    // Control signals output
    output logic byte_valid,  // Output signal
    output logic spi_error,   // Error indication

    // ----------- DEBUG ----------------
    input logic debug_enable,  // Debug enable signal
    output logic [1:0] debug_state,  // Debug: current state
    output logic [3:0] debug_bit_count,  // Debug: bit count
    output logic [7:0] debug_rx_byte  // Debug: received byte
);
  // Add parameters for SPI mode (CPOL/CPHA) and debug flag
  parameter logic CPOL = 0;
  parameter logic CPHA = 0;

  typedef enum logic [1:0] {
    SPI_IDLE,
    SPI_TRANSFER,
    SPI_BYTE_READY
  } spi_state_t;

  spi_state_t state, next_state;
  spi_state_t prev_state;  // To track the previous state for debugging

  logic [7:0] rx_shift_reg, tx_shift_reg;
  logic [3:0] bit_count;

  logic sclk_rising;
  logic sclk_falling;  // For detecting falling edge of SCLK

  logic sclk_sync_0, sclk_sync_1, sclk_sync_2;
  logic cs_sync_0, cs_sync_1, cs_sync_2;
  logic copi_sync_0, copi_sync_1, copi_sync_2;

  logic shift_edge, sample_edge;

  logic cipo_drive;
  logic cipo_internal;  // Internal signal for CIPO

  assign CIPO = cipo_internal;  // Directly assign the internal signal to CIPO

  logic [7:0] timeout_counter;
  localparam TIMEOUT_LIMIT = 8'd200;

  logic incomplete_transfer;

  // ------------------------ Synchronize SCLK -----------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sclk_sync_0 <= CPOL;
      sclk_sync_1 <= CPOL;
      sclk_sync_2 <= CPOL;
      cs_sync_0 <= 1'b1;
      cs_sync_1 <= 1'b1;
      cs_sync_2 <= 1'b1;
      copi_sync_0 <= 1'b0;
      copi_sync_1 <= 1'b0;
      copi_sync_2 <= 1'b0;
      // Ensure COPI is reset
      cipo_internal <= 1'b0;  // Reset internal CIPO signal
    end else begin
      sclk_sync_0 <= SCLK;
      sclk_sync_1 <= sclk_sync_0;
      sclk_sync_2 <= sclk_sync_1;
      cs_sync_0   <= CS;
      cs_sync_1   <= cs_sync_0;
      cs_sync_2   <= cs_sync_1;
      copi_sync_0 <= COPI;
      copi_sync_1 <= copi_sync_0;
      copi_sync_2 <= copi_sync_1;

      // Drive CIPO based on chip select and cipo_drive
      if (!cs_sync_2) begin
        cipo_internal <= cipo_drive;
      end else begin
        cipo_internal <= 1'b0;  // Default to 0 when CS is inactive
      end
    end
  end

  assign sclk_rising = (CPOL == 0) ? (sclk_sync_1 && !sclk_sync_2) : (!sclk_sync_1 && sclk_sync_2);
  assign sclk_falling = (CPOL == 0) ? (!sclk_sync_1 && sclk_sync_2) : (sclk_sync_1 && !sclk_sync_2);

  // ------------------------ Phase Control Logic ------------------------
  assign shift_edge = (CPHA == 0) ? sclk_rising : sclk_falling;
  assign sample_edge = (CPHA == 0) ? sclk_falling : sclk_rising;

  // ----------------------- FSM State Control -----------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= SPI_IDLE;
      incomplete_transfer <= 1'b0;  // Initialize here
    end else begin
      state <= next_state;

      // Handle incomplete_transfer in the same block
      if (state == SPI_TRANSFER && cs_sync_2 && bit_count < 8) begin
        incomplete_transfer <= 1'b1;
      end else if (state == SPI_IDLE) begin
        incomplete_transfer <= 1'b0;
      end
    end
  end

  // ------------------------ Timeout/Watchdog Logic ------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      timeout_counter <= 0;
      spi_error <= 1'b0;
    end else if (state == SPI_TRANSFER) begin
      if (timeout_counter < TIMEOUT_LIMIT) timeout_counter <= timeout_counter + 1;
      else begin
        timeout_counter <= 0;
        spi_error <= 1'b1;
      end
    end else begin
      timeout_counter <= 0;
      spi_error <= 1'b0;  // Reset spi_error explicitly when not in TRANSFER
    end
  end

  // ------------------------ Shift Register Logic ------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_shift_reg <= 8'd0;
      tx_shift_reg <= 8'd0;
      bit_count    <= 4'd0;
      cipo_drive   <= 1'b0;
      byte_valid   <= 1'b0; // Ensure byte_valid is reset
    end else begin
      if (state == SPI_IDLE) begin
        bit_count  <= 0;
        byte_valid <= 1'b0;  // Reset byte_valid in IDLE state
        if (byte_ready) tx_shift_reg <= tx_byte;
      end

      // Preload CIPO on CS falling edge if CPHA=1
      if (!cs_sync_2 && cs_sync_1 && tx_enable && CPHA) begin
        cipo_drive <= tx_byte[7];
      end

      // Separate edges for RX (sample_edge) and TX (shift_edge)
      if (sample_edge && state == SPI_TRANSFER && !cs_sync_2 && bit_count < 8 && rx_enable) begin
        rx_shift_reg <= {rx_shift_reg[6:0], copi_sync_2};
        $display("[DEBUG] Received bit: %b, Updated rx_shift_reg: %b, Bit count: %0d", copi_sync_2,
                 rx_shift_reg, bit_count);
      end
      if (shift_edge && state == SPI_TRANSFER && !cs_sync_2 && bit_count < 8 && tx_enable) begin
        cipo_drive   <= tx_shift_reg[7];
        tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
        bit_count    <= bit_count + 1;
      end

      // Complete byte transfer
      if (bit_count == 8 && state == SPI_TRANSFER) begin
        byte_valid <= 1'b1;
        $display("[TRACE] Byte transfer complete. rx_shift_reg=%b, time=%0t", rx_shift_reg, $time);
      end else if (cs_sync_2) begin
        byte_valid <= 1'b0;  // Hold byte_valid until CS goes high
      end
    end
  end

  // ------------------------ Byte Completion ------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_byte <= 8'd0;
    end else if (state == SPI_BYTE_READY && rx_enable) begin
      rx_byte <= rx_shift_reg;  // Consolidate rx_byte write here
    end
  end

  // ------------------------- DEBUG Signal Outputs -----------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      debug_state     <= SPI_IDLE;
      debug_bit_count <= 4'd0;
      debug_rx_byte   <= 8'd0;
    end else begin
      debug_state     <= state;
      debug_bit_count <= bit_count;
      debug_rx_byte   <= rx_shift_reg;
    end
  end

  // ------------------------ FSM Next-State Logic ------------------------
  always_comb begin
    next_state = state;
    case (state)
      SPI_IDLE: begin
        if (!cs_sync_2 && byte_ready) next_state = SPI_TRANSFER;
      end
      SPI_TRANSFER: begin
        if (bit_count == 4'd7 && shift_edge) next_state = SPI_BYTE_READY;  // Fix off-by-one
        else if (cs_sync_2) next_state = SPI_IDLE;
      end
      SPI_BYTE_READY: begin
        if (!cs_sync_2) next_state = SPI_TRANSFER;
        else next_state = SPI_IDLE;
      end
      default: next_state = SPI_IDLE;  // Add default case
    endcase
  end

endmodule
