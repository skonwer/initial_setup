module sfu_ofifo_tile #(
    parameter DEPTH = 16,
    parameter DW    = 16,
    parameter ADDR  = $clog2(DEPTH),
    parameter KIJ   = 9
) (
    input clk,
    input reset,
    input [DW-1:0] data_in,
    output [DW-1:0] data_out,
    input wr,
    input rd,
    output full,
    output empty,
    output empty_next,
    output reg [ADDR:0] wptr,
    input [$clog2(KIJ)-1:0] counter
);

reg [DW-1:0] fifo [DEPTH-1:0];
reg [ADDR:0] rptr;
reg full_once;

//assignment
assign full  = ((wptr[ADDR-1:0] == rptr[ADDR-1:0]) && (wptr[ADDR] != rptr[ADDR]));
assign empty = ((wptr[ADDR-1:0] == rptr[ADDR-1:0]) && (wptr[ADDR] == rptr[ADDR]));
assign empty_next = (wptr[ADDR:0] == rptr[ADDR:0]+1) | empty;

// write
always @ (posedge clk) begin
    if (reset)
        wptr       <= 'b0;
    else if (wr && (~(full|full_once))) begin
        wptr       <= wptr + 1'b1;
        fifo[wptr[ADDR-1:0]] <= data_in;
    end else if (wr) begin
        wptr       <= wptr + 1'b1;
        fifo[wptr[ADDR-1:0]] <= $signed(data_in) + $signed(fifo[wptr[ADDR-1:0]]);
    end
end

always @ (posedge clk) begin
    if (reset)
        full_once       <= 1'b0;
    else if (full) begin
        full_once       <= 1'b1 ;
    end else begin
        full_once       <= full_once;
    end
end

//read
always @ (posedge clk) begin
    if (reset)
        rptr       <= 'b0;
    //else if (rd && !empty) begin
    else if (rd) begin
        rptr       <= rptr + 1'b1;
    end
end

assign data_out = fifo[rptr[ADDR-1:0]];

endmodule