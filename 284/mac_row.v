module mac_row (flush,format,clk, out_s, in_w, in_n, valid, inst_w, reset, overwrite);

    parameter bw = 4;
    parameter psum_bw = 16;
    parameter col = 8;
  
    input clk, reset;
    output [psum_bw*col-1:0] out_s;
    output [col-1:0] valid;
    input [bw-1:0] in_w; 
    input [1:0] inst_w;  // inst[1]:execute, inst[0]: kernel loading
    input [psum_bw*col-1:0] in_n;
    input format;
    input overwrite;
    input [col-1:0] flush;
    
    wire [(col+1)*bw-1:0] temp;
    wire [(col+1)*2-1:0]  inst_temp;
    wire [psum_bw-1:0] in_n_temp;
	wire [7:0] valid_t;
    //wire [psum_bw-1:0] out_s_temp;
  genvar i;
  assign temp[bw-1:0]   = in_w; // Connect in_w to the first section of temp
  assign inst_temp[1:0] = inst_w; // Connect inst_w to the first section of temp
  
  generate
    for (i = 1; i < col+1; i = i+1) begin : col_num
		  assign valid[i - 1] = format ? inst_temp[2*(i+1)-1] : valid_t[i-1]; //assign valid as inst_e or 1 in case of flush
          mac_tile #(.bw(bw), .psum_bw(psum_bw)) mac_tile_instance (
            .clk(clk),
            .reset(reset),
            .in_w(temp[bw*i-1:bw*(i-1)]), // Pass input weight for the column
            .out_e(temp[bw*(i+1)-1:bw*i]), // Connect output east of the current tile to input of the next
            .inst_w(inst_temp[2*i-1:2*(i-1)]),
            .inst_e(inst_temp[2*(i+1)-1:2*i]),
            .in_n(format ? in_n[psum_bw*i-1:psum_bw*(i-1)] : {{12{in_n[psum_bw*(i-1)+4-1]}}, in_n[psum_bw*(i-1)+4-1:psum_bw*(i-1)]}),	
            .out_s(out_s[psum_bw*i-1:psum_bw*(i-1)]),
            .format(format), // Generate output psum for the column and pass weight in case of op st.
            .overwrite(overwrite),
            .flush(flush[i-1]),
			.valid(valid_t[i-1])
        );
       
    end
  endgenerate  
endmodule
