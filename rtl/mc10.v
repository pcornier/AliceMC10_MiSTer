
module mc10 (
  input reset,
  input clk_sys,
  input clk_4,
  input [10:0] ps2_key,
  input [10:0] exp_in, // D7-D0, sel, reset, nmi
  output [17:0] exp_out, // R/W, A15-A0, E
  output [7:0] red,
  output [7:0] green,
  output [7:0] blue,
  output hsync,
  output vsync,
  output hblank,
  output vblank,
  output audio,
  input cin
);

wire [15:0] cpu_addr;
wire E_CLK;
wire cpu_rw;
wire [3:0] U4_Y1, U4_Y2;
wire [12:0] vdg_addr;
wire [7:0] cpu_dout, rom_dout, ram_dout, ram_dout_b;
wire [3:0] r4, g4, b4;
wire [7:0] KR, kb_rows;
wire [5:0] U14_out;
wire shift = kb_rows[6];
reg [5:0] U8;

assign red[7:4] = r4;
assign green[7:4] = g4;
assign blue[7:4] = b4;

assign audio = U8[5];

wire RESET = reset | exp_in[1];

reg [1:0] clk_div;
always @(posedge clk_4)
  clk_div <= clk_div + 2'd1;

wire clk_cpu = clk_div[1];

reg [7:0] data_bus;
always @(posedge clk_sys)
  data_bus <= rom_dout | (U4_Y1[1] ? 8'd0 : ram_dout) | U14_out;

MC6803_gen2 U1(
  .clk(clk_cpu),
  .RST(RESET),
  .hold(0),
  .halt(0),
  .irq(0),
  .nmi(exp_in[2]),
  .PORT_A_IN(),
  .PORT_B_IN({ cin, 1'b0, shift, 1'b0 }),
  .DATA_IN(data_bus),
  .PORT_A_OUT(KR),
  .PORT_B_OUT(),
  .ADDRESS(cpu_addr),
  .DATA_OUT(cpu_dout),
  .E_CLK(E_CLK),
  .rw(cpu_rw)
);

rom_mc10 U3(
  .clk(clk_sys),
  .addr(cpu_addr),
  .dout(rom_dout),
  .cs(U4_Y1[3])
);

x74155 U4(
  .C(2'b01),
  .G({ exp_in[0] | cpu_addr[12], exp_in[0] }),
  .A(cpu_addr[14]),
  .B(cpu_addr[15]),
  .Y1(U4_Y1),
  .Y2(U4_Y2)
);

wire U8_clock = ~(cpu_rw | U4_Y1[2]);
always @(posedge U8_clock or posedge RESET)
  if (RESET) U8 <= 6'd0;
  else U8 <= cpu_dout[7:2];

dpram u9_u10(
  .clock(clk_sys),

  .address_a(cpu_addr[11:0]),
  .data_a(cpu_dout),
  .wren_a(~(cpu_rw|U4_Y1[1])),
  .q_a(ram_dout),

  .address_b(vdg_addr[11:0]),
  .q_b(ram_dout_b)
);

mc6847_mc10 U11(
  .clk(clk_4),
  .clk_sys(clk_sys),
  .clk_ena(1'b1),
  .reset(RESET),
  .videoaddr(vdg_addr),
  .dd(ram_dout_b),
  .an_g(U8[3]),
  .an_s(ram_dout_b[7]),
  .intn_ext(U8[0]),
  .gm({ U8[0], U8[1], U8[2] }), // 5 4 3
  .css(U8[4]),
  .inv(ram_dout_b[6]),
  .red(r4),
  .green(g4),
  .blue(b4),
  .hsync(hsync),
  .vsync(vsync),
  .hblank(hblank),
  .vblank(vblank)
);

x14503B U14(
  .in(~kb_rows),
  .out(U14_out),
  .A(U4_Y1[2] | ~cpu_rw),
  .B(U4_Y1[2] | ~cpu_rw)
);

keyboard keyboard(
  .clk_sys(clk_sys),
  .reset(RESET),
  .ps2_key(ps2_key),
  .addr(KR),
  .kb_rows(kb_rows),
  .kblayout(1'b0)
);

endmodule