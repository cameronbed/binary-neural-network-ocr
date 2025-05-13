module seven_seg_display (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       result_ready,
    input  logic [3:0] result_in,
    output logic [6:0] seg,
    output logic       decimalPoint,
    output logic [3:0] an
);
  logic [3:0] digit_0 = 4'd0;
  logic [3:0] digit_1 = 4'd0;
  logic [3:0] digit_2 = 4'd0;
  logic [3:0] digit_3;
  logic [3:0] result_reg;
  logic       result_reg_valid;

  logic [3:0] digit_vals       [3:0];
  logic [1:0] digit_sel;
  logic [6:0] seg_out;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_reg       <= 4'd0;
      result_reg_valid <= 1'b0;
    end else begin
      result_reg_valid <= result_ready;
      if (result_ready) result_reg <= result_in;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      digit_3 <= 4'd0;
    end else if (result_reg_valid) begin
      digit_3 <= result_reg;
    end
  end

  always_comb begin
    digit_vals[0] = digit_0;
    digit_vals[1] = digit_1;
    digit_vals[2] = digit_2;
    digit_vals[3] = digit_3;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) digit_sel <= 2'd0;
    else digit_sel <= digit_sel + 1;
  end

  always_comb begin
    an            = 4'b1111;
    an[digit_sel] = 1'b0;
    seg_out       = seven_segment_encode(digit_vals[digit_sel]);
    decimalPoint  = 1'b0;
  end

  assign seg = seg_out;

  function logic [6:0] seven_segment_encode(input logic [3:0] v);
    case (v)
      4'd0: seven_segment_encode = 7'b100_0000;
      4'd1: seven_segment_encode = 7'b111_1001;
      4'd2: seven_segment_encode = 7'b010_0100;
      4'd3: seven_segment_encode = 7'b011_0000;
      4'd4: seven_segment_encode = 7'b001_1001;
      4'd5: seven_segment_encode = 7'b001_0010;
      4'd6: seven_segment_encode = 7'b000_0010;
      4'd7: seven_segment_encode = 7'b111_1000;
      4'd8: seven_segment_encode = 7'b000_0000;
      4'd9: seven_segment_encode = 7'b001_0000;
      default: seven_segment_encode = 7'b111_1111;
    endcase
  endfunction

endmodule
