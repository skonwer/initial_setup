module l0_to_array_fsm #(
    parameter bw=4,
    parameter psum_bw = 16,
    parameter col = 8,  // considering as OC
    parameter row = 8,  // considering as IC
    parameter addr_width = 8, //
    parameter len_onij=16
) (
    input                   clk,
    input                   reset,
    input                   corelet_l0_rd_ready_i,
    output  reg [1:0]       inst_o_q,
    output  reg             corelet_l0_rd_en_o_qq,
    output  reg             corelet_weight_overwrite_o


);


localparam IDLE  = 3'b100;
localparam S0    = 3'b001;
localparam S1    = 3'b011;
localparam S2    = 3'b111;
localparam S3    = 3'b110;



reg [2:0] nstate, pstate;
reg inst_o, corelet_l0_rd_en_o;
reg [4:0]       wcounter, wcounter_q;
reg [5:0]       xcounter, xcounter_q;
reg [3:0]       kij_counter_q;
reg             kij_counter_en, kij_counter_en_q, corelet_l0_rd_en_o_q;
reg [2:0]       delay_counter,delay_counter_q;

always @(posedge clk) begin
    if (reset) 
        pstate <= S0;
    else 
        pstate <= nstate;
end



always @(posedge clk) begin
    if (reset)
        kij_counter_q        <= 4'b0;
    else if (kij_counter_en)
        kij_counter_q        <= kij_counter_q + 1;
end




always @(posedge clk) begin
    if (reset) begin
        wcounter_q                      <= 4'b0;
        xcounter_q                      <= 5'b0;
        inst_o_q                        <= 2'b0;
        corelet_l0_rd_en_o_q            <= 1'b0;
        delay_counter_q                 <= 3'b0;
        kij_counter_en_q                <= 1'b0;
        corelet_l0_rd_en_o_qq           <= 1'b0;
    end
    else begin
        wcounter_q                      <= wcounter;
        xcounter_q                      <= xcounter;
        inst_o_q                        <= inst_o;
        corelet_l0_rd_en_o_q            <= corelet_l0_rd_en_o;
        corelet_l0_rd_en_o_qq           <= corelet_l0_rd_en_o_q;  // understanding is inst is published 1 cycle before weights
        delay_counter_q                 <= delay_counter;
        kij_counter_en_q                <= kij_counter_en;
    end
end


always @(*) begin
    inst_o             = 2'b0;
    corelet_l0_rd_en_o = 1'b0;
    kij_counter_en     = 1'b0;
    delay_counter      = 3'b0;
    wcounter           = 'b0;
    xcounter           = 'b0;
    corelet_weight_overwrite_o = 1'b0;
    case (pstate) 
        S0: begin
            if (corelet_l0_rd_ready_i && (wcounter_q!= 8) ) begin
                inst_o             = 2'b01;
                corelet_l0_rd_en_o = 1'b1;
                wcounter           = wcounter_q + 1;
                nstate             = S0;
            end
            else if (wcounter_q== 8) begin
                nstate = S1;
                kij_counter_en     = 1'b1;
            end
            else
                nstate             = S0;
        end
        
        S1: begin
            if (delay_counter_q!=4) 
                delay_counter = delay_counter_q + 1;
            else  begin
                nstate = S2;
            end
        end

        S2: begin
            if (corelet_l0_rd_ready_i && (xcounter_q!= 16) ) begin
                inst_o             = 2'b10;
                corelet_l0_rd_en_o = 1'b1;
                xcounter           = xcounter_q + 1;
            end
            else if (xcounter_q== 16) begin
                nstate = S3;
            end
        end

        S3: begin
            if (kij_counter_q == 9)
                nstate             = IDLE;
            else begin
                nstate              = S0;
                corelet_weight_overwrite_o = 1;
            end
        end

        IDLE: begin
                nstate = pstate;
        end
    endcase
end

endmodule
