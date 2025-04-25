`timescale 1ns / 1ps

module spi_peripheral #(
    parameter logic CPOL = 0,
    parameter logic CPHA = 0
) (
    input logic clk,
    input logic rst_n,
    // SPI pins
    input logic SCLK,
    input logic COPI,
    input logic spi_cs_n,

    // Data interface
    output logic [7:0] spi_rx_data,

    // Control Signals
    input  logic rx_enable,
    output logic spi_byte_valid,
    input  logic byte_taken
);
  // -------------------- Local Parameters
  localparam SPI_FRAME_BITS = 8;  // Fixed to 8 bits for SPI
  localparam IMG_BYTE_COUNT = 113;  // Fixed to 1024 bytes for image buffer
  localparam int SPI_TIMEOUT_LIMIT = 32'd10000;  // timeout cycles

  // -------- FSM States
  typedef enum logic [2:0] {  // Increase state width for new state
    SPI_IDLE,
    SPI_RX,
    SPI_PROCESS,
    SPI_IMG_RX,
    SPI_DONE,
    SPI_WAIT  // new state added for handshake delay
  } spi_state_t;

  spi_state_t spi_state, spi_next_state;

  // Synchronizers
  logic sclk_sync_0, sclk_sync_1, sclk_sync_2;
  logic cs_sync_0, cs_sync_1, cs_sync_2;
  logic copi_sync_0, copi_sync_1, copi_sync_2;

  // Shifting
  logic [7:0] rx_shift_reg;
  logic [3:0] bit_cnt;

  // Control Signals
  logic shift_rx;
  logic byte_valid_int;

  logic spi_active;
  logic rx_mode;

  assign spi_active = (cs_sync_2 == 1'b0);
  assign rx_mode    = rx_enable && spi_active;

  logic [7:0] img_buffer[0:IMG_BYTE_COUNT-1];
  logic [$clog2(IMG_BYTE_COUNT)-1:0] img_byte_cnt;  // Adjust width to match IMG_BYTE_COUNT
  logic [31:0] spi_timeout_cnt;  // timeout counter

  logic [31:0] cycle_cnt;
  spi_state_t prev_spi_state;
  logic prev_cs_sync_2, prev_rx_mode;

  //===================================================
  // Input Synchronization
  //===================================================

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      {sclk_sync_0, sclk_sync_1, sclk_sync_2} <= {CPOL, CPOL, CPOL};
      {cs_sync_0, cs_sync_1, cs_sync_2}       <= 3'b111;
      {copi_sync_0, copi_sync_1, copi_sync_2} <= 3'b000;
    end else begin
      sclk_sync_0 <= SCLK;
      sclk_sync_1 <= sclk_sync_0;
      sclk_sync_2 <= sclk_sync_1;

      cs_sync_0   <= spi_cs_n;
      cs_sync_1   <= cs_sync_0;
      cs_sync_2   <= cs_sync_1;

      copi_sync_0 <= COPI;
      copi_sync_1 <= copi_sync_0;
      copi_sync_2 <= copi_sync_1;
    end
  end

  //===================================================
  // Edge Detection
  //===================================================
  wire sclk_rising = (CPOL == 0) ? (sclk_sync_1 && !sclk_sync_2) : (!sclk_sync_1 && sclk_sync_2);
  wire sclk_falling = (CPOL == 0) ? (!sclk_sync_1 && sclk_sync_2) : (sclk_sync_1 && !sclk_sync_2);
  wire shift_edge = (CPHA == 0) ? sclk_rising : sclk_falling;
  wire sample_edge = (CPHA == 0) ? sclk_falling : sclk_rising;

  //===================================================
  // FSM Register + Timeout Counter
  //===================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      spi_state       <= SPI_IDLE;
      spi_timeout_cnt <= 32'd0;
    end else begin
      spi_state <= spi_next_state;
      // count only in RX phases
      if (spi_state == SPI_RX || spi_state == SPI_IMG_RX) spi_timeout_cnt <= spi_timeout_cnt + 1;
      else spi_timeout_cnt <= 32'd0;
    end
  end

  //===================================================
  // FSM Next-State and Control Logic
  //===================================================
  always_comb begin
    spi_next_state = spi_state;
    // timeout forces idle
    if (spi_timeout_cnt >= SPI_TIMEOUT_LIMIT) spi_next_state = SPI_IDLE;

    shift_rx = 1'b0;

    case (spi_state)
      SPI_IDLE: begin
        if (rx_mode) begin
          spi_next_state = SPI_RX;
        end
      end

      SPI_RX: begin
        if (sample_edge) begin
          shift_rx = 1'b1;
          if (bit_cnt == 4'd7) begin
            spi_next_state = SPI_PROCESS;
          end
        end
      end

      SPI_PROCESS: begin
        if (img_byte_cnt < IMG_BYTE_COUNT) begin
          spi_next_state = SPI_IMG_RX;
        end else begin
          spi_next_state = SPI_DONE;
        end
      end

      SPI_IMG_RX: begin
        spi_next_state = SPI_RX;
      end

      SPI_DONE: begin
        if (cs_sync_2) begin
          spi_next_state = SPI_WAIT;  // hold data one extra cycle
        end
      end

      SPI_WAIT: begin
        spi_next_state = SPI_IDLE;  // now allow transition
      end

      default: spi_next_state = SPI_IDLE;
    endcase
  end

  //===================================================
  // Shift Registers and Flags
  //===================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_shift_reg   <= '0;
      bit_cnt        <= '0;
      spi_rx_data    <= '0;
      byte_valid_int <= 1'b0;
      img_byte_cnt   <= '0;
    end else begin
      if (spi_state == SPI_RX && spi_next_state != SPI_RX) byte_valid_int <= 1'b0;

      if (shift_rx) begin
        rx_shift_reg <= {rx_shift_reg[6:0], copi_sync_2};
        bit_cnt <= bit_cnt + 1;
      end

      if (spi_state == SPI_PROCESS) begin
        img_buffer[img_byte_cnt] <= rx_shift_reg;
        img_byte_cnt <= img_byte_cnt + 1;

        $display("[SPI RX] (%0d): Byte Processed. Data = %b, Byte Count = %0d", cycle_cnt,
                 rx_shift_reg, img_byte_cnt);

        spi_rx_data    <= rx_shift_reg;
        byte_valid_int <= 1'b1;
        bit_cnt <= 0;
      end else byte_valid_int <= 1'b0;

      // Clear once acknowledged
      if (byte_valid_int && byte_taken) begin
        byte_valid_int <= 1'b0;
        spi_rx_data    <= '0;
      end

      if (spi_state == SPI_WAIT) begin
        img_byte_cnt <= '0;
      end
    end
  end


  //===================================================
  // Output Assignments
  //===================================================
  assign spi_byte_valid = byte_valid_int;



  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_cnt <= 0;
      prev_spi_state <= SPI_IDLE;
      prev_cs_sync_2 <= 1'b1;
      prev_rx_mode <= 1'b0;
    end else begin
      cycle_cnt <= cycle_cnt + 1;

      // Debug FSM state transitions
      if (spi_state != prev_spi_state) begin
        $display("[SPI RX] (%0d): State Transition: %s -> %s", cycle_cnt, prev_spi_state.name(),
                 spi_state.name());
        prev_spi_state <= spi_state;
      end

      // Debug CS_N and RX Mode changes
      if (cs_sync_2 != prev_cs_sync_2 || rx_mode != prev_rx_mode) begin
        $display("[SPI RX] (%0d): SPI Active. CS_N = %b -> %b, RX Mode = %b -> %b", cycle_cnt,
                 prev_cs_sync_2, cs_sync_2, prev_rx_mode, rx_mode);
        prev_cs_sync_2 <= cs_sync_2;
        prev_rx_mode   <= rx_mode;
      end

      // Comment out verbose bit-level debug
      // if (shift_rx)
      //   $display(
      //       "[SPI RX] (%0d): Shift Edge Detected. COPI = %b, Shift Register = %b, Bit Count = %0d",
      //       cycle_cnt,
      //       copi_sync_2,
      //       rx_shift_reg,
      //       bit_cnt
      //   );

      // Debug when a byte is processed
      if (spi_state == SPI_PROCESS)
        $display(
            "[SPI RX] (%0d): Byte Processed. Data = %b, Byte Count = %0d",
            cycle_cnt,
            rx_shift_reg,
            img_byte_cnt
        );

      // Debug when the SPI is done
      if (spi_state == SPI_DONE)
        $display("[SPI RX] (%0d): SPI Done. Image Byte Count = %0d", cycle_cnt, img_byte_cnt);
    end
  end

endmodule
