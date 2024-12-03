// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
`timescale 1us/1ps

module core_tb;

parameter bw = 4;
parameter psum_bw = 16;
parameter len_kij = 9;
parameter len_onij = 16;
parameter col = 8;
parameter row = 8;
parameter len_nij = 36;
parameter addr_width = 8;

reg clk = 0;
reg reset = 1;
reg execution_mode = 0; // 0 weight stationary, 1 output stationary
reg mem_load_complete = 0; // testbench to ctlr (memory write is done)
reg [bw*row-1:0] D_mem;
reg [bw*row-1:0] D_mem_q = 0;
reg CEN_mem = 1;
reg CEN_mem_q = 1;
reg WEN_mem = 1;
reg WEN_mem_q = 1;
reg [addr_width-1:0] A_mem = 0;
reg [addr_width-1:0] A_mem_q = 0;
reg ibank_selection = 0; // 0 x_bank; 1 w_bank
reg ibank_selection_q = 0;
reg [8*30:1] w_file_name;

wire convolution_complete; // ctlr to testbench (marking completion of execution and memory writing with o/p values)
wire [psum_bw*col-1:0] sfp_out;
reg [psum_bw*col-1:0] answer;

integer x_file, x_scan_file ; // file_handler
integer w_file, w_scan_file ; // file_handler
integer out_file, out_scan_file ; // file_handler
integer captured_data; 
integer t, i, j, k, l, kij;
integer error;
`define NULL 0

core  #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(row), .addr_width(addr_width), .len_onij(len_onij)) core_instance (
	.clk(clk), 
	.reset(reset),
	.ADDR(A_mem_q),
	.ibank_selection(ibank_selection_q),
	.WEN(WEN_mem_q),
	.CEN(CEN_mem_q),
	.execution_mode(execution_mode),
	.mem_load_complete(mem_load_complete),
        .data_in(D_mem_q), 
        //.data_in(data_in), 
        .data_out(sfp_out), 
        //.data_out(data_out), 
	.convolution_complete(convolution_complete)); 

/*
core  #(.bw(bw), .col(col), .row(row)) core_instance (
	.clk(clk), 
	.inst(inst_q),
	.ofifo_valid(ofifo_valid),
        .D_xmem(D_xmem_q), 
        .sfp_out(sfp_out), 
	.reset(reset)); 
*/

initial begin 

  D_mem   = 0;
  CEN_mem = 1;
  WEN_mem = 1;
  A_mem   = 0;
  mem_load_complete = 0;

  $dumpfile("core_tb.vcd");
  $dumpvars(0,core_tb);

  x_file = $fopen("activation_tile0.txt", "r");
  if (x_file == `NULL) begin
    $display("x_file handle was NULL");
    $finish;
  end
  // Following three lines are to remove the first three comment lines of the file
  x_scan_file = $fscanf(x_file,"%s", captured_data);
  x_scan_file = $fscanf(x_file,"%s", captured_data);
  x_scan_file = $fscanf(x_file,"%s", captured_data);

  //////// Reset /////////
  #0.5 clk = 1'b0;   reset = 1;
  #0.5 clk = 1'b1; 

  for (i=0; i<10 ; i=i+1) begin
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;  
  end

  #0.5 clk = 1'b0;   reset = 0;
  #0.5 clk = 1'b1; 

  #0.5 clk = 1'b0;
  #0.5 clk = 1'b1;   
  /////////////////////////

  /////// Activation data writing to memory ///////

  #0.5 clk = 1'b0;  x_scan_file = $fscanf(x_file,"%32b", D_mem); WEN_mem = 0; ibank_selection = 0; CEN_mem = 0; 
  #0.5 clk = 1'b1;   

  while(!$feof(x_file)) begin  
    #0.5 clk = 1'b0;  x_scan_file = $fscanf(x_file,"%32b", D_mem); WEN_mem = 0; ibank_selection = 0; CEN_mem = 0; A_mem = A_mem + 1;
    #0.5 clk = 1'b1;   
  end


/*
  for (t=0; t<len_nij; t=t+1) begin  
    #0.5 clk = 1'b0;  x_scan_file = $fscanf(x_file,"%32b", D_xmem); WEN_xmem = 0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1;
    #0.5 clk = 1'b1;   
  end
*/

  #0.5 clk = 1'b0;  WEN_mem = 1;  CEN_mem = 1; A_mem = 0;
  #0.5 clk = 1'b1; 

  $fclose(x_file);
  /////////////////////////////////////////////////


  for (kij=0; kij<9; kij=kij+1) begin  // kij loop

    case(kij)
     0: w_file_name = "weight_itile0_otile0_kij0.txt";
     1: w_file_name = "weight_itile0_otile0_kij1.txt";
     2: w_file_name = "weight_itile0_otile0_kij2.txt";
     3: w_file_name = "weight_itile0_otile0_kij3.txt";
     4: w_file_name = "weight_itile0_otile0_kij4.txt";
     5: w_file_name = "weight_itile0_otile0_kij5.txt";
     6: w_file_name = "weight_itile0_otile0_kij6.txt";
     7: w_file_name = "weight_itile0_otile0_kij7.txt";
     8: w_file_name = "weight_itile0_otile0_kij8.txt";
    endcase

    if (w_file_name == `NULL) begin
     $display("w_file_name handle was NULL");
     $finish;
    end
    

    w_file = $fopen(w_file_name, "r");
    // Following three lines are to remove the first three comment lines of the file
    w_scan_file = $fscanf(w_file,"%s", captured_data);
    w_scan_file = $fscanf(w_file,"%s", captured_data);

    #0.5 clk = 1'b0;   reset = 1;
    #0.5 clk = 1'b1; 

    for (i=0; i<10 ; i=i+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;  
    end

    #0.5 clk = 1'b0;   reset = 0;
    #0.5 clk = 1'b1; 

    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   





    /////// Kernel data writing to memory ///////

if (kij == 0) begin
        #0.5 clk = 1'b0;  w_scan_file = $fscanf(w_file,"%32b", D_mem); WEN_mem = 0; ibank_selection = 1; CEN_mem = 0;
        #0.5 clk = 1'b1; 
    end


    while(!$feof(w_file)) begin  
      #0.5 clk = 1'b0;  w_scan_file = $fscanf(w_file,"%32b", D_mem); WEN_mem = 0; ibank_selection = 1; CEN_mem = 0; A_mem = A_mem + 1;
      #0.5 clk = 1'b1;   
    end

/*
    A_xmem = 11'b10000000000;
    for (t=0; t<col; t=t+1) begin  
      #0.5 clk = 1'b0;  w_scan_file = $fscanf(w_file,"%32b", D_xmem); WEN_xmem = 0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1; 
      #0.5 clk = 1'b1;  
    end
*/

    #0.5 clk = 1'b0;  //WEN_mem = 1;  ibank_selection = 0; CEN_mem = 1;
    #0.5 clk = 1'b1; 
    /////////////////////////////////////


/*

    /////// Kernel data writing to L0 ///////
    ...
    /////////////////////////////////////



    /////// Kernel loading to PEs ///////
    ...
    /////////////////////////////////////
  


    ////// provide some intermission to clear up the kernel loading ///
    #0.5 clk = 1'b0;  load = 0; l0_rd = 0;
    #0.5 clk = 1'b1;  
  

    for (i=0; i<10 ; i=i+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;  
    end
    /////////////////////////////////////



    /////// Activation data writing to L0 ///////
    ...
    /////////////////////////////////////



    /////// Execution ///////
    ...
    /////////////////////////////////////



    //////// OFIFO READ ////////
    // Ideally, OFIFO should be read while execution, but we have enough ofifo
    // depth so we can fetch out after execution.
    ...
    /////////////////////////////////////

*/
  end  // end of kij loop

    #0.5 clk = 1'b0;  WEN_mem = 1;  ibank_selection = 0; CEN_mem = 1; A_mem = 0; mem_load_complete = 1;
    //#0.5 clk = 1'b1; 



  //////////////////////////////////

  //for (t=0; t<10; t=t+1) begin  
  //  #0.5 clk = 1'b0;  
  //  #0.5 clk = 1'b1;  
  //end

  #1000 $finish;

end


always @(posedge convolution_complete) begin
  ////////// Accumulation /////////
  out_file = $fopen("out.txt", "r");  
  if (out_file == `NULL) begin
   $display("out_file handle was NULL");
   $finish;
  end
  // Following three lines are to remove the first three comment lines of the file
  out_scan_file = $fscanf(out_file,"%s", answer); 
  out_scan_file = $fscanf(out_file,"%s", answer); 
  out_scan_file = $fscanf(out_file,"%s", answer); 

  error = 0;

  //if (convolution_complete) begin

  $display("############ Verification Start during accumulation #############"); 
  l = 0;

  #0.5 clk = 1'b0; 
  #0.5 clk = 1'b1; 

  //for (i=0; i<len_onij+1; i=i+1) begin 
  while(!$feof(out_file)) begin

    l = l + 1;

    //#0.5 clk = 1'b0; 
    //#0.5 clk = 1'b1; 

    //if (i>0) begin
     out_scan_file = $fscanf(out_file,"%128b", answer); // reading from out file to answer

       #0.5 clk = 1'b0;  WEN_mem = 1; CEN_mem = 0; if (l > 1) A_mem = A_mem + 1;
       #0.5 clk = 1'b1;

       // how long to wait?

       if (sfp_out == answer)
         $display("%2d-th output featuremap Data matched! :D", l); 
       else begin
         $display("%2d-th output featuremap Data ERROR!!", l); 
         $display("sfpout: %128b", sfp_out);
         $display("answer: %128b", answer);
         error = 1;
       end
    //end
  
/*
    #0.5 clk = 1'b0; reset = 1;
    #0.5 clk = 1'b1;  
    #0.5 clk = 1'b0; reset = 0; 
    #0.5 clk = 1'b1;  

    for (j=0; j<len_kij+1; j=j+1) begin 

      #0.5 clk = 1'b0;   
        if (j<len_kij) begin CEN_pmem = 0; WEN_pmem = 1; acc_scan_file = $fscanf(acc_file,"%11b", A_pmem); end
                       else  begin CEN_pmem = 1; WEN_pmem = 1; end

        if (j>0)  acc = 1;  
      #0.5 clk = 1'b1;   
    end

    #0.5 clk = 1'b0; acc = 0;
    #0.5 clk = 1'b1;
*/ 
  end

  #0.5 clk = 1'b0;  WEN_mem = 0; CEN_mem = 1; A_mem = 0;
  #0.5 clk = 1'b1;  



  if (error == 0) begin
  	$display("############ No error detected ##############"); 
  	$display("########### Project Completed !! ############"); 

  end
//end
  $fclose(out_file);
end
always @(posedge mem_load_complete) begin
    forever begin
      # (0.5) clk = ~clk;
    end
  end
  
always @(posedge mem_load_complete) begin
    #0.5 reset = 1'b1;
    #2.5 reset = 1'b0;   
  end

always @ (posedge clk) begin
   D_mem_q   <= D_mem;
   CEN_mem_q <= CEN_mem;
   WEN_mem_q <= WEN_mem;
   A_mem_q   <= A_mem;
   ibank_selection_q   <= ibank_selection;
end


endmodule
