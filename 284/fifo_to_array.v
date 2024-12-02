module os_fifo_to_array_fsm #(
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
    input                   corelet_ififo_rd_ready_i,
    output  reg [1:0]       inst_o_q,
    output  reg             corelet_l0_rd_en_o_qq,
    output  reg             corelet_ififo_rd_en_o_qq,
    output  reg [col-1:0]   shift_psum
);


localparam IDLE  = 3'b100;
localparam S0    = 3'b001;
localparam S1    = 3'b011;
localparam S2    = 3'b111;
localparam S3    = 3'b110;



reg [2:0] nstate, pstate;
reg  corelet_l0_rd_en_o, corelet_ififo_rd_en_o;
reg [6:0]       icounter, icounter_q;
reg [3:0]       var_counter_q;
reg             var_counter_en, var_counter_en_q, corelet_l0_rd_en_o_q, corelet_ififo_rd_en_o_q;
reg [3:0]       delay_counter,delay_counter_q;
reg [1:0]       inst_o;
reg             fsm_shift_en;

always @(posedge clk) begin
    if (reset) 
        pstate <= S0;
    else 
        pstate <= nstate;
end



always @(posedge clk) begin
    if (reset)
        var_counter_q        <= 'b0;
    else if (var_counter_en)
        var_counter_q        <= var_counter_q + 1;
end


always @(posedge clk) begin
    if (reset)
        shift_psum        <= 'b0;
    else
        shift_psum        <= {shift_psum[6:0],fsm_shift_en};
end


always @(posedge clk) begin
    if (reset) begin
        icounter_q                      <= 7'b0;
        inst_o_q                        <= 2'b0;
        corelet_l0_rd_en_o_q            <= 1'b0;
        corelet_ififo_rd_en_o_q         <= 1'b0;
        delay_counter_q                 <= 4'b0;
        var_counter_en_q                <= 1'b0;
        corelet_l0_rd_en_o_qq           <= 1'b0;
        corelet_ififo_rd_en_o_qq           <= 1'b0;
    end
    else begin
        icounter_q                      <= icounter;
        inst_o_q                        <= inst_o;
        corelet_l0_rd_en_o_q            <= corelet_l0_rd_en_o;
        corelet_ififo_rd_en_o_q         <= corelet_ififo_rd_en_o;
        corelet_l0_rd_en_o_qq           <= corelet_l0_rd_en_o_q;  // understanding is inst is published 1 cycle before weights
        corelet_ififo_rd_en_o_qq        <= corelet_ififo_rd_en_o_q;  // understanding is inst is published 1 cycle before weights
        delay_counter_q                 <= delay_counter;
        var_counter_en_q                <= var_counter_en;
    end
end


always @(*) begin
    inst_o                  = 2'b0;
    corelet_l0_rd_en_o      = 1'b0;
    corelet_ififo_rd_en_o   = 1'b0;
    var_counter_en          = 'b0;
    delay_counter           = 3'b0;
    icounter                = 'b0;
    fsm_shift_en            = 1'b0;
    case (pstate) 
        S0: begin
            if (corelet_ififo_rd_ready_i && corelet_l0_rd_ready_i && (icounter_q!= 72) ) begin
                inst_o                  = 2'b01;
                corelet_l0_rd_en_o      = 1'b1;
                corelet_ififo_rd_en_o   = 1'b1;
                icounter                = icounter_q + 1;
                nstate                  = S0;
            end
            else if (icounter_q== 72) begin
                nstate = S1;
                var_counter_en     = 1'b1;
            end
            else
                nstate             = S0;
        end
        
        S1: begin
            if (delay_counter_q!=8) 
                delay_counter = delay_counter_q + 1;
            else  begin
                nstate = S2;
            end
        end

        S2: begin
            if (corelet_ififo_rd_ready_i && corelet_l0_rd_ready_i && (icounter_q!= 8) ) begin
                //inst_o             = 2'b10;
                fsm_shift_en       = 1'b1;
                icounter           = icounter_q + 1;
            end
            else if (icounter_q== 8) begin
                nstate = S3;
            end
        end

        S3: begin
            if (var_counter_q == 2)
                nstate             = IDLE;
            else if (delay_counter_q!=8) 
                delay_counter = delay_counter_q + 1;
            else begin
                nstate              = S0;
            end
        end

        IDLE: begin
                nstate = pstate;
        end

        default: nstate = pstate;
    endcase
end

endmodule
