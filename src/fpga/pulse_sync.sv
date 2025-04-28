module pulse_sync (
    input  logic src_clk,
    input  logic src_pulse,
    input  logic dst_clk,
    output logic dst_pulse
);
  logic src_toggle;
  logic dst_toggle_d, dst_toggle_q;

  always_ff @(posedge src_clk) begin
    if (src_pulse) src_toggle <= ~src_toggle;
  end

  always_ff @(posedge dst_clk) begin
    dst_toggle_d <= src_toggle;
    dst_toggle_q <= dst_toggle_d;
  end

  assign dst_pulse = dst_toggle_d ^ dst_toggle_q;
endmodule
