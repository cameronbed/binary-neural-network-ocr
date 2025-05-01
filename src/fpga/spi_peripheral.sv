`timescale 1ns / 1ps

module spi_peripheral (
    input logic rst_n,
    input logic clk,

    // SPI pins
    input logic SCLK,
    input logic COPI,
    input logic spi_cs_n,

    // Data interface
    output logic [7:0] spi_rx_data,

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

`ifndef SYNTHESIS
  logic [31:0] cycle_cnt;
  spi_state_t prev_spi_state;
  logic prev_cs_sync_2, prev_rx_mode;
`endif

  //===================================================
  // Synchronizers
  //===================================================
  logic copi_q1, copi_q2;
  logic sclk_last;

  logic spi_cs_n_meta, spi_cs_n_sync;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sclk_last <= 1'b0;

      copi_q1 <= 1'b0;
      copi_q2 <= 1'b0;

      spi_cs_n_meta <= 1'b1;
      spi_cs_n_sync <= 1'b1;
    end else begin
      sclk_last <= SCLK;

      copi_q1 <= COPI;
      copi_q2 <= copi_q1;

      spi_cs_n_meta <= spi_cs_n;
      spi_cs_n_sync <= spi_cs_n_meta;
    end
  end

  //===================================================
  // Edge Detection for SCLK
  //===================================================
  wire sclk_rising = (SCLK == 1'b1 && sclk_last == 1'b0);
  //wire sclk_falling = (SCLK == 1'b0 && sclk_last == 1'b1);

  //=========================================
  // State Transition
  //=========================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) spi_state <= SPI_IDLE;
    else spi_state <= spi_next_state;
  end

  logic [3:0] bit_cnt;

  always_comb begin
    spi_next_state = spi_state;  // Default stay

    case (spi_state)
      SPI_IDLE: begin
        if (!spi_cs_n_sync && rx_enable) spi_next_state = SPI_RX;
      end

      SPI_RX: begin
        if (bit_cnt == 4'd7 && sclk_rising)  // Full 8 bits received
          spi_next_state = SPI_BYTE_READY;
      end

      SPI_BYTE_READY: begin
        if (byte_taken) spi_next_state = SPI_IDLE;
      end

      default: spi_next_state = SPI_IDLE;
    endcase
  end

  //-----------------------------------------
  // SPI Reception Logic
  //-----------------------------------------
  logic [7:0] shift_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      bit_cnt   <= 4'd0;
      shift_reg <= 8'd0;
    end else if (!spi_cs_n_sync && rx_enable) begin
      if (sclk_rising) begin
        shift_reg <= {shift_reg[6:0], copi_q1};  // shift in data
        bit_cnt   <= bit_cnt + 1;
      end
    end else begin
      bit_cnt   <= 4'd0;
      shift_reg <= 8'd0;
    end
  end

  //=========================================
  // Output Logic
  //=========================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      byte_valid <= 1'b0;
    end else begin
      case (spi_state)
        SPI_IDLE:       byte_valid <= 1'b0;
        SPI_RX:         byte_valid <= 1'b0;
        SPI_BYTE_READY: byte_valid <= 1'b1;
        default:        byte_valid <= 1'b0;
      endcase
    end
  end

  assign spi_rx_data = shift_reg;

endmodule
