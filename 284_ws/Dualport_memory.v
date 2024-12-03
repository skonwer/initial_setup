// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module sram (CLK, D, Q, CEN, REN, WEN, A_W, A_R);

  input                   CLK;
  input                   WEN; // write when 0
  input                   REN; // read when 0
  input                   CEN; // enable when 0
  input  [data_width-1:0]   D;
  input  [addr_width-1:0] A_R; // read addr
  input  [addr_width-1:0] A_W; // write addr
  output [data_width-1:0]   Q;

  parameter num = 2048;
  parameter data_width = 32;
  localparam addr_width = $clog2(num);

  reg [data_width-1:0]      memory [num-1:0];
  reg [addr_width-1:0]  add_q;
  assign Q = memory[add_q];

  always @ (posedge CLK) begin

   if (!CEN && !REN) // read 
      add_q <= A_R;
   if (!CEN && !WEN) // write
      memory[A_W] <= D; 

  end

endmodule
