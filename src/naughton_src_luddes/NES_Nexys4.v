// Copyright (c) 2012-2013 Ludvig Strigeus
// This program is GPL Licensed. See COPYING for the full license.

`timescale 1ns / 1ps

// Asynchronous PSRAM controller for byte access
// After outputting a byte to read, the result is available 70ns later.
module MemoryController(
                 input clk,
                 input read_a,             // Set to 1 to read from RAM
                 input read_b,             // Set to 1 to read from RAM
                 input write,              // Set to 1 to write to RAM
                 input [23:0] addr,        // Address to read / write
                 input [7:0] din,          // Data to write
                 output reg [7:0] dout_a,  // Last read data a
                 output reg [7:0] dout_b,  // Last read data b
                 output reg busy,          // 1 while an operation is in progress

                 output reg MemOE,         // Output Enable. Enable when Low.
                 output reg MemWR,         // Write Enable. WRITE when Low.
                 output MemAdv,            // Address valid. Keep LOW for Async.
                 output MemClk,            // Clock for sync oper. Keep LOW for Async.
                 output reg RamCS,         // Chip Enable. Active = LOW
                 output RamCRE,            // CRE = Control Register. LOW = Normal mode.
                 output reg RamUB,         // Upper byte enable
                 output reg RamLB,         // Lower byte enable
                 output reg [22:0] MemAdr,
                 inout [15:0] MemDB);
                 
  // These are always low for async operations
  assign MemAdv = 0;
  assign MemClk = 0;
  assign RamCRE = 0;
  reg [7:0] data_to_write;
  assign MemDB = MemOE ? {data_to_write, data_to_write} : 16'bz; // MemOE == 0 means we need to output tristate
  reg [1:0] cycles;
  reg r_read_a;
  
  always @(posedge clk) begin
    // Initiate read or write
    if (!busy) begin
      if (read_a || read_b || write) begin
        MemAdr <= addr[23:1];
        RamUB <= !(addr[0] != 0); // addr[0] == 0 asserts RamUB, active low.
        RamLB <= !(addr[0] == 0);
        RamCS <= 0;    // 0 means active
        MemWR <= !(write != 0); // Active Low
        MemOE <= !(write == 0);
        busy <= 1;
        data_to_write <= din;
        cycles <= 0;
        r_read_a <= read_a;
      end else begin
        MemOE <= 1;
        MemWR <= 1;
        RamCS <= 1;
        RamUB <= 1;
        RamLB <= 1;
        busy <= 0;
        cycles <= 0;
      end
    end else begin
      if (cycles == 2) begin
        // Now we have waited 3x45 = 135ns, latch incoming data on read.
        if (!MemOE) begin
          if (r_read_a) dout_a <= RamUB ? MemDB[7:0] : MemDB[15:8];
          else dout_b <= RamUB ? MemDB[7:0] : MemDB[15:8];
        end
        MemOE <= 1; // Deassert Output Enable.
        MemWR <= 1; // Deassert Write
        RamCS <= 1; // Deassert Chip Select
        RamUB <= 1; // Deassert upper/lower byte
        RamLB <= 1;
        busy <= 0;
        cycles <= 0;
      end else begin
        cycles <= cycles + 1;
      end
    end
  end
endmodule  // MemoryController

//15nov27 - This module will read from the .coe file that contains the Game ROM and 
//              provide the correct signals to feed into the GameLoader module so the ROM
//              can be consumed by the emulator
module coe_to_loader(
        input clk,
        input reset,
        input GameLoader_done_in,
        //debug
        output reg [3:0] coe_to_loader_state_out,
        output [15:0] coe_to_loader_rom_addr_out,
        output reg [7:0] coe_data_out,
        output reg coe_to_loader_clk_out         
    );
   
    wire [7:0] ROM_data_out;
    reg [15:0] rom_addr; 

    assign coe_to_loader_rom_addr_out = rom_addr; 

    reg coe_to_loader_clk_out_ns;

    always @(posedge clk) begin
        if(reset) begin
            coe_to_loader_clk_out <= 1'b0; 
            //reset to beginning of ROM
            rom_addr <= 16'd0;

            //debug
            coe_to_loader_state_out <= 4'h8;

        end //reset
        else begin
            rom_addr <= rom_addr + 1;
            //debug
            coe_to_loader_state_out <= 4'h4;
            coe_data_out <= ROM_data_out; 


//-fail-            if(coe_to_loader_clk_out) begin
//-fail-                //debug
//-fail-                coe_to_loader_state_out <= 4'h4;
//-fail-
//-fail-                coe_to_loader_clk_out <= 1'd0;
//-fail-                rom_addr <= rom_addr + 1; 
//-fail-
//-fail-            end else begin
//-fail-                coe_to_loader_clk_out <= 1'd1;
//-fail-
//-fail-            end //~coe_to_loader_clk_out  

//--oldest--            coe_to_loader_clk_out <= coe_to_loader_clk_out_ns;
//--oldest--
//--oldest--            if(~GameLoader_done_in) begin
//--oldest--                coe_to_loader_clk_out_ns <= ~coe_to_loader_clk_out;
//--oldest--
//--oldest--                if(coe_to_loader_clk_out) begin
//--oldest--                    rom_addr <= rom_addr + 1; 
//--oldest--                    //debug
//--oldest--                    coe_to_loader_state_out <= 4'h4;
//--oldest--                end// coe_to_loader_clk_out
//--oldest--            end // ~GameLoader_done_in
//--oldest--            else begin
//--oldest--                //15nov28 - not sure I need this becuase it will only re-load 
//--oldest--                rom_addr <= 16'd0;
//--oldest--                //debug
//--oldest--                coe_to_loader_state_out <= 4'h2;
//--oldest--                coe_to_loader_clk_out <= 1'b0;
//--oldest--
//--oldest--            end//else (gameLoader)

        end //else  (reset)

    end //always @(posedge clk)


    smb_ROM_take2 smb_rom (
        .clka(clk),            //input wire clka
        .addra(rom_addr),           //input wire addra
        .douta(ROM_data_out)            //output wire [7:0] doutb
    );
endmodule 


// Module reads bytes and writes to proper address in ram.
// Done is asserted when the whole game is loaded.
// This parses iNES headers too.
module GameLoader(input clk, input reset,
                  input [7:0] indata, input indata_clk,
                  output reg [21:0] mem_addr, output [7:0] mem_data, output mem_write,
                  output [31:0] mapper_flags,
                  output reg done,

                  //JN - Debug 
                  output [2:0] gameLoader_led_out,
                  output [7:0] gameLoader_ines_0_out,
                  output [7:0] gameLoader_ines_1_out,
                  output [7:0] gameLoader_ines_2_out,
                  output [7:0] gameLoader_ines_3_out,
                  output       gameLoader_ines_6_2_out,
                  output       gameLoader_ines_6_3_out,
                  output [3:0] gameLoader_ctr_out,
                  output [3:0] gameLoader_ctr_flop1_out,
                  output [2:0] gameLoader_prg_size_out,
                  output [7:0] gameLoader_mem_data_out,
                  output [1:0] gameLoader_state_out,
                  output reg [1:0] gameLoader_ctr_state_out,
                  output [7:0] gameLoader_rom_data_out_flop1_out,

                  output error);
  reg [1:0] state = 0;
  reg [7:0] prgsize;
  reg [3:0] ctr;
  reg [7:0] ines[0:15]; // 16 bytes of iNES header
  reg [21:0] bytes_left;

  wire [7:0] GL_ROM_data_out;
  reg  [7:0] rom_data_out_flop1;
  reg  [3:0] ctr_flop1;
  reg  [3:0] ctr_flop2;
  reg  [3:0] ctr_flop3;
  reg  [15:0] rom_ctr;

  //JN - DEBUG   
  assign gameLoader_led_out[1:0] = state;
  assign gameLoader_state_out = state;
  assign gameLoader_led_out[2] = reset;
  assign gameLoader_ines_0_out = ines[0];
  assign gameLoader_ines_1_out = ines[1];
  assign gameLoader_ines_2_out = ines[2];
  assign gameLoader_ines_3_out = ines[3];
  assign gameLoader_ines_6_2_out = ines[6][2];
  assign gameLoader_ines_6_3_out = ines[6][3];
  assign gameLoader_ctr_out = ctr;
  assign gameLoader_ctr_flop1_out = ctr_flop1;
  assign gameLoader_prg_size_out = prg_size;
  assign gameLoader_mem_data_out = mem_data;
  assign gameLoader_rom_data_out_flop1_out = rom_data_out_flop1;
  assign gameLoader_rom_ctr_out = rom_ctr;

  assign error = (state == 3);
  wire [7:0] prgrom = ines[4];
  wire [7:0] chrrom = ines[5];
  //assign mem_data = indata;
  //JN - 15dec01 - assign mem_data = GL_ROM_data_out;
  assign mem_data = rom_data_out_flop1;
  //15dec01 - JN - because i'm holding indata_clk to 1'd1 we need to qualify with a mem write enable of clk
  //assign mem_write = (bytes_left != 0) && (state == 1 || state == 2) && indata_clk;
  assign mem_write = (bytes_left != 0) && (state == 1 || state == 2) && indata_clk && clk;
  
  wire [2:0] prg_size = prgrom <= 1  ? 0 :
                        prgrom <= 2  ? 1 : 
                        prgrom <= 4  ? 2 : 
                        prgrom <= 8  ? 3 : 
                        prgrom <= 16 ? 4 : 
                        prgrom <= 32 ? 5 : 
                        prgrom <= 64 ? 6 : 7;
                        
  wire [2:0] chr_size = chrrom <= 1  ? 0 : 
                        chrrom <= 2  ? 1 : 
                        chrrom <= 4  ? 2 : 
                        chrrom <= 8  ? 3 : 
                        chrrom <= 16 ? 4 : 
                        chrrom <= 32 ? 5 : 
                        chrrom <= 64 ? 6 : 7;
  
  wire [7:0] mapper = {ines[7][7:4], ines[6][7:4]};
  wire has_chr_ram = (chrrom == 0);
  assign mapper_flags = {16'b0, has_chr_ram, ines[6][0], chr_size, prg_size, mapper};
  always @(posedge clk) begin
    if (reset) begin
      state <= 0;
      done <= 0;
      ctr <= 0;
      //JN
      rom_ctr <= 0;
      mem_addr <= 0;  // Address for PRG
      gameLoader_ctr_state_out <= 2'd0;
      //clearing header
      ines[0] <= 8'd0;
      ines[1] <= 8'd0;
      ines[2] <= 8'd0;
      ines[3] <= 8'd0;
      ines[4] <= 8'd0;
      ines[5] <= 8'd0;
      ines[6] <= 8'd0;
      ines[7] <= 8'd0;
      ines[8] <= 8'd0;
      ines[9] <= 8'd0;
      ines[10] <= 8'd0;
      ines[11] <= 8'd0;
      ines[12] <= 8'd0;
      ines[13] <= 8'd0;
      ines[14] <= 8'd0;
      ines[15] <= 8'd0;
    end else begin
    
      rom_data_out_flop1 <= GL_ROM_data_out;
      ctr_flop1 <= ctr;
      ctr_flop2 <= ctr_flop1;
      ctr_flop3 <= ctr_flop2;

      case(state)
      // Read 16 bytes of ines header
      0: if (indata_clk) begin
           gameLoader_ctr_state_out <= 2'd1;
           //ines[ctr] <= indata;
           //JN - 15dec01 - ines[ctr] <= GL_ROM_data_out;
           //15dec01 - JN - ***CLOSE*** - ines[ctr_flop1] <= rom_data_out_flop1;
           //15dec01 - JN - 352p - **$$$ WORKS $$$** - ines[(ctr_flop1-2)] <= rom_data_out_flop1;
           //JN - Need to delay writing to get around 2 cycle latency from smb_ROM
           ines[ctr_flop3] <= rom_data_out_flop1;
           bytes_left <= {prgrom, 14'b0};

           rom_ctr <= rom_ctr + 1;
           ctr <= ctr + 1;

           if (ctr == 4'b1111) begin
              gameLoader_ctr_state_out <= 2'd2;
             //JN - state <= (ines[0] == 8'h4E) && (ines[1] == 8'h45) && (ines[2] == 8'h53) && (ines[3] == 8'h1A) && !ines[6][2] && !ines[6][3] ? 1 : 3;
             state <= (ines[0] == 8'h4E) && (ines[1] == 8'h45) && (ines[2] == 8'h53) && (ines[3] == 8'h1A) && !ines[6][2] && !ines[6][3] ? 1 : 0;
           end//ctr==4'b1111
         end//indata_clk
         else begin
            gameLoader_ctr_state_out <=2'd3;
         end //~indata_clk
      1, 2: begin // Read the next |bytes_left| bytes into |mem_addr|
          if (bytes_left != 0) begin
            if (indata_clk) begin
              //JN
              rom_ctr <= rom_ctr + 1;

              bytes_left <= bytes_left - 1;
              mem_addr <= mem_addr + 1;
            end
          end else if (state == 1) begin
            state <= 2;
            mem_addr <= 22'b10_0000_0000_0000_0000_0000; // Address for CHR
            //JN - Adding one more Byte to account for the initial flopped read.  Need to let the
            //bytes_left <= {1'b0, chrrom, 13'b0};
            bytes_left <= {1'b0, chrrom, 13'b0};
          end else if (state == 2) begin
            done <= 1;
          end
        end //state 1 or 2
     3: begin //JN - ERROR STATE
            ines[0] = 8'hDE;    //FOR Display of ERROR State 
            ines[1] = 8'hAD;    //FOR Display of ERROR State
        end //state 3
      endcase
    end
  end

    smb_ROM_take2 smb_rom (
        .clka(clk),            //input wire clka
        //JN - WORKS - .addra(ctr),           //input wire addra
        .addra(rom_ctr),           //input wire addra
        .douta(GL_ROM_data_out)            //output wire [7:0] doutb
    );



endmodule


module NES_Nexys4(input CLK100MHZ,
                 input CPU_RESET,
                 input [4:0] BTN,
                 input [15:0] SW,
                 output [15:0] LED,
                 output [7:0] SSEG_CA,
                 output [7:0] SSEG_AN,
                 // UART
                 input UART_RXD,
                 output UART_TXD,
                 // VGA
                 output vga_v, output vga_h, output [3:0] vga_r, output [3:0] vga_g, output [3:0] vga_b,
                 // Memory
                 output MemOE,          // Output Enable. Enable when Low.
                 output MemWR,          // Write Enable. WRITE when Low.
                 output MemAdv,         // Address valid. Keep LOW for Async.
                 input MemWait,         // Ignore for Async.
                 output MemClk,         // Clock for sync oper. Keep LOW for Async.
                 output RamCS,          // Chip Enable. Active = LOW
                 output RamCRE,         // CRE = Control Register. LOW = Normal mode.
                 output RamUB,          // Upper byte enable
                 output RamLB,          // Lower byte enable
                 output [22:0] MemAdr,
                 inout [15:0] MemDB,
                 // Sound board
                 output AUD_MCLK,
                 output AUD_LRCK,
                 output AUD_SCK,
                 output AUD_SDIN
                 );

  wire clock_locked;
  wire clk;
//  clk_wiz_v3_6 clock_21mhz(.CLK_IN1(CLK100MHZ), .CLK_OUT1(clk),  .RESET(1'b0), .LOCKED(clock_locked));
  clk_wiz_out_mhz instance_name
   (
   // Clock in ports
    .clk_in1(CLK100MHZ),      // input clk_in1
    // Clock out ports
    .clk_21_478_mhz(clk),     // output clk_21_478_mhz
    .clk_4_698_mhz(clk_4_698_mhz),     // output clk_4_698_mhz
    // Status and control signals
    .reset(1'd0), // input reset
    .locked(locked)      // output locked
   );

  // UART
  wire [7:0] uart_data;
  wire [7:0] uart_addr;
  wire       uart_write;
  wire       uart_error;
  UartDemux uart_demux(clk, 1'b0, UART_RXD, uart_data, uart_addr, uart_write, uart_error);
  assign     UART_TXD = 1;

  reg  [7:0] loader_conf;
  reg  [7:0] loader_btn, loader_btn_2;
  always @(posedge clk) begin
    if (uart_addr == 8'h35 && uart_write)
      loader_conf <= uart_data;
    if (uart_addr == 8'h40 && uart_write)
      loader_btn <= uart_data;
    if (uart_addr == 8'h41 && uart_write)
      loader_btn_2 <= uart_data;
  end

  // NES Palette -> RGB332 conversion
  reg [14:0] pallut[0:63];
  initial $readmemh("nes_palette.txt", pallut);

  // LED Display
  reg [31:0] led_value;
  reg [7:0] led_enable;
  LedDriver led_driver(clk, led_value, led_enable, SSEG_CA, SSEG_AN);

  wire [8:0] cycle;
  wire [8:0] scanline;
  wire [15:0] sample;
  wire [5:0] color;
  wire joypad_strobe;
  wire [1:0] joypad_clock;
  wire [21:0] memory_addr;
  wire memory_read_cpu, memory_read_ppu;
  wire memory_write;
  wire [7:0] memory_din_cpu, memory_din_ppu;
  wire [7:0] memory_dout;
  reg [7:0] joypad_bits, joypad_bits2;
  reg [1:0] last_joypad_clock;
  wire [31:0] dbgadr;
  wire [1:0] dbgctr;

  reg [1:0] nes_ce;

  always @(posedge clk) begin
    if (joypad_strobe) begin
      joypad_bits <= loader_btn;
      joypad_bits2 <= loader_btn_2;
    end
    if (!joypad_clock[0] && last_joypad_clock[0])
      joypad_bits <= {1'b0, joypad_bits[7:1]};
    if (!joypad_clock[1] && last_joypad_clock[1])
      joypad_bits2 <= {1'b0, joypad_bits2[7:1]};
    last_joypad_clock <= joypad_clock;
  end
  
  wire cpu_reset = ~CPU_RESET;
  wire cpu_reset_n = ~cpu_reset;

  // Loader
  //15nov27 - JN START - replacing uart_data with coe_data_out
  wire [7:0] coe_data_out;
  wire coe_to_loader_clk_out;

  //wire [7:0] loader_input = uart_data;
  wire [7:0] loader_input = coe_data_out;

  //JN - this is just esentially an enable signal to let the GameLoader module
  //        know when to consume the loader_input data
  //   - Luddes uses his C++ program to assign a uart_addr based on what he's doing
  //        (loading game, reading controller buttons, etc.)
  //wire       loader_clk   = (uart_addr == 8'h37) && uart_write;
  wire       loader_clk   = coe_to_loader_clk_out;

  wire [3:0] coe_to_loader_state_out;
  wire [15:0] coe_to_loader_rom_addr_out;

  wire [21:0] loader_addr;
  wire [7:0] loader_write_data;
  //JN - making loader_reset and coe_to_loader reset on a SW[0] for now
  //wire loader_reset = loader_conf[0];
  //wire loader_reset = ~(SW[15]); 
  wire loader_reset = cpu_reset;
  wire loader_write;
  wire [31:0] mapper_flags;
  wire loader_done, loader_fail;

  //JN - Debug
  wire [2:0] gameLoader_led_out;
  wire [7:0] gameLoader_ines_0_out;
  wire [7:0] gameLoader_ines_1_out;
  wire [7:0] gameLoader_ines_2_out;
  wire [7:0] gameLoader_ines_3_out;
  wire       gameLoader_ines_6_2_out;
  wire       gameLoader_ines_6_3_out;
  wire [3:0] gameLoader_ctr_out;
  wire [3:0] gameLoader_ctr_flop1_out;
  wire [2:0] gameLoader_prg_size_out;
  wire [7:0] gameLoader_mem_data_out;
  wire [1:0] gameLoader_state_out;
  wire [1:0] gameLoader_ctr_state_out;
  wire [7:0] gameLoader_rom_data_out_flop1_out;


  wire my_sw_14;
  assign my_sw_14 = SW[14];
  wire my_sw_15;
  assign my_sw_15 = SW[15];


  //JN - 11/30 - GameLoader loader(clk, loader_reset, loader_input, loader_clk,
  GameLoader loader(
                    //.clk(clk),
                    //.clk(my_sw_14),
                    .clk(SW[13] ? clk : my_sw_14),
                    .reset(loader_reset),
                    .indata(coe_data_out),
                    //.indata_clk(clk),
                    .indata_clk(1'd1),
                    //.indata_clk(SW[13] ? clk : SW[12]),
                    .mem_addr(loader_addr),
                    .mem_data(loader_write_data),
                    .mem_write(loader_write),
                    .mapper_flags(mapper_flags),
                    .done(loader_done),
                  //JN - Debug 
                    .gameLoader_led_out(gameLoader_led_out),
                    .gameLoader_ines_0_out(gameLoader_ines_0_out),
                    .gameLoader_ines_1_out(gameLoader_ines_1_out),
                    .gameLoader_ines_2_out(gameLoader_ines_2_out),
                    .gameLoader_ines_3_out(gameLoader_ines_3_out),
                    .gameLoader_ines_6_2_out(gameLoader_ines_6_2_out),
                    .gameLoader_ines_6_3_out(gameLoader_ines_6_3_out),
                    .gameLoader_ctr_out(gameLoader_ctr_out),
                    .gameLoader_ctr_flop1_out(gameLoader_ctr_flop1_out),
                    .gameLoader_prg_size_out(gameLoader_prg_size_out),
                    .gameLoader_mem_data_out(gameLoader_mem_data_out),
                    .gameLoader_state_out(gameLoader_state_out),
                    .gameLoader_ctr_state_out(gameLoader_ctr_state_out),
                    .gameLoader_rom_data_out_flop1_out(gameLoader_rom_data_out_flop1_out),
                    .error(loader_fail)
                );

  //JN - coe_to_loader
  coe_to_loader coe2loader(
        //.clk(clk),
        //JN - IF YOU WANT TO USE THIS UNCOMMENT LINE 59 IN NEXYS4_MANUAL_CONVERT.XDC 
                  //.clk(my_sw_14),
                  .clk(SW[13] ? clk : my_sw_14),
        .reset(loader_reset),
        .GameLoader_done_in(loader_done),
        .coe_to_loader_state_out(coe_to_loader_state_out),
        .coe_to_loader_rom_addr_out(coe_to_loader_rom_addr_out),
        .coe_data_out(coe_data_out),
        .coe_to_loader_clk_out(coe_to_loader_clk_out)
  );



  wire reset_nes = (BTN[3] || !loader_done);
  wire run_mem = (nes_ce == 0) && !reset_nes;
  wire run_nes = (nes_ce == 3) && !reset_nes;

  // NES is clocked at every 4th cycle.
  always @(posedge clk)
    nes_ce <= nes_ce + 1;
    
  NES nes(clk, reset_nes, run_nes,
          mapper_flags,
          sample, color,
          joypad_strobe, joypad_clock, {joypad_bits2[0], joypad_bits[0]},
          SW[4:0],
          memory_addr,
          memory_read_cpu, memory_din_cpu,
          memory_read_ppu, memory_din_ppu,
          memory_write, memory_dout,
          cycle, scanline,
          dbgadr,
          dbgctr);

  // This is the memory controller to access the board's PSRAM
  wire ram_busy;
  MemoryController memory(clk,
                          memory_read_cpu && run_mem, 
                          memory_read_ppu && run_mem,
                          memory_write && run_mem || loader_write,
                          loader_write ? {2'b00, loader_addr} : {2'b00, memory_addr},
                          loader_write ? loader_write_data : memory_dout,
                          memory_din_cpu,
                          memory_din_ppu,
                          ram_busy,
                          MemOE, MemWR, MemAdv, MemClk, RamCS, RamCRE, RamUB, RamLB, MemAdr, MemDB);
  reg ramfail;
  always @(posedge clk) begin
    if (loader_reset)
      ramfail <= 0;
    else
      ramfail <= ram_busy && loader_write || ramfail;
  end

  wire [14:0] doubler_pixel;
  wire doubler_sync;
  wire [9:0] vga_hcounter, doubler_x;
  wire [9:0] vga_vcounter;
  
  VgaDriver vga(clk, vga_h, vga_v, vga_r, vga_g, vga_b, vga_hcounter, vga_vcounter, doubler_x, doubler_pixel, doubler_sync, SW[0]);
  
  wire [14:0] pixel_in = pallut[color];
  Hq2x hq2x(clk, pixel_in, SW[5], 
            scanline[8],        // reset_frame
            (cycle[8:3] == 42), // reset_line
            doubler_x,          // 0-511 for line 1, or 512-1023 for line 2.
            doubler_sync,       // new frame has just started
            doubler_pixel);     // pixel is outputted

  wire [15:0] sound_signal = {sample[15] ^ 1'b1, sample[14:0]};
//  wire [15:0] sound_signal_fir;
//  wire sample_now_fir;
//  FirFilter fir(clk, sound_signal, sound_signal_fir, sample_now_fir);
  // Display mapper info on screen
  always @(posedge clk) begin
    if(cpu_reset) begin
        led_enable <= 255;
        led_value <= 32'd0;
    end else begin
        led_enable <= 255;
        //JN - led_value <= sound_signal;
        led_value <= {  //gameLoader_ines_0_out,        //[31:24]
                        loader_write_data,        //[31:24]
                        gameLoader_ines_1_out,        //[23:16]
                        //gameLoader_ines_2_out,        //[23:16]
                        //gameLoader_ines_3_out,        //[23:16]
                        gameLoader_rom_data_out_flop1_out, //[15:8]
                        //gameLoader_mem_data_out,      //[15:8]
                        2'd0,                         //[7:6]
                        gameLoader_state_out,         //[5:4]
                        //gameLoader_ctr_out            //[3:0]
                        gameLoader_ctr_flop1_out        //[3;0]
                        //coe_to_loader_rom_addr_out[3:0]    //[3:0]
                     };
    end//~cpu_reset
  end

  reg [7:0] sound_ctr;
  always @(posedge clk)
    sound_ctr <= sound_ctr + 1;
  wire sound_load = /*SW[6] ? sample_now_fir : */(sound_ctr == 0);
  SoundDriver sound_driver(clk, 
      /*SW[6] ? sound_signal_fir : */sound_signal, 
      sound_load,
      sound_load,
      AUD_MCLK, AUD_LRCK, AUD_SCK, AUD_SDIN);
 
  assign LED = {
                //gameLoader_ctr_out,  //LED[15:12]
                //4'd0,                
                //coe_data_out,      //LED[15:8]
                //gameLoader_ines_0_out,      //LED[15:8]
                coe_to_loader_state_out,//LED[15:12]
                //2'd0,                   //LED[11:10]
                //clk,                    //LED[9]
                //coe_to_loader_clk_out,  //LED[8]
                //loader_clk,             //LED[7]
                
                gameLoader_ctr_state_out,   //LED[11:10]
                gameLoader_ines_6_3_out,    //LED[9]
                gameLoader_ines_6_2_out,    //LED[8]
                //clk,                    //LED[7]
                reset_nes,                    //LED[7]
                run_mem,                    //LED[6]
                2'b0,                       //LED[5:4]
                //gameLoader_led_out,     //LED[6]=reset LED[5:4] = GameLoader.state
                loader_write,           //LED[3]
                ramfail,                //LED[2]
                loader_fail,            //LED[1]
                loader_done};           //LED[0]
endmodule
