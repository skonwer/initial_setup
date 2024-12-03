module os_bank_to_fifo #(
    parameter bw=4,
    parameter psum_bw = 16,
    parameter col = 8,  // considering as OC
    parameter row = 8,  // considering as IC
    parameter addr_width = 8, //
    parameter len_onij=16
) (
    input                   clk,
    input                   reset,
    input                   corelet_l0_wr_ready_i,
    input                   corelet_ififo_wr_ready_i,
    input                   mem_load_complete_i,
    output reg              w_bank_read_en_n_o_q,                             // negedge active low
    output reg [6:0]        w_bank_read_addr_o_qq,                             //  7 bit because 72 is the depth
    output reg              x_bank_read_en_n_o_q,                             // negedge active low
    output reg [7:0]        x_bank_read_addr_o_qq,                             //  8 bit because 144 is the depth
    output reg              corelet_l0_wr_en_o_q,
    output reg              corelet_ififo_wr_en_o_q

);


localparam RESET = 2'b01;
localparam S0    = 2'b11;
localparam S1    = 2'b10;

reg [2:0]       nstate,pstate;
reg [6:0]       counter, counter_q;
reg [6:0]       w_bank_read_addr_o, w_bank_read_addr_o_q;
reg [7:0]       x_bank_read_addr_o, x_bank_read_addr_o_q;
reg [1:0]       delay_counter,delay_counter_q;
reg             corelet_ififo_wr_en_o, corelet_l0_wr_en_o, w_bank_read_en_n_o, x_bank_read_en_n_o,var_counter_en_q,var_counter_en;
reg [1:0]       var_q;

always @(posedge clk) begin
    if (reset) 
        pstate <= RESET;
    else 
        pstate <= nstate;
end

always @(posedge clk) begin
    if (reset) begin
        counter_q               <= 7'b0;
        w_bank_read_addr_o_q    <= 7'b0;
        w_bank_read_addr_o_qq   <= 7'b0;
        w_bank_read_en_n_o_q    <= 1'b1;
        x_bank_read_addr_o_q    <= 8'b0;
        x_bank_read_addr_o_qq   <= 8'b0;
        x_bank_read_en_n_o_q    <= 1'b1;
        corelet_l0_wr_en_o_q    <= 1'b0;
        corelet_ififo_wr_en_o_q <= 1'b0;
        delay_counter_q         <= 2'b0;
        var_counter_en_q        <= 1'b0;
    end
    else begin
        counter_q               <= counter;
        w_bank_read_addr_o_q    <= w_bank_read_addr_o;
        w_bank_read_addr_o_qq   <= w_bank_read_addr_o_q;
        w_bank_read_en_n_o_q    <= w_bank_read_en_n_o;
        x_bank_read_addr_o_q    <= w_bank_read_addr_o;
        x_bank_read_addr_o_qq   <= x_bank_read_addr_o_q;
        x_bank_read_en_n_o_q    <= x_bank_read_en_n_o;
        corelet_l0_wr_en_o_q    <= corelet_l0_wr_en_o;
        corelet_ififo_wr_en_o_q <= corelet_ififo_wr_en_o;
        delay_counter_q         <= delay_counter;
        var_counter_en_q        <= var_counter_en;
    end
end

always @(posedge clk) begin
    if (reset)
        var_q        <= 2'b0;
    else if (var_counter_en)
        var_q        <= var_q + 1;
end


always @ (*) begin
    counter                 = 0;
    w_bank_read_en_n_o      = 1'b1;
    w_bank_read_addr_o      = 'b0;
    x_bank_read_en_n_o      = 1'b1;
    x_bank_read_addr_o      = 'b0;
    corelet_l0_wr_en_o      = 1'b0;
    corelet_ififo_wr_en_o   = 1'b0;
    delay_counter           = 2'b0;
    var_counter_en          = 1'b0;

    case (pstate) 
        RESET: begin
            if(mem_load_complete_i && var_q != 2) nstate = S0;
            else                    nstate = RESET;
        end
        S0: begin
            corelet_l0_wr_en_o      = ~x_bank_read_en_n_o_q;            
            corelet_ififo_wr_en_o   = ~w_bank_read_en_n_o_q;
            if(corelet_ififo_wr_ready_i && corelet_l0_wr_ready_i && (counter_q!=72))   begin         // counter != 8
                w_bank_read_en_n_o = 1'b0;
                x_bank_read_en_n_o = 1'b0;
                w_bank_read_addr_o = w_bank_read_addr_o_q + 1;
                x_bank_read_addr_o = x_bank_read_addr_o_q + 1 + 72*var_q;
                counter           = counter_q + 1;
            end
            else if (counter_q==72) begin
                var_counter_en     = 1'b1;
                nstate             = S1;
            end
        end

        S1: begin
            if (var_q == 2) 
                nstate = RESET;
            else if (delay_counter_q != 1)
                delay_counter = delay_counter_q + 1;
            else
                nstate = S0;
            end

    endcase
end

endmodule
