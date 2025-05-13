`timescale 1ns / 1ps

module spi_peripheral (
    input logic rst_n,
    input logic clk,

    // SPI pins (asynchronous domain)
    input logic SCLK,
    input logic COPI,
    input logic spi_cs_n,

    // Data interface
    output logic [7:0] spi_rx_data,
    output logic rx_data_is_zero,

    // Control Signals
    input  logic rx_enable,
    output logic byte_valid,
    input  logic byte_taken
);
  // -------------------- Local Parameters
  localparam logic CPOL = 0;
  localparam logic CPHA = 0;
  localparam SPI_FRAME_BITS = 8;
  localparam int SPI_TIMEOUT_LIMIT = 32'd10000;

  // -------- FSM States
  typedef enum logic [1:0] {
    SPI_IDLE,
    SPI_RX,
    SPI_BYTE_READY
  } spi_state_t;

  spi_state_t spi_state, spi_next_state;

  // DEBUG
`ifndef SYNTHESIS
  logic [31:0] cycle_cnt;
  spi_state_t prev_spi_state;
  logic prev_cs_sync_2, prev_rx_mode;
`endif

  //===================================================
  // Synchronizers
  //===================================================
  logic sclk_sync_1, sclk_sync_2, sclk_sync_3;
  logic copi_sync_1, copi_sync_2, copi_sync_3;
  logic cs_sync_1, cs_sync_2, cs_sync_3;

  logic sclk_filt, sclk_filt_prev;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sclk_sync_1 <= 0;
      sclk_sync_2 <= 0;
      sclk_sync_3 <= 0;

      copi_sync_1 <= 0;
      copi_sync_2 <= 0;
      copi_sync_3 <= 0;

      cs_sync_1   <= 1;
      cs_sync_2   <= 1;
      cs_sync_3   <= 1;
    end else begin
      sclk_sync_1 <= SCLK;
      sclk_sync_2 <= sclk_sync_1;
      sclk_sync_3 <= sclk_sync_2;

      copi_sync_1 <= COPI;
      copi_sync_2 <= copi_sync_1;
      copi_sync_3 <= copi_sync_2;

      cs_sync_1   <= spi_cs_n;
      cs_sync_2   <= cs_sync_1;
      cs_sync_3   <= cs_sync_2;
    end
  end

  // ====== SCLK Rising Edge Detection ======
  wire sclk_rising = sclk_sync_2 && !sclk_sync_3;

  // ====== FSM State Update ======
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) spi_state <= SPI_IDLE;
    else spi_state <= spi_next_state;
  end

  logic [3:0] bit_cnt;

  always_comb begin
    spi_next_state = spi_state;

    case (spi_state)
      SPI_IDLE: begin
        if (!cs_sync_3 && rx_enable) spi_next_state = SPI_RX;
      end

      SPI_RX: begin
        if (cs_sync_3) begin
          // Transition to SPI_IDLE if CS is de-asserted mid-frame
          spi_next_state = SPI_IDLE;
        end else if (bit_cnt == 4'd7 && sclk_rising) begin
          spi_next_state = SPI_BYTE_READY;
        end
      end

      SPI_BYTE_READY: begin
        if (cs_sync_2) spi_next_state = SPI_IDLE;
        else if (byte_taken) spi_next_state = SPI_IDLE;
      end

      default: spi_next_state = SPI_IDLE;
    endcase
  end

  //-----------------------------------------
  // Shift Register and Bit Counter
  //-----------------------------------------
  logic [7:0] shift_reg;
  logic [7:0] shift_reg_stable;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      bit_cnt   <= 0;
      shift_reg <= 0;
    end else begin
      case (spi_state)
        SPI_IDLE: begin
          if (!cs_sync_3 && rx_enable) begin
            bit_cnt   <= 0;
            shift_reg <= 0;
          end
        end

        SPI_RX: begin
          if (cs_sync_3) begin
            bit_cnt   <= 0;
            shift_reg <= 0;
          end else if (sclk_rising) begin
            shift_reg <= {shift_reg[6:0], copi_sync_3};
            bit_cnt   <= bit_cnt + 1;
          end
        end

        SPI_BYTE_READY: begin
          if (byte_taken) begin
            bit_cnt   <= 0;
            shift_reg <= 0;
          end
        end

        default: ;
      endcase
    end
  end

  // ====== Output Latching ======
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) shift_reg_stable <= 0;
    else if (spi_state == SPI_BYTE_READY) shift_reg_stable <= shift_reg;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) byte_valid <= 0;
    else byte_valid <= (spi_state == SPI_BYTE_READY);
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) rx_data_is_zero <= 0;
    else if (spi_state == SPI_BYTE_READY) rx_data_is_zero <= (shift_reg_stable == 8'd0);
  end

  assign spi_rx_data = shift_reg_stable;

endmodule

