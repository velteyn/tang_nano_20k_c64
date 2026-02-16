// Implementation of HDMI packet ECC calculation.
// By Sameer Puri https://github.com/sameer

module packet_assembler (
    input logic clk_pixel,
    input logic reset,
    input logic data_island_period,
    input logic [23:0] header, // See Table 5-8 Packet Types
    input logic [55:0] sub [3:0],
    output logic [8:0] packet_data, // See Figure 5-4 Data Island Packet and ECC Structure
    output logic [4:0] counter
);

always_ff @(posedge clk_pixel)
begin
    if (reset)
        counter <= 5'd0;
    else if (data_island_period)
        counter <= counter + 5'd1;
end
wire [5:0] counter_t2 = {counter, 1'b0};
wire [5:0] counter_t2_p1 = {counter, 1'b1};

logic [7:0] parity [4:0] = '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0};

wire [63:0] bch [3:0];
assign bch[0] = {parity[0], sub[0]};
assign bch[1] = {parity[1], sub[1]};
assign bch[2] = {parity[2], sub[2]};
assign bch[3] = {parity[3], sub[3]};
wire [31:0] bch4 = {parity[4], header};
assign packet_data = {bch[3][counter_t2_p1], bch[2][counter_t2_p1], bch[1][counter_t2_p1], bch[0][counter_t2_p1], bch[3][counter_t2], bch[2][counter_t2], bch[1][counter_t2], bch[0][counter_t2], bch4[counter]};

function automatic [7:0] next_ecc;
input [7:0] ecc, next_bch_bit;
begin
    next_ecc = (ecc >> 1) ^ ((ecc[0] ^ next_bch_bit) ? 8'b10000011 : 8'd0);
end
endfunction

logic [7:0] parity_next [4:0];
logic [7:0] parity_next_next [3:0];

genvar i;
generate
    for(i = 0; i < 5; i++)
    begin: parity_calc
        if (i == 4)
            assign parity_next[i] = next_ecc(parity[i], header[counter]);
        else
        begin
            assign parity_next[i] = next_ecc(parity[i], sub[i][counter_t2]);
            assign parity_next_next[i] = next_ecc(parity_next[i], sub[i][counter_t2_p1]);
        end
    end
endgenerate

always_ff @(posedge clk_pixel)
begin
    if (reset)
        parity <= '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0};
    else if (data_island_period)
    begin
        if (counter < 5'd28)
        begin
            parity[3:0] <= parity_next_next;
            if (counter < 5'd24)
                parity[4] <= parity_next[4];
        end
        else if (counter == 5'd31)
            parity <= '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0};
    end
    else
        parity <= '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0};
end

endmodule

