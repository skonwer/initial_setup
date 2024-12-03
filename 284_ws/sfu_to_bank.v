module sfu_to_bank #(
    parameter bw=4,
    parameter psum_bw = 16,
    parameter col = 8,  // considering as OC
    parameter row = 8,  // considering as IC
    parameter addr_width = 8, //
    parameter len_onij=16
) (
    input                               clk,
    input                               reset,
    input [col*psum_bw-1:0]             psum_data_i,
    input                               psum_data_in_valid,
    output reg [$clog2(len_onij)-1:0]   psum_addr_out,
    output [col*psum_bw-1:0]            psum_data_o,
    output                              psum_data_out_valid,
    output  reg                         convolution_complete_o
    
);

reg [4:0] ocounter;

always @ (posedge clk) begin
    if (reset) begin
        psum_addr_out           <= 'b0;
        ocounter                <= 'b0;
        convolution_complete_o  <= 1'b0;
    end
    else if (psum_data_in_valid && ocounter!=16) begin
        psum_addr_out           <= psum_addr_out + 1;
        ocounter                <= ocounter + 1;
    end
    else if (ocounter == 16) begin
        convolution_complete_o   <= 1'b1;
    end
end

assign psum_data_o = psum_data_i;
assign psum_data_out_valid = psum_data_in_valid;


endmodule
