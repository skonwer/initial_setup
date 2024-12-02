// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module l0 (clk, in, out, rd, wr, o_ready_rd_l0_array, reset, o_ready_wr_bank_lo);

  parameter row  = 8;
  parameter bw = 4;

  input  clk;
  input  wr;
  input  rd;
  input  reset;
  input  [row*bw-1:0] in;
  output [row*bw-1:0] out;
  output o_ready_rd_l0_array;
  output o_ready_wr_bank_lo;

  wire [row-1:0] empty;
  wire [row-1:0] full;
  reg [row-1:0] rd_en;
  
  genvar i;
  
  localparam version = 0;

  assign o_ready_wr_bank_lo = ~(|full) ;    // atleast 1 vector ready to be written
  assign o_ready_rd_l0_array  = ~(|empty) ; // atleast 1 vector ready to be read


  for (i=0; i<row ; i=i+1) begin : row_num
      fifo_depth64 #(.bw(bw)) fifo_instance (
	 .rd_clk(clk),
	 .wr_clk(clk),
	 .rd(rd_en[i]),
	 .wr(wr),
     .o_empty(empty[i]),
     .o_full(full[i]),
	 .in(in[bw*(i+1)-1:bw*(i)]),
	 .out(out[bw*(i+1)-1:bw*(i)]),
         .reset(reset));
  end


  always @ (posedge clk) begin
   if (reset) begin
      rd_en <= 8'b00000000;
   end

      /////////////// version1: read all row at a time ////////////////
   else if (!version)
      rd_en <= {8{rd}};
      ///////////////////////////////////////////////////////



      //////////////// version2: read 1 row at a time /////////////////
   else if (version)
        rd_en <= {rd_en[row-2:0],rd};
      ///////////////////////////////////////////////////////
    end

endmodule
