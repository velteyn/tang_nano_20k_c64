module hdmi 
#(
    parameter bit IT_CONTENT = 1'b1,
    parameter int AUDIO_RATE = 44100,
    parameter int AUDIO_BIT_WIDTH = 16,
    parameter bit [8*8-1:0] VENDOR_NAME = {"Unknown", 8'd0},
    parameter bit [8*16-1:0] PRODUCT_DESCRIPTION = {"FPGA", 96'd0},
    parameter bit [7:0] SOURCE_DEVICE_INFORMATION = 8'h00
)
(
    input logic clk_pixel_x5,
    input logic clk_pixel,
    input logic clk_audio,
    input logic reset,
    input logic [1:0] stmode,
    input wide,
    input logic [23:0] rgb, 
    input logic [AUDIO_BIT_WIDTH-1:0] audio_sample_word [1:0],
    output logic [2:0] tmds,
    output logic tmds_clock
);

localparam int NUM_CHANNELS = 3;
logic hsync;
logic vsync;
logic [1:0] invert;

wire [55:0] htiming0  = { 11'd0,  12'd1000, 11'd800, 11'd16, 11'd62 }; 
wire [55:0] whtiming0 = { 11'd40, 12'd1000, 11'd928, 11'd16, 11'd32 };  
wire [39:0] vtiming0  = {         10'd526, 10'd480, 10'd9,  10'd6 };
wire [7:0] cea0 = 8'd2;
wire [55:0] htiming1  = { 11'd0,  12'd1008, 11'd800, 11'd24, 11'd72 }; 
wire [55:0] whtiming1 = { 11'd60, 12'd1008, 11'd952, 11'd16, 11'd32 };  
wire [39:0] vtiming1  = {          10'd624, 10'd576,  10'd5,  10'd5 };
wire [7:0] cea1 = 8'd17;
wire [55:0] htiming2  = { 11'd0,   12'd896, 11'd640, 11'd24, 11'd72 };
wire [55:0] whtiming2 = { 11'd40,  12'd896, 11'd720, 11'd24, 11'd72 };
wire [39:0] vtiming2  = {          10'd501, 10'd400,  10'd5,  10'd5 };  
wire [7:0] cea2 = 8'd2;
wire [103:0]  timing0 = {  htiming0, vtiming0, cea0 };
wire [103:0] wtiming0 = { whtiming0, vtiming0, cea0 };
wire [103:0]  timing1 = {  htiming1, vtiming1, cea1 };
wire [103:0] wtiming1 = { whtiming1, vtiming1, cea1 };
wire [103:0]  timing2 = {  htiming2, vtiming2, cea2 };
wire [103:0] wtiming2 = { whtiming2, vtiming2, cea2 };

wire [103:0] timing = 
         !wide?( (stmode == 2'd0)?timing0:
                 (stmode == 2'd1)?timing1:
                  timing2):
               ( (stmode == 2'd0)?wtiming0:
                 (stmode == 2'd1)?wtiming1:
                  wtiming2);

wire [10:0] start_x           = timing[103:93];
wire [11:0] frame_width       = timing[92:81];
wire [10:0] screen_width      = timing[80:70];
wire [10:0] hsync_pulse_start = timing[69:59];
wire [10:0] hsync_pulse_size  = timing[58:48];
wire [9:0] frame_height       = timing[47:38];
wire [9:0] screen_height      = timing[37:28];
wire [9:0] vsync_pulse_start  = timing[27:18];
wire [9:0] vsync_pulse_size   = timing[17: 8];
wire [7:0] cea                = timing[7:0]; 
   
assign invert = 2'b11;

reg [10:0] cx;
reg [9:0] cy;

always_comb begin
    hsync <= invert[0] ^ (cx >= screen_width + hsync_pulse_start && cx < screen_width + hsync_pulse_start + hsync_pulse_size);
    if (cy == screen_height + vsync_pulse_start - 1)
        vsync <= invert[1] ^ (cx >= screen_width + hsync_pulse_start);
    else if (cy == screen_height + vsync_pulse_start + vsync_pulse_size - 1)
        vsync <= invert[1] ^ (cx < screen_width + hsync_pulse_start);
    else
        vsync <= invert[1] ^ (cy >= screen_height + vsync_pulse_start && cy < screen_height + vsync_pulse_start + vsync_pulse_size);
end

localparam real VIDEO_RATE = 31.5E6;

always_ff @(posedge clk_pixel)
begin
    if (reset)
    begin
        cx <= start_x;
        cy <= 10'd0;
    end
    else
    begin
        cx <= cx == frame_width-1'b1 ? 11'd0 : cx + 1'b1;
        cy <= cx == frame_width-1'b1 ? cy == frame_height-1'b1 ? 10'd0 : cy + 1'b1 : cy;
    end
end

logic video_data_period = 0;
always_ff @(posedge clk_pixel)
begin
    if (reset)
        video_data_period <= 0;
    else
        video_data_period <= cx < screen_width && cy < screen_height;
end

logic [2:0] mode = 3'd1;
logic [23:0] video_data = 24'd0;
logic [5:0] control_data = 6'd0;
logic [11:0] data_island_data = 12'd0;

generate
    begin: true_hdmi_output
        logic video_guard = 1;
        logic video_preamble = 0;
        always_ff @(posedge clk_pixel)
        begin
            if (reset)
            begin
                video_guard <= 1;
                video_preamble <= 0;
            end
            else
            begin
                video_guard <= cx >= frame_width - 2 && cx < frame_width && (cy == frame_height - 1 || cy < screen_height - 1);
                video_preamble <= cx >= frame_width - 10 && cx < frame_width - 2 && (cy == frame_height - 1 || cy < screen_height - 1);
            end
        end

        int max_num_packets_alongside;
        logic [4:0] num_packets_alongside;
        always_comb
        begin
	        max_num_packets_alongside = (frame_width - screen_width - 2 - 8 - 4 - 2 - 2 - 8 - 4) / 32;
            if (max_num_packets_alongside > 18)
                num_packets_alongside = 5'd18;
            else
                num_packets_alongside = 5'(max_num_packets_alongside);
        end

        logic data_island_period_instantaneous;
        assign data_island_period_instantaneous = num_packets_alongside > 0 && cx >= screen_width + 14 && cx < screen_width + 14 + num_packets_alongside * 32;
        logic packet_enable;
        assign packet_enable = data_island_period_instantaneous && 5'(cx + screen_width + 18) == 5'd0;

        logic data_island_guard = 0;
        logic data_island_preamble = 0;
        logic data_island_period = 0;
        always_ff @(posedge clk_pixel)
        begin
            if (reset)
            begin
                data_island_guard <= 0;
                data_island_preamble <= 0;
                data_island_period <= 0;
            end
            else
            begin
	            data_island_guard <= num_packets_alongside > 0 && (
                    (cx >= screen_width + 12 && cx < screen_width + 14) || 
                    (cx >= screen_width + 14 + num_packets_alongside * 32 && cx < screen_width + 14 + num_packets_alongside * 32 + 2)
                );
                data_island_preamble <= num_packets_alongside > 0 && cx >= screen_width + 4 && cx < screen_width + 12;
                data_island_period <= data_island_period_instantaneous;
            end
        end

        logic [23:0] header;
        logic [55:0] sub [3:0];
        logic video_field_end;
        assign video_field_end = cx == screen_width - 1'b1 && cy == screen_height - 1'b1;
        logic [4:0] packet_pixel_counter;
        packet_picker #(
            .VIDEO_RATE(VIDEO_RATE),
            .IT_CONTENT(IT_CONTENT),
            .AUDIO_RATE(AUDIO_RATE),
            .AUDIO_BIT_WIDTH(AUDIO_BIT_WIDTH),
            .VENDOR_NAME(VENDOR_NAME),
            .PRODUCT_DESCRIPTION(PRODUCT_DESCRIPTION),
            .SOURCE_DEVICE_INFORMATION(SOURCE_DEVICE_INFORMATION)
        ) packet_picker (.clk_pixel(clk_pixel), .clk_audio(clk_audio), .reset(reset), .cea(cea), .stmode(stmode), .video_field_end(video_field_end), .packet_enable(packet_enable), .packet_pixel_counter(packet_pixel_counter), .audio_sample_word(audio_sample_word), .header(header), .sub(sub));
        logic [8:0] packet_data;
        packet_assembler packet_assembler (.clk_pixel(clk_pixel), .reset(reset), .data_island_period(data_island_period), .header(header), .sub(sub), .packet_data(packet_data), .counter(packet_pixel_counter));

        always_ff @(posedge clk_pixel)
        begin
            if (reset)
            begin
                mode <= 3'd2;
                video_data <= 24'd0;
                control_data = 6'd0;
                data_island_data <= 12'd0;
            end
            else
            begin
                mode <= data_island_guard ? 3'd4 : data_island_period ? 3'd3 : video_guard ? 3'd2 : video_data_period ? 3'd1 : 3'd0;
                video_data <= rgb;
                control_data <= {{1'b0, data_island_preamble}, {1'b0, video_preamble || data_island_preamble}, {vsync, hsync}};
                data_island_data[11:4] <= packet_data[8:1];
                data_island_data[3] <= cx != 0;
                data_island_data[2] <= packet_data[0];
                data_island_data[1:0] <= {vsync, hsync};
            end
        end
    end
endgenerate

logic [9:0] tmds_internal [NUM_CHANNELS-1:0];
genvar i;
generate
    for (i = 0; i < NUM_CHANNELS; i++)
    begin: tmds_gen
        tmds_channel #(.CN(i)) tmds_channel (.clk_pixel(clk_pixel), .video_data(video_data[i*8+7:i*8]), .data_island_data(data_island_data[i*4+3:i*4]), .control_data(control_data[i*2+1:i*2]), .mode(mode), .tmds(tmds_internal[i]));
    end
endgenerate

serializer #(.NUM_CHANNELS(NUM_CHANNELS)) serializer(.clk_pixel(clk_pixel), .clk_pixel_x5(clk_pixel_x5), .reset(reset), .tmds_internal(tmds_internal), .tmds(tmds), .tmds_clock(tmds_clock));

endmodule

