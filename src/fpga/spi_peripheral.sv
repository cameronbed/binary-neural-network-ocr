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

  // DEBUG
`ifndef SYNTHESIS
  logic [31:0] cycle_cnt;
  spi_state_t prev_spi_state;
  logic prev_cs_sync_2, prev_rx_mode;
`endif

  //===================================================
  // Synchronizers
  //===================================================
  logic sclk_sample, sclk_debounced;
  logic [1:0] sclk_hist;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sclk_hist   <= 2'b00;
      sclk_sample <= 1'b0;
    end else begin
      sclk_hist   <= {sclk_hist[0], SCLK};
      sclk_sample <= &sclk_hist;  // Only goes high if both bits are high
    end
  end

  logic copi_q1, copi_q2;
  logic sclk_q1, sclk_q2, sclk_q3;
  logic cs_q1, cs_q2;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      copi_q1 <= 1'b0;
      copi_q2 <= 1'b0;

      sclk_q1 <= sclk_sample;
      sclk_q2 <= 1'b0;
      sclk_q3 <= 1'b0;

      cs_q1   <= 1'b1;
      cs_q2   <= 1'b1;
    end else begin
      copi_q1 <= COPI;
      copi_q2 <= copi_q1;

      sclk_q1 <= sclk_sample;
      sclk_q2 <= sclk_q1;
      sclk_q3 <= sclk_q2;

      cs_q1   <= spi_cs_n;
      cs_q2   <= cs_q1;
    end
  end

  logic sclk_sync1, sclk_sync2;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sclk_sync1 <= 0;
      sclk_sync2 <= 0;
    end else begin
      sclk_sync1 <= SCLK;
      sclk_sync2 <= sclk_sync1;
    end
  end
  //===================================================
  // Edge Detection for SCLK
  //===================================================
  wire sclk_rising = sclk_sync1 && !sclk_sync2;


  //=========================================
  // State Transition
  //=========================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) spi_state <= SPI_IDLE;
    else spi_state <= spi_next_state;
  end

  logic [3:0] bit_cnt;

  always_comb begin
    spi_next_state = spi_state;

    case (spi_state)
      SPI_IDLE: begin
        if (!cs_q2 && rx_enable) spi_next_state = SPI_RX;
      end

      SPI_RX: begin
        if (cs_q2) begin
          // Transition to SPI_IDLE if CS is de-asserted mid-frame
          spi_next_state = SPI_IDLE;
        end else if (bit_cnt == 4'd7 && sclk_rising) begin
          spi_next_state = SPI_BYTE_READY;
        end
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
    end else begin
      case (spi_state)
        SPI_IDLE: begin
          if (!cs_q2 && rx_enable) begin
            bit_cnt   <= 4'd0;
            shift_reg <= 8'd0;
          end
        end

        SPI_RX: begin
          if (cs_q2) begin
            bit_cnt   <= 4'd0;
            shift_reg <= 8'd0;
          end else if (sclk_rising) begin
            shift_reg <= {shift_reg[6:0], copi_q2};
            bit_cnt   <= bit_cnt + 1;
          end
        end

        SPI_BYTE_READY: begin
          if (byte_taken) begin
            bit_cnt   <= 4'd0;
            shift_reg <= 8'd0;
          end
        end

        default: ;  // hold in SPI_IDLE
      endcase
    end
  end

  logic [7:0] shift_reg_stable;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      shift_reg_stable <= 8'd0;
    end else if (spi_state == SPI_BYTE_READY) begin
      shift_reg_stable <= shift_reg;  // Register shift_reg when transitioning to SPI_BYTE_READY
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) byte_valid <= 1'b0;
    else byte_valid <= (spi_state == SPI_BYTE_READY);
  end

  //=========================================
  // Output Logic
  //=========================================
  assign spi_rx_data = shift_reg_stable;

endmodule
