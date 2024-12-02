 module controller #(
parameter bw=4,
    parameter psum_bw = 16,
    parameter col = 8,  // considering as OC
    parameter row = 8,  // considering as IC
    parameter addr_width = 8, //
    parameter len_onij=16

 ) (
    input                               clk                       ,
    input                               reset                     ,
    output [1:0]                        inst_o                    ,
    input  [127:0]                      psum_data_i               ,
    input                               psum_data_in_valid        ,
    output  [$clog2(len_onij)-1:0]      psum_addr_out             ,
    output  [127:0]                     psum_data_o               ,
    output                              psum_data_out_valid       ,
    output                              x_bank_read_en_n_o        ,
    output  [7:0]                       x_bank_read_addr_o        ,
    output                              w_bank_read_en_n_o        ,
    output  [6:0]                       w_bank_read_addr_o        ,
    output                              corelet_l0_wr_en_o        ,
    output                              corelet_l0_rd_en_o        ,
    input                               corelet_l0_wr_ready_i     ,
    input                               corelet_l0_rd_ready_i     ,
    input                               corelet_ififo_wr_ready_i  ,
    input                               corelet_ififo_rd_ready_i  ,
    output                              corelet_ififo_wr_en_o     ,
    output                              corelet_ififo_rd_en_o     ,
    output                              corelet_bank_selector_o   ,
    output                              corelet_weight_overwrite_o,
    input                               execution_mode            ,
    output                              convolution_complete_o,    
    output [col-1:0]                    shift_psum_o,    
    input                               mem_load_complete_i 
);
//TODO shift


// Wire declaration
wire [1:0]  inst_o_ws,inst_o_os;
wire        x_bank_read_en_n_o_ws,x_bank_read_en_n_o_os;
wire [7:0]  x_bank_read_addr_o_ws,x_bank_read_addr_o_os;
wire        w_bank_read_en_n_o_ws,w_bank_read_en_n_o_os;
wire [6:0]  w_bank_read_addr_o_ws,w_bank_read_addr_o_os;
wire        corelet_l0_wr_en_o_ws,corelet_l0_wr_en_o_os;
wire        corelet_l0_rd_en_o_ws,corelet_l0_rd_en_o_os;
wire        corelet_bank_selector_o_ws,corelet_weight_overwrite_o_ws;
wire [7:0]  shift_psum_os;



// Mux logic
assign inst_o                       = execution_mode?    inst_o_os               :   inst_o_ws;
assign x_bank_read_en_n_o           = execution_mode?    x_bank_read_en_n_o_os   :   x_bank_read_en_n_o_ws;
assign x_bank_read_addr_o           = execution_mode?    x_bank_read_addr_o_os   :   x_bank_read_addr_o_ws;
assign w_bank_read_en_n_o           = execution_mode?    w_bank_read_en_n_o_os   :   w_bank_read_en_n_o_ws;
assign w_bank_read_addr_o           = execution_mode?    w_bank_read_addr_o_os   :   w_bank_read_addr_o_ws;
assign corelet_l0_wr_en_o           = execution_mode?    corelet_l0_wr_en_o_os   :   corelet_l0_wr_en_o_ws;
assign corelet_l0_rd_en_o           = execution_mode?    corelet_l0_rd_en_o_os   :   corelet_l0_rd_en_o_ws;
assign corelet_bank_selector_o      = execution_mode?    1'b1                    :   corelet_bank_selector_o_ws;
assign corelet_weight_overwrite_o   = execution_mode?    1'b0                    :   corelet_weight_overwrite_o_ws;
assign shift_psum_o                 = execution_mode?    shift_psum_os           :   8'b0;

// Agnostic to MODE of EXECUTION
sfu_to_bank  #(
     .bw        (bw),
     .psum_bw   (psum_bw),
     .col       (col),  // considering as OC
     .row       (row),  // considering as IC
     .addr_width(addr_width), //
     .len_onij  (len_onij)
) sft_to_bank_inst (
  .clk                      (clk),                   
  .reset                    (reset),
  .psum_data_i              (psum_data_i),
  .psum_data_in_valid       (psum_data_in_valid),
  .psum_addr_out            (psum_addr_out),
  .psum_data_o              (psum_data_o),
  .psum_data_out_valid      (psum_data_out_valid),
  .convolution_complete_o   (convolution_complete_o)

);


// Weight Stationary FSMs // ex_mode=0
bank_to_l0_fsm  #(
     .bw        (bw),
     .psum_bw   (psum_bw),
     .col       (col),  // considering as OC
     .row       (row),  // considering as IC
     .addr_width(addr_width), //
     .len_onij  (len_onij)
) bank_to_l0_fsm_instance(
   .clk                     (clk),                  
   .reset                   (reset),
   .mem_load_complete_i     (mem_load_complete_i),
   .corelet_l0_wr_ready_i   (corelet_l0_wr_ready_i),
   .w_bank_read_en_n_o_q    (w_bank_read_en_n_o_ws),
   .w_bank_read_addr_o_qq   (w_bank_read_addr_o_ws),
   .x_bank_read_en_n_o_q    (x_bank_read_en_n_o_ws),
   .x_bank_read_addr_o_q    (x_bank_read_addr_o_ws),
   .corelet_l0_wr_en_o_q    (corelet_l0_wr_en_o_ws),
   .corelet_bank_selector_o (corelet_bank_selector_o_ws)
);


l0_to_array_fsm  #(
     .bw        (bw),
     .psum_bw   (psum_bw),
     .col       (col),  // considering as OC
     .row       (row),  // considering as IC
     .addr_width(addr_width), //
     .len_onij  (len_onij)
) l0_to_array_fsm_instance(
   .clk                       (clk),                       
   .reset                     (reset),
   .corelet_l0_rd_ready_i     (corelet_l0_rd_ready_i),
   .inst_o_q                  (inst_o_ws),
   .corelet_l0_rd_en_o_qq     (corelet_l0_rd_en_o_ws),
   .corelet_weight_overwrite_o(corelet_weight_overwrite_o_ws)

);



// Output Stationary FSMs //ex_mode=1
os_bank_to_fifo  #(
     .bw        (bw),
     .psum_bw   (psum_bw),
     .col       (col),  // considering as OC
     .row       (row),  // considering as IC
     .addr_width(addr_width), //
     .len_onij  (len_onij)
) os_bank_to_fifo_instance(
  .clk                      (clk),                     
  .reset                    (reset),
  .corelet_l0_wr_ready_i    (corelet_l0_wr_ready_i),
  .corelet_ififo_wr_ready_i (corelet_ififo_wr_ready_i),
  .mem_load_complete_i      (mem_load_complete_i),
  .w_bank_read_en_n_o_q     (w_bank_read_en_n_o_os),   
  .w_bank_read_addr_o_qq    (w_bank_read_addr_o_os),  
  .x_bank_read_en_n_o_q     (x_bank_read_en_n_o_os),   
  .x_bank_read_addr_o_qq    (x_bank_read_addr_o_os),  
  .corelet_l0_wr_en_o_q     (corelet_l0_wr_en_o_os), 
  .corelet_ififo_wr_en_o_q  (corelet_ififo_wr_en_o)

  );


os_fifo_to_array_fsm  #(
     .bw        (bw),
     .psum_bw   (psum_bw),
     .col       (col),  // considering as OC
     .row       (row),  // considering as IC
     .addr_width(addr_width), //
     .len_onij  (len_onij)
) os_fifo_to_array_fsm_instance(
   .clk                      (clk),                      
   .reset                    (reset),
   .corelet_l0_rd_ready_i    (corelet_l0_rd_ready_i),
   .corelet_ififo_rd_ready_i (corelet_ififo_rd_ready_i),
   .inst_o_q                 (inst_o_os),
   .shift_psum               (shift_psum_os),
   .corelet_l0_rd_en_o_qq    (corelet_l0_rd_en_o_os),
   .corelet_ififo_rd_en_o_qq (corelet_ififo_rd_en_o)

);




endmodule
