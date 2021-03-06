// Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2015.2 (win64) Build 1266856 Fri Jun 26 16:35:25 MDT 2015
// Date        : Tue Dec 01 08:58:13 2015
// Host        : jnaughto-MOBL1 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               c:/Users/jnaughto/Documents/Personal/luddes_R_in_GL/luddes_R_in_GL.srcs/sources_1/ip/clk_wiz_out_mhz/clk_wiz_out_mhz_stub.v
// Design      : clk_wiz_out_mhz
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tcsg324-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module clk_wiz_out_mhz(clk_in1, clk_21_478_mhz, clk_4_698_mhz, reset, locked)
/* synthesis syn_black_box black_box_pad_pin="clk_in1,clk_21_478_mhz,clk_4_698_mhz,reset,locked" */;
  input clk_in1;
  output clk_21_478_mhz;
  output clk_4_698_mhz;
  input reset;
  output locked;
endmodule
