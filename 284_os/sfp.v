module sfp #(
  parameter DEPTH   = 16,
  parameter DW      = 16,
  parameter ADDR    = $clog2(DEPTH),
  parameter KIJ     = 9,
  parameter COUNT   = $clog2(KIJ),
  parameter col     = 8,
  parameter psum_bw = 16
)(
  input  clk,
  input  [col-1:0] wr,
  //input  rd,
  input  reset,
  input  execution_mode,
  input  [col*psum_bw-1:0] in,
  output [col*psum_bw-1:0] out,
  output o_full,
  output o_ready,
  output o_valid,
  output reg o_valid_read_q
);

  wire [col-1:0] empty;
  wire [col-1:0] empty_next;
  wire [col-1:0] full;
  wire [col*(ADDR+1)-1:0] wptr;
  wire rd;
  reg  rd_en;
  reg  [COUNT-1:0] counter;
  reg  [COUNT-1:0] counter_q;
  reg  o_valid_q;
  wire [col*psum_bw-1:0] out_acc;
  wire o_valid_read;
  wire o_valid_next;

  assign o_ready =  ~o_full ;
  assign o_full  =  (|full) ;
  assign o_valid =  ~(|empty) ;
  assign o_valid_next = ~(|empty_next);

  genvar i;
  generate
    for (i=0; i<col ; i=i+1) begin : col_num
        sfu_ofifo_tile #(.DEPTH(DEPTH), .DW(DW), .ADDR(ADDR), .KIJ(KIJ)) sfp_instance (
	     .clk(clk),
         .reset(reset),
	     .data_in(in[(i+1)*psum_bw-1:i*psum_bw]),
	     .data_out(out_acc[(i+1)*psum_bw-1:i*psum_bw]),
	     .wr(wr[i]),
	     //.rd(rd_en),
	     .rd(o_valid_read_q),
         .full(full[i]),
         .empty(empty[i]),
         .empty_next(empty_next[i]),
	     .wptr(wptr[(i+1)*(ADDR+1)-1:i*(ADDR+1)]),
	     .counter(counter));

        assign out[(i+1)*psum_bw-1:i*psum_bw] = out_acc[(i+1)*psum_bw-1] ? 16'b0 : out_acc[(i+1)*psum_bw-1:i*psum_bw]; // relu
    end
  endgenerate

  always @ (posedge clk) begin
    if (reset) begin
      counter <= 'b0;
    end else if ((wptr[1*(ADDR+1)-2:(1-1)*(ADDR+1)] == 'b0001)) begin
      counter <= counter + 1'b1;
    end else if (~execution_mode && (counter == KIJ) && (wptr[1*(ADDR+1)-2:(1-1)*(ADDR+1)] == 'b0000)) begin
      counter <= 'b0;
    end else begin
      counter <= counter;
    end
  end
 
 // flopping counter==KIJ for 16 cycle window 
  always @ (posedge clk) begin
   if (reset) begin
      counter_q <= 'b0;
      //o_valid_q <= 'b0;
   end else      
      counter_q <= counter;
      //o_valid_q <= o_valid;
  end

  assign o_valid_read = (execution_mode) ? o_valid_next : (counter == KIJ | counter_q == KIJ) ;
 
 /* 
  assign rd = o_valid_read;

  always @ (posedge clk) begin
   if (reset) begin
      rd_en <= 0;
   end else begin     
      rd_en <= rd;
   end  
  end
 */
  
 
 // flopping o_valid_read for 16 cycle window 
  always @ (posedge clk) begin
   if (reset) begin
      o_valid_read_q <= 1'b0;
   end else begin
      o_valid_read_q <= o_valid_read;
   end
  end
  
endmodule