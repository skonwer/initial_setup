module bank_to_l0_fsm #(
    parameter bw=4,
    parameter psum_bw = 16,
    parameter col = 8,  // considering as OC
    parameter row = 8,  // considering as IC
    parameter addr_width = 8, //
    parameter len_onij=16
) (
    input               clk,
    input               reset,
    input               mem_load_complete_i,
    input               corelet_l0_wr_ready_i,
    output reg          w_bank_read_en_n_o_q,                             // negedge active low
    output reg [6:0]    w_bank_read_addr_o_qq,                             //  7 bit because 72 is the depth
    output reg          x_bank_read_en_n_o_q,                             // negedge active low
    output reg [7:0]    x_bank_read_addr_o_q,                             //  8 bit because 144 is the depth
    output reg          corelet_l0_wr_en_o_q,
    output              corelet_bank_selector_o
);


localparam RESET = 3'b000;
localparam S0    = 3'b001;
localparam S1    = 3'b011;
localparam S2    = 3'b010;
localparam S3    = 3'b110;


reg [2:0]       nstate,pstate;
reg [4:0]       wcounter, wcounter_q;
reg [5:0]       xcounter, xcounter_q;
reg [3:0]       kij_counter_q;
reg             kij_counter_en, kij_counter_en_q;
reg [1:0]       delay_counter,delay_counter_q;
reg [6:0]       w_bank_read_addr_o, w_bank_read_addr_o_q;
reg [7:0]       x_bank_read_addr_o;
reg             corelet_l0_wr_en_o, w_bank_read_en_n_o, x_bank_read_en_n_o;


reg [3:0] LUT [8:0];


assign corelet_bank_selector_o = (pstate==S0 || pstate==S1)? 1'b0 : 1'b1;

always @(reset) begin
    LUT[0] <= 4'b0000; //0
    LUT[1] <= 4'b0001; //1
    LUT[2] <= 4'b0010; //2
    LUT[3] <= 4'b0110; //6
    LUT[4] <= 4'b0111; //7
    LUT[5] <= 4'b1000; //8
    LUT[6] <= 4'b1100; //12
    LUT[7] <= 4'b1101; //13
    LUT[8] <= 4'b1110; //14
end

always @(posedge clk) begin
    if (reset) begin
        wcounter_q           <= 4'b0;
        xcounter_q           <= 5'b0;
        w_bank_read_addr_o_q <= 7'b0;
        w_bank_read_addr_o_qq <= 7'b0;
        w_bank_read_en_n_o_q <= 1'b1;
        x_bank_read_addr_o_q <= 8'b0;
        x_bank_read_en_n_o_q <= 1'b1;
        corelet_l0_wr_en_o_q <= 1'b0;
        delay_counter_q      <= 2'b0;
        kij_counter_en_q     <= 1'b0;
    end
    else begin
        wcounter_q <= wcounter;
        xcounter_q <= xcounter;
        w_bank_read_addr_o_q <= w_bank_read_addr_o;
        w_bank_read_addr_o_qq <= w_bank_read_addr_o_q;
        w_bank_read_en_n_o_q <= w_bank_read_en_n_o;
        x_bank_read_addr_o_q <= x_bank_read_addr_o;
        x_bank_read_en_n_o_q <= x_bank_read_en_n_o;
        corelet_l0_wr_en_o_q <= corelet_l0_wr_en_o;
        delay_counter_q      <= delay_counter;
        kij_counter_en_q     <= kij_counter_en;
    end
end

always @(posedge clk) begin
    if (reset)
        kij_counter_q        <= 4'b0;
    else if (kij_counter_en && ~kij_counter_en_q)
        kij_counter_q        <= kij_counter_q + 1;
end

always @(posedge clk) begin
    if (reset) 
        pstate <= 3'b0;
    else 
        pstate <= nstate;
end



always @(*) begin
    w_bank_read_en_n_o = 1'b1;
    w_bank_read_addr_o = 'b0;
    x_bank_read_en_n_o = 1'b1;
    x_bank_read_addr_o = 'b0;
    corelet_l0_wr_en_o = 1'b0;
    wcounter           = 1'b0;
    xcounter           = 1'b0;
    delay_counter      = 1'b0;
    kij_counter_en        = 1'b0;

    case (pstate) 
        RESET: begin
            if(mem_load_complete_i && kij_counter_q!=9) nstate = S0;
            else                    nstate = RESET;
        end
        
        S0: begin
            
            corelet_l0_wr_en_o = ~w_bank_read_en_n_o_q;
            if(corelet_l0_wr_ready_i && (wcounter_q[3]!=1'b1))   begin         // counter != 8
                w_bank_read_en_n_o = 1'b0;
                w_bank_read_addr_o = w_bank_read_addr_o_q + 1;
                wcounter           = wcounter_q + 1;
            end
            else if ((wcounter_q[3]==1'b1)) begin
                kij_counter_en     = 1'b1;
                nstate             = S1;
              //  wcounter           = 'b0;
            end
        end

        S1: begin
            if (delay_counter_q!=2) 
                delay_counter = delay_counter_q + 1;
            else  begin
                nstate = S2;
           //     delay_counter = 'b0;
            end
        end
        
        S2: begin
           corelet_l0_wr_en_o = ~x_bank_read_en_n_o_q;
            if(corelet_l0_wr_ready_i && (xcounter_q[4]!=1'b1))   begin         // counter != 16
                x_bank_read_en_n_o = 1'b0;
                x_bank_read_addr_o = LUT[kij_counter_q[3:0]-1] + xcounter_q[1:0] + 6*xcounter_q[3:2];
                xcounter           = xcounter_q + 1;
            end
            else if ((xcounter_q[4]==1'b1)) begin
                nstate             = S3;
           //     xcounter           = 'b0;
            end
        end

        S3: begin
            if (kij_counter_q == 9)
                nstate             = RESET;
            else if (delay_counter_q!=2) 
                delay_counter = delay_counter_q + 1;
            else begin
                nstate              = S0;
           //      delay_counter = 'b0;
            end
        end


    endcase
end

endmodule
