module corelet #(
    parameter bw=4,
    parameter psum_bw = 16,
    parameter col = 8,  // considering as OC
    parameter row = 8,  // considering as IC
    parameter addr_width = 8, //
    parameter len_onij=16
) (
    
    input                               clk,                  
    input                               reset,
    input                               execution_mode,
    input [1:0]                         inst_i,               
    output reg [col*psum_bw-1:0]        data_o,               
    output                              d_valid_o,            
    input  [bw*row-1:0]                 x_bank_corelet_data_i,
    input  [bw*row-1:0]                 w_bank_corelet_data_i,
    input                               l0_wr_en_i,           
    input                               l0_rd_en_i,           
    output                              l0_ctlr_wr_ready_o,           
    output                              l0_ctlr_rd_ready_o,           
    input                               bank_selector_i,      
    input                               ififo_wr_en_i,        
    input                               ififo_rd_en_i,        
    output                              ififo_ctlr_wr_ready_o,           
    output                              ififo_ctlr_rd_ready_o,           
    input                               weight_overwrite, 
    input  [col-1:0]                    shift_psum_i 

    );


wire [bw*row-1:0]                   lo_data_in;     
wire [bw*row-1:0]                   lo_marray_data;     
wire [bw*row-1:0]                   ififo_data_out;     
reg  [psum_bw*col-1:0]              ififo_marray_weight_in;
wire [psum_bw*col-1:0]              marray_sfu_psum_out;
reg  [psum_bw*col-1:0]              marray_sfu_psum_out_sfp;
wire [psum_bw*col-1:0]              data_o_sfp;
wire [col-1:0]                      marray_sfu_psum_valid;
reg  [col-1:0]                      marray_sfu_psum_valid_sfp;


assign lo_data_in       = bank_selector_i ? x_bank_corelet_data_i : w_bank_corelet_data_i;  // l0datain  takes in x&w bank in weight stationary
//assign ififo_marray_weight_in   = execution_mode  ? {((psum_bw-bw)*col){ififo_data_out[bw]},ififo_data_out}:{(psum_bw*col){1'b0}}; // when emode0(wgtstat); else (outstat) // taking care of sign extention for emode 1 as weights may be negative

integer i;
always @(*) begin
for (i=0; i<col; i=i+1) begin
     ififo_marray_weight_in[psum_bw*(i)+:psum_bw] = execution_mode ? {{(psum_bw-bw){1'b0}}, ififo_data_out[bw*(i)+:bw]} : {(psum_bw){1'b0}};
    //ififo_marray_weight_in[psum_bw*(i)+:psum_bw]    = execution_mode ? ({(psum_bw-bw){1'b0]},ififo_data_out[bw*i:bw]}):({(psum_bw){1'b0}});
     marray_sfu_psum_out_sfp[psum_bw*(7-i)+:psum_bw] = marray_sfu_psum_out[psum_bw*(i)+:psum_bw];
     marray_sfu_psum_valid_sfp[7-i]                  = marray_sfu_psum_valid[i];
     data_o[psum_bw*(7-i)+:psum_bw]                  = data_o_sfp[psum_bw*(i)+:psum_bw];
end
end


l0 #(
    .bw(bw),
    .row(row)
) l0_instance (
        .clk                    (clk),
        .in                     (lo_data_in),       // change this to receive data from SRAM(memory bank)
        .out                    (lo_marray_data),   // bw*row bits
        .rd                     (l0_rd_en_i),       // 1 bit read  en from ctlr
        .wr                     (l0_wr_en_i),       // 1 bit write en from ctlr
        .o_ready_rd_l0_array    (l0_ctlr_rd_ready_o), // 1 bit atleast 1 vector ready to be read
        .reset                  (reset), 
        .o_ready_wr_bank_lo     (l0_ctlr_wr_ready_o)        // 1 bit output ready to ctlr
    );
        
l0 #(
    .bw(bw),
    .row(col)
) ififo_instance (
        .clk                    (clk),
        .in                     (w_bank_corelet_data_i),       // change this to receive data from SRAM(memory bank)
        .out                    (ififo_data_out),   // bw*row bits
        .rd                     (execution_mode && ififo_rd_en_i),       // 1 bit read  en from ctlr
        .wr                     (execution_mode && ififo_wr_en_i),       // 1 bit write en from ctlr
        .o_ready_rd_l0_array    (ififo_ctlr_rd_ready_o), // 1 bit atleast 1 vector ready to be read
        .reset                  (reset), 
        .o_ready_wr_bank_lo     (ififo_ctlr_wr_ready_o)        // 1 bit output ready to ctlr
    );
    

sfp #(
    .psum_bw    (psum_bw),
    .col        (col)
) sfu_instance (
    .clk            (clk),
    .reset          (reset),
    .in             (marray_sfu_psum_out_sfp),   // psum_bw*col bit
    .out            (data_o_sfp),
    .execution_mode (execution_mode),
    .wr             (marray_sfu_psum_valid_sfp), // valid from marray drives the write enable
    .o_valid_read_q (d_valid_o)              // data_valid from sfu to psum bank via controller
);


mac_array #(
    .bw(bw),
    .psum_bw(psum_bw),
    .col(col),
    .row(row)
) mac_array_instance (
   .clk                     (clk),
   .reset                   (reset),
   .out_s                   (marray_sfu_psum_out),          // psum_bw*col bit
   .in_w                    (lo_marray_data),               // bw*row bit
   .in_n                    (ififo_marray_weight_in),       // psum_bw*col bit
   .inst_w                  (inst_i),                       // 2 bit from ctlr
   .valid                   (marray_sfu_psum_valid),        // o/p valid from marray drives the write enable of SFU fifos
   .format                  (~exection_mode),               // i/p format 0> o/p stat; format 1> wgt stat opposite of execution mode
   .overwrite               (weight_overwrite),
   .flush                   (shift_psum_i)
);


endmodule
