// Code your design here
module mac_array (flush, clk, reset,format, out_s, in_w, in_n, inst_w, valid,overwrite);   //in_w_n for passing weight north to south 
 parameter bw = 4;
 parameter psum_bw = 16;
 parameter col = 8;
 parameter row = 8;

 input clk, reset;
 output [psum_bw*col-1:0] out_s;
 input [row*bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
 input [1:0] inst_w;
 input [psum_bw*col-1:0] in_n;
 input format;
 output [col-1:0] valid;
 input overwrite;
 input [col-1:0] flush;

 // wire & reg
 reg [2*row-1:0] inst_w_temp;
 wire [psum_bw*col*(row+1)-1:0] temp;
 wire [row*col-1:0] valid_temp;
 
 // Assignments
 assign out_s = temp[psum_bw*col*(row+1)-1:psum_bw*col*row];
 assign temp[psum_bw*col*1-1:psum_bw*col*0] = in_n;          //instead of making zero kept as in_n 
 assign valid = valid_temp[row*col-1:row*col-8];

// // Generate block  
 genvar i;
 generate
 for (i = 1; i <= row; i = i + 1) begin : gen_r
    mac_row #(.bw(bw), .psum_bw(psum_bw) ) mac_row_instance (
        .clk(clk),
        .reset(reset),
        .in_w(in_w[i*bw-1:(i-1)*bw]),
        .inst_w(inst_w_temp[2*i-1:2*(i-1)]),
        .in_n(temp[psum_bw*col*i-1:psum_bw*col*(i-1)]),
        .valid(valid_temp[col*i-1:col*(i-1)]),
        .out_s(temp[psum_bw*col*(i+1)-1:psum_bw*col*i]),
        .format(format),
        .overwrite(overwrite),
        .flush(flush)

    );
 end
 endgenerate

 always @(posedge clk or posedge reset) begin
    if (reset) 
        inst_w_temp <= 0;
    else begin
        inst_w_temp[1:0]   <= inst_w; 
        inst_w_temp[3:2]   <= inst_w_temp[1:0];
        inst_w_temp[5:4]   <= inst_w_temp[3:2];
        inst_w_temp[7:6]   <= inst_w_temp[5:4];
        inst_w_temp[9:8]   <= inst_w_temp[7:6];
        inst_w_temp[11:10] <= inst_w_temp[9:8];
        inst_w_temp[13:12] <= inst_w_temp[11:10];
        inst_w_temp[15:14] <= inst_w_temp[13:12];
    end
 end

endmodule

