module mac_tile (valid,flush, format,clk, out_s, in_w, out_e, in_n, inst_w, inst_e, reset,overwrite);  //FORMAT = 1 for WEIGHT STATIONARY

parameter bw = 4;
parameter psum_bw = 16;

output reg valid;
output [psum_bw-1:0] out_s;
input  [bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
output [bw-1:0] out_e;
input  [1:0] inst_w;  //inst_w[0] -> compute and inst_w[1] -> pass psum for output stationary
output [1:0] inst_e;
input  [psum_bw-1:0] in_n; 
input  clk;
input  reset;
input  format;
input  overwrite;
input flush;
// Wire & Reg declaration   
wire [psum_bw-1:0] mac_out;
wire               act_reg_enable;
wire               w_reg_enable;
wire               psum_reg_enable;
wire               load_status;
wire               inst_reg0_enable;
reg                load_ready;
reg [bw -1:0]      a_q,b_q;
reg [psum_bw-1:0]  c_q;
//reg [psum_bw-1:0]  psum_q;  //for storing current psum in op st.
reg [1:0]          inst_q;

// Assign Statements
assign inst_e          = inst_q;
assign out_e           = a_q;
//TODO assign out_s           = format ? mac_out : (flush ? psum_q : {{12{b_q[3]}}, b_q});  //out_s gets psum in wt. stationary, sign_ext. weight or psum_q based on inst
assign out_s           = format ? mac_out : (flush ? c_q : {{12{1'b0}}, b_q});  //out_s gets psum in wt. stationary, sign_ext. weight or psum_q based on inst
assign load_status     = inst_w[0] && load_ready; //kernel ready to load for that PE
assign act_reg_enable  = format ? |inst_w : inst_w[0];               //a_q should latch input from west for both the instructions and in op st. only when inst -> compute
assign w_reg_enable    = format ? inst_w[0] && load_ready : inst_w[0]; //b_q should capture the input west only when load_ready is 1
//TODO assign psum_reg_enable = format ? inst_w[1] : inst_w[0];             //for execution
assign inst_reg0_enable = ~load_ready;           //when load ready is 0 capture instruction should go to the next PE

// psum initially zero 
    always @ (posedge clk) begin
	if (reset)
	    c_q <= 0;          //initial condition 
    if (format) begin
        if (inst_w[1])
            c_q <= in_n;
    end
	else if (!format) begin
	   if (inst_w[0])
	    c_q <= mac_out;     //updating psum with current sum in case of op st.
       else if(flush)
        c_q <= in_n;
		  
    end
    end
// Load Ready Register assign valid[i - 1] = inst_temp[2*(i+1)-1]; //assign valid as inst_e
    always @ (posedge clk) begin
        if (reset || overwrite)
            load_ready <= 1'b1;
        else if (load_status)        // latched the weight in the b_q now make load_ready as 0 again
            load_ready <= 1'b0;
    end

// Activation Register
    always @ (posedge clk) begin
        if (reset)
            a_q <= 'b0;
        else if (act_reg_enable)    
            a_q <= in_w;
    end

// Weight Register
    always @ (posedge clk) begin
        if (reset)
            b_q <= 'b0;
        else if (w_reg_enable)
            b_q <= format ? in_w : in_n[3:0];  // weight is passed as first 4 bits of in_n
    end

//TODO Psum Register
//    always @ (posedge clk) begin
//        if (reset)
//            c_q <= 'b0;
//        else if (psum_reg_enable)
//            c_q <= in_n ;  
//    end
	 
// valid should be high on flush signal.
    always @ (posedge clk) begin
        if (reset)
            valid <= 'b0;
        else 
            valid <= flush;  
    end

// Instruction Register   
    always @ (posedge clk) begin
        if (reset)
            inst_q <= 2'b0;
        else if (format) begin
        
          inst_q[1] <= inst_w[1];
          if(inst_reg0_enable)
          begin 
            inst_q[0] <= inst_w[0];
          end
          end
          
        else if (!format)  
          inst_q <= inst_w;
    end
mac #(.bw(bw), .psum_bw(psum_bw)) mac_instance (
        .a(a_q), 
        .b(b_q),
        .c(c_q),
	.out(mac_out)
); 

endmodule
