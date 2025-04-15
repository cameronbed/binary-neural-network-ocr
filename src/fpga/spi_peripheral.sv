`timescale 1ns / 1ps
module spi_peripheral #(
    parameter logic CPOL = 0,
    parameter logic CPHA = 0,
    parameter int SPI_FRAME_BITS = 8  // Change to int for proper width
) (
    input logic clk,   // System clock
    input logic rst_n, // Active-low reset

    // SPI
    input  logic SCLK,
    input  logic COPI,
    input  logic CS,
    output logic CIPO,

    // Data
    input  logic [7:0] tx_byte,  // Byte to be transmitted
    output logic [7:0] rx_byte,  // Captured received byte

    // Control signals input
    input logic rx_enable,
    input logic tx_enable,
    input logic byte_ready,

    // Control signals output
    output logic byte_valid,
    output logic spi_error
);
  typedef enum logic [1:0] {
    SPI_IDLE,
    SPI_RX,
    SPI_TX
  } spi_state_t;
  spi_state_t spi_state, spi_next_state, spi_prev_state;

  logic [7:0] rx_shift_reg;
  logic [7:0] tx_shift_reg;  // Separate declaration for clarity
  logic [31:0] rx_bit_count, tx_bit_count;  // Extend to 32 bits for proper width matching

  logic sclk_rising, sclk_falling;  // For detecting falling edge of SCLK

  logic sclk_sync_0, sclk_sync_1, sclk_sync_2;
  logic cs_sync_0, cs_sync_1, cs_sync_2;
  logic copi_sync_0, copi_sync_1, copi_sync_2;

  logic shift_edge, sample_edge;

  logic cipo_drive;
  logic cipo_internal;  // Internal signal for CIPO

  assign CIPO = cipo_internal;  // Directly assign the internal signal to CIPOf

  logic incomplete_transfer;

  // ----------------------- FSM State Control -----------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      spi_state <= SPI_IDLE;
      incomplete_transfer <= 1'b0;  // Initialize here
    end else begin
      spi_state <= spi_next_state;

      case (spi_state)
        SPI_IDLE: begin
          // Reset signals in IDLE state
          incomplete_transfer <= 1'b0;  // Reset incomplete_transfer in IDLE state
          cipo_drive          <= 1'b0;  // Reset CIPO drive signal
        end

        SPI_RX: begin
          // Handle RX state logic
          if (byte_valid) begin
            rx_byte <= rx_shift_reg;  // Capture received byte
            incomplete_transfer <= 1'b0;  // Reset incomplete_transfer on byte valid
          end else begin
            incomplete_transfer <= 1'b1;  // Set incomplete_transfer if not valid
          end
        end

        SPI_TX: begin
          // Handle TX state logic
          if (byte_ready) begin
            cipo_drive <= tx_shift_reg[7];  // Drive CIPO with the most significant bit of tx_shift_reg
            incomplete_transfer <= 1'b0;  // Reset incomplete_transfer on byte ready
          end else begin
            incomplete_transfer <= 1'b1;  // Set incomplete_transfer if not ready
          end
        end

        default: spi_error <= 1'b1;  // Set error flag for unexpected states
      endcase
    end
  end

  // ------------------------ Shift Register Logic ------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_shift_reg <= 8'd0;
      tx_shift_reg <= 8'd0;  // Use non-blocking assignment consistently
      tx_bit_count <= 32'd0;
      rx_bit_count <= 32'd0;
      cipo_drive <= 1'b0;
      byte_valid <= 1'b0;
      rx_byte <= 8'd0;
    end

    // Preload CIPO on CS falling edge if CPHA = 1
    if (!cs_sync_2 && cs_sync_1 && tx_enable && CPHA) begin
      tx_shift_reg <= tx_byte;  // Use non-blocking assignment
      cipo_drive   <= tx_byte[7];
    end

    case (spi_state)
      SPI_IDLE: begin
        rx_shift_reg <= 8'd0;
        tx_shift_reg <= 8'd0;  // Use non-blocking assignment
        tx_bit_count <= 32'd0;
        rx_bit_count <= 32'd0;
        cipo_drive   <= 1'b0;

        if (byte_ready) begin
          tx_shift_reg <= tx_byte;  // Use non-blocking assignment
          if (!CPHA) begin
            cipo_drive <= tx_byte[7];
          end
        end
      end

      // ---------------- RX ----------------
      SPI_RX: begin
        if (sample_edge && !cs_sync_2 && rx_enable && rx_bit_count < SPI_FRAME_BITS) begin
          rx_shift_reg <= {rx_shift_reg[6:0], copi_sync_2};
          rx_bit_count <= rx_bit_count + 1;

          // On final bit, capture full byte
          if (rx_bit_count == SPI_FRAME_BITS - 1) begin
            rx_byte    <= {rx_shift_reg[6:0], copi_sync_2};
            byte_valid <= 1'b1;  // Ensure this is asserted
          end else begin
            byte_valid <= 1'b0;  // Deassert otherwise
          end
        end
      end

      // ---------------- TX ----------------
      SPI_TX: begin
        if (shift_edge && !cs_sync_2 && tx_enable && tx_bit_count < SPI_FRAME_BITS) begin
          cipo_drive   <= tx_shift_reg[6];
          tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};  // Ensure proper width
          tx_bit_count <= tx_bit_count + 1;
        end
      end

      default: spi_error <= 1'b1;
    endcase
  end

  // ------------------------ FSM Next-State Logic ------------------------
  always_comb begin
    spi_next_state = spi_state;

    case (spi_state)
      // ---------- IDLE ----------
      SPI_IDLE: begin
        if (!cs_sync_2) begin
          if (rx_enable) spi_next_state = SPI_RX;
          else if (tx_enable) spi_next_state = SPI_TX;
        end
      end

      // ---------- RX ----------
      SPI_RX: begin
        if (cs_sync_2 || rx_bit_count == SPI_FRAME_BITS) begin
          spi_next_state = SPI_IDLE;
        end
      end

      // ---------- TX ----------
      SPI_TX: begin
        if (cs_sync_2 || tx_bit_count == SPI_FRAME_BITS) begin
          spi_next_state = SPI_IDLE;
        end
      end

      default: ;  // Add default case to handle incomplete coverage
    endcase
  end


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

endmodule
