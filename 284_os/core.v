 module core #(
    parameter bw=4,
    parameter psum_bw = 16,
    parameter col = 8,  // considering as OC
    parameter row = 8,  // considering as IC
    parameter addr_width = 8, //
    parameter len_onij=16,
    parameter op_channel_num=8,
    parameter ip_channel_num=8,
    parameter len_knij=9
 ) (
    input                       clk,
    input                       reset,
    input                       execution_mode,      // 0 weight stationary, 1 output stationary
    input  [addr_width-1:0]     ADDR,                // addr to memory
    input                       ibank_selection,     // 0 x_bank; 1 w_bank
    input                       WEN,                 // 0 write; 1 read
    input                       CEN,                 // 0 enable memory
    input  [bw*row-1:0]         data_in,             // testbench write to memory
    output [psum_bw*col-1:0]    data_out,            // testbench read from memory
    input                       mem_load_complete,   // testbench to ctlr (memory write is done)
    output                      convolution_complete // ctlr to testbench (marking completion of execution and memory writing with o/p values)
 );

// Wire declarations
wire [1:0]           inst;                        // Instruction wire (2 bits)
wire [psum_bw*col-1:0] corelet_ctlr_data;         // 128-bit wire from corelet to controller
wire                corelet_ctlr_valid;           // Valid signal (1 bit)
wire [bw*row-1:0]   xbank_corelet_data_out;       // 32-bit wire from x_bank to corelet
wire [bw*row-1:0]   wbank_corelet_data_out;       // 32-bit wire from w_bank to corelet
wire                ctlr_corelet_l0_wr_en;        // L0 write enable (1 bit)
wire                ctlr_corelet_l0_rd_en;        // L0 read enable (1 bit)
wire                corelet_ctlr_l0_wr_ready_out; // L0 write ready signal from corelet (1 bit)
wire                corelet_ctlr_l0_rd_ready_out; // L0 read ready signal from corelet (1 bit)
wire                ctlr_corelet_bank_selector;   // Bank selector (1 bit)
wire                ctlr_corelet_ififo_wr_en;     // IFIFO write enable (1 bit)
wire                ctlr_corelet_ififo_rd_en;     // IFIFO read enable (1 bit)
wire                corelet_ctlr_ififo_wr_ready_out; // IFIFO write ready from corelet (1 bit)
wire                corelet_ctlr_ififo_rd_ready_out; // IFIFO read ready from corelet (1 bit)
wire                ctlr_corelet_weight_overwrite;  // Weight overwrite (1 bit)
wire [3:0]          ctlr_pbank_addr;              // PSUM bank address (4 bits)
wire [psum_bw*col-1:0] ctlr_pbank_data;           // 128-bit PSUM data to bank
wire                ctlr_pbank_data_valid;        // PSUM data valid signal (1 bit)
wire                ctlr_xbank_read_en_n;         // X bank read enable (active low) (1 bit)
wire [7:0]          ctlr_xbank_read_addr;         // X bank read address (8 bits)
wire                ctlr_wbank_read_en_n;         // W bank read enable (active low) (1 bit)
wire [6:0]          ctlr_wbank_read_addr;         // W bank read address (7 bits)
wire [col-1:0]      ctlr_corelet_marray_shift_psum;         // Psum out (8 bits)

// Module instantiations
 corelet #(
 ) corelet_inst0 (
    .clk                    (clk),
    .reset                  (reset),
    .inst_i                 (inst), //2 bit
    .data_o                 (corelet_ctlr_data),  // 128 bit width (col*psum_bw) from sfu
    .d_valid_o              (corelet_ctlr_valid), // vaid signal for 128 bit op from corelet sfu
    .x_bank_corelet_data_i  (xbank_corelet_data_out[bw*row-1:0]),     // 32bit bw*row to l0
    .w_bank_corelet_data_i  (wbank_corelet_data_out[bw*row-1:0]),     // 32bit bw*row to l0
    .l0_wr_en_i             (ctlr_corelet_l0_wr_en),                               // 1 bit to l0
    .l0_rd_en_i             (ctlr_corelet_l0_rd_en),                               // 1 bit to l0
    .l0_ctlr_wr_ready_o     (corelet_ctlr_l0_wr_ready_out),                    // 1 bit to l0 to determine if l0 is ready to take vector in from x/wbank
    .l0_ctlr_rd_ready_o     (corelet_ctlr_l0_rd_ready_out),                    // 1 bit to l0 to determine if l0 is ready to take vector in from x/wbank
    .bank_selector_i        (ctlr_corelet_bank_selector),                   // 1 bit signal to select b/w 0 xbank data and 1 wbank data (intended for mux inside corelet)
    .ififo_wr_en_i          (ctlr_corelet_ififo_wr_en),                     // 1 bit signal to ififo for writing to i fifo
    .ififo_rd_en_i          (ctlr_corelet_ififo_rd_en),                     // 1 bit signal to ififo for reading to mac array
    .ififo_ctlr_wr_ready_o  (corelet_ctlr_ififo_wr_ready_out),                    // 1 bit to l0 to determine if ififo is ready to take vector in from wbank
    .ififo_ctlr_rd_ready_o  (corelet_ctlr_ififo_rd_ready_out),                    // 1 bit to l0 to determine if ififo is ready to take vector in from wbank
    .weight_overwrite       (ctlr_corelet_weight_overwrite),                // 1 bit 
    .execution_mode         (execution_mode),                                // 1 bit from tb
    .shift_psum_i           (ctlr_corelet_marray_shift_psum)                 // 8 bit from ctlr
 );

 controller #(
 ) ctlr (
    .clk                                (clk),
    .reset                              (reset),
    .inst_o                             (inst),
    .psum_data_i                        (corelet_ctlr_data),                // 128 bit width (col*psum_bw)
    .psum_data_in_valid                 (corelet_ctlr_valid),               // 1 bit
    .psum_addr_out                      (ctlr_pbank_addr),                  // $clog2(len_onij) (4)
    .psum_data_o                        (ctlr_pbank_data),                  // 128 bit width (col*psum_bw)
    .psum_data_out_valid                (ctlr_pbank_data_valid),            // 1 bit
    .x_bank_read_en_n_o                 (ctlr_xbank_read_en_n),             // 1 bit
    .x_bank_read_addr_o                 (ctlr_xbank_read_addr),             // 8 bit because 144 is the depth
    .w_bank_read_en_n_o                 (ctlr_wbank_read_en_n),             // 1 bit
    .w_bank_read_addr_o                 (ctlr_wbank_read_addr),             // 7 bit because 72 is the depth
    .corelet_l0_wr_en_o                 (ctlr_corelet_l0_wr_en),            // 1 bit to corelet l0
    .corelet_l0_rd_en_o                 (ctlr_corelet_l0_rd_en),            // 1 bit to corelet l0
    .corelet_l0_wr_ready_i              (corelet_ctlr_l0_wr_ready_out),     // 1 bit from corelet l0
    .corelet_l0_rd_ready_i              (corelet_ctlr_l0_rd_ready_out),     // 1 bit from corelet l0
    .corelet_ififo_wr_ready_i           (corelet_ctlr_ififo_wr_ready_out),  // 1 bit from corelet l0
    .corelet_ififo_rd_ready_i           (corelet_ctlr_ififo_rd_ready_out),  // 1 bit from corelet l0
    .corelet_ififo_wr_en_o              (ctlr_corelet_ififo_wr_en),         // 1 bit to corelet l0
    .corelet_ififo_rd_en_o              (ctlr_corelet_ififo_rd_en),         // 1 bit to corelet l0
    .corelet_bank_selector_o            (ctlr_corelet_bank_selector),       // 1 bit signal to select b/w xbank data and wbank data (intended for mux inside corelet) 
    .corelet_weight_overwrite_o         (ctlr_corelet_weight_overwrite),    // 1 bit from ctlr to mac_array
    .execution_mode                     (execution_mode),                   // 1 bit from tb
    .convolution_complete_o             (convolution_complete),             // 1 bit from ctlr to tb
    .shift_psum_o                       (ctlr_corelet_marray_shift_psum),   // 8 bit from ctlr to corelet marray 
    .mem_load_complete_i                (mem_load_complete)                 // 1 bit from tb to ctlr as a trigger to start the controller
 );

 sram #(
     .data_width    (psum_bw*col),     // psum_width * output channel number
     .num           (len_onij)         // output feature map size
 ) psum_bank (
    .CLK                    (clk),
    .WEN                    (~ctlr_pbank_data_valid),
    .REN                    (~WEN),                           // reading directly from testbanch
    .CEN                    (CEN && ~ctlr_pbank_data_valid), // chip enable when tb reads or ctlr writes
    .D                      (ctlr_pbank_data),
    .A_R                    ({(4){WEN}} & ADDR[$clog2(len_onij)-1:0]),    // addr from tb for reading purpose
    .A_W                    (ctlr_pbank_addr),
    .Q                      (data_out[psum_bw*col-1:0])
 );

  sram #(
     .data_width    (bw*row),          // bw * input channel number
     .num           (256)              // for 8onij we need kijn* input channel number that is 72, for 16onij it is 144 so taking 256 
 ) x_bank (
    .CLK                    (clk),
    .WEN                    (ibank_selection || WEN),                                  // when WEN==1 no writing
    .REN                    (ctlr_xbank_read_en_n),                                    // from controller
    .CEN                    (CEN && (ibank_selection || WEN) && ctlr_xbank_read_en_n), // chip enable when tb reads or ctlr writes
    .D                      (data_in[bw*row-1:0]),                                     // data_in from tb
    .A_R                    (ctlr_xbank_read_addr),                                    // addr from ctlr for reading to l0
    .A_W                    ({(8){~WEN}} & ADDR),                                                    // addr 8 bit wide
    .Q                      (xbank_corelet_data_out[bw*row-1:0])
 );

 sram #(
     .data_width    (bw*row),          // bw * input channel number
     .num           (128)              // kijn * output channel number = 72
 ) w_bank (
    .CLK                    (clk),
    .WEN                    (~ibank_selection || WEN),                                  // when WEN==1 no writing
    .REN                    (ctlr_wbank_read_en_n),                                     // from cotroller
    .CEN                    (CEN && (~ibank_selection || WEN) && ctlr_wbank_read_en_n), // chip enable when tb reads or ctlr writes
    .D                      (data_in[bw*row-1:0]),                                      // data_in from tb
    .A_R                    (ctlr_wbank_read_addr),                                     // addr from ctlr for reading to l0
    .A_W                    ({(7){~WEN}} & ADDR[$clog2(len_knij*op_channel_num)-1:0]),                // addr 7 bit wide
    .Q                      (wbank_corelet_data_out[bw*row-1:0])
 );


 endmodule
