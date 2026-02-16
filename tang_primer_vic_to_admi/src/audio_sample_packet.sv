// Implementation of HDMI audio sample packet
// By Sameer Puri https://github.com/sameer

module audio_sample_packet 
#(
    parameter bit GRADE = 1'b0,
    parameter bit SAMPLE_WORD_TYPE = 1'b0,
    parameter bit COPYRIGHT_NOT_ASSERTED = 1'b1,
    parameter bit [2:0] PRE_EMPHASIS = 3'b000,
    parameter bit [1:0] MODE = 2'b00,
    parameter bit [7:0] CATEGORY_CODE = 8'd0,
    parameter bit [3:0] SOURCE_NUMBER = 4'd0,
    parameter bit [3:0] SAMPLING_FREQUENCY = 4'b0000,
    parameter bit [1:0] CLOCK_ACCURACY = 2'b00,
    parameter bit [3:0] WORD_LENGTH = 0,
    parameter bit [3:0] ORIGINAL_SAMPLING_FREQUENCY = 4'b0000,
    parameter bit LAYOUT = 1'b0
)
(
    input logic [7:0] frame_counter,
    input logic [1:0] valid_bit [3:0],
    input logic [1:0] user_data_bit [3:0],
    input logic [23:0] audio_sample_word [3:0] [1:0],
    input logic [3:0] audio_sample_word_present,
    output logic [23:0] header,
    output logic [55:0] sub [3:0]
);

logic [3:0] CHANNEL_LEFT = 4'd1;
logic [3:0] CHANNEL_RIGHT = 4'd2;

localparam bit [7:0] CHANNEL_STATUS_LENGTH = 8'd192;
logic [192-1:0] channel_status_left;
assign channel_status_left = {152'd0, ORIGINAL_SAMPLING_FREQUENCY, WORD_LENGTH, 2'b00, CLOCK_ACCURACY, SAMPLING_FREQUENCY, CHANNEL_LEFT, SOURCE_NUMBER, CATEGORY_CODE, MODE, PRE_EMPHASIS, COPYRIGHT_NOT_ASSERTED, SAMPLE_WORD_TYPE, GRADE};
logic [CHANNEL_STATUS_LENGTH-1:0] channel_status_right;
assign channel_status_right = {152'd0, ORIGINAL_SAMPLING_FREQUENCY, WORD_LENGTH, 2'b00, CLOCK_ACCURACY, SAMPLING_FREQUENCY, CHANNEL_RIGHT, SOURCE_NUMBER, CATEGORY_CODE, MODE, PRE_EMPHASIS, COPYRIGHT_NOT_ASSERTED, SAMPLE_WORD_TYPE, GRADE};

assign header[19:12] = {4'b0000, {3'b000, LAYOUT}};
assign header[7:0] = 8'd2;
logic [1:0] parity_bit [3:0];
logic [7:0] aligned_frame_counter [3:0];
genvar i;
generate
    for (i = 0; i < 4; i++)
    begin: sample_based_assign
        always_comb
        begin
            if (8'(frame_counter + i) >= CHANNEL_STATUS_LENGTH)
                aligned_frame_counter[i] = 8'(frame_counter + i - CHANNEL_STATUS_LENGTH);
            else
                aligned_frame_counter[i] = 8'(frame_counter + i);
        end
        assign header[23 - (3-i)] = aligned_frame_counter[i] == 8'd0 && audio_sample_word_present[i];
        assign header[11 - (3-i)] = audio_sample_word_present[i];
        assign parity_bit[i][0] = ^{channel_status_left[aligned_frame_counter[i]], user_data_bit[i][0], valid_bit[i][0], audio_sample_word[i][0]};
        assign parity_bit[i][1] = ^{channel_status_right[aligned_frame_counter[i]], user_data_bit[i][1], valid_bit[i][1], audio_sample_word[i][1]};
        always_comb
        begin
            if (audio_sample_word_present[i])
                sub[i] = {{parity_bit[i][1], channel_status_right[aligned_frame_counter[i]], user_data_bit[i][1], valid_bit[i][1], parity_bit[i][0], channel_status_left[aligned_frame_counter[i]], user_data_bit[i][0], valid_bit[i][0]}, audio_sample_word[i][1], audio_sample_word[i][0]};
            else
            `ifdef MODEL_TECH
                sub[i] = 56'd0;
            `else
                sub[i] = 56'dx;
            `endif
        end
    end
endgenerate

endmodule
