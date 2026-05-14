module hdmi 
#(
    parameter bit IT_CONTENT = 1'b1,
    parameter int AUDIO_RATE = 44100,
    parameter int AUDIO_BIT_WIDTH = 16,
    parameter bit [8*8-1:0] VENDOR_NAME = {"Unknown", 8'd0},
    parameter bit [8*16-1:0] PRODUCT_DESCRIPTION = {"FPGA", 96'd0},
    parameter bit [7:0] SOURCE_DEVICE_INFORMATION = 8'h00,
    parameter bit INTERNAL_BARS = 1'b1
)
(
    input  logic                    clk_pixel_x5,
    input  logic                    clk_pixel,
    input  logic                    clk_audio,
    input  logic                    reset,
    input  logic [1:0]              stmode,
    input                           wide,
    input  logic [23:0]             rgb, 
    input  logic [AUDIO_BIT_WIDTH-1:0] audio_sample_word [1:0],
    output logic [2:0]              tmds,
    output logic                    tmds_clock
);

localparam int NUM_CHANNELS = 3;

logic hsync;
logic vsync;
logic [1:0] invert;

// VESA 800x600@60Hz (SVGA) timing at ~40MHz pixel
// H: 800 active, FP=40, SYNC=128, BP=88 => total 1056
// V: 600 active, FP=1,  SYNC=4,   BP=23 => total 628

wire [10:0] start_x           = 11'd0;
wire [11:0] frame_width       = 12'd1056;
wire [10:0] screen_width      = 11'd800;
wire [10:0] hsync_pulse_start = 11'd40;   // front porch
wire [10:0] hsync_pulse_size  = 11'd128;
wire [9:0]  frame_height      = 10'd628;
wire [9:0]  screen_height     = 10'd600;
wire [9:0]  vsync_pulse_start = 10'd1;    // front porch
wire [9:0]  vsync_pulse_size  = 10'd4;
wire [7:0]  cea               = 8'd0;     // non-CEA (VESA), informational
   
// VESA 800x600 uses positive polarity for HS/VS
assign invert = 2'b00;

reg [10:0] cx;
reg [9:0]  cy;

always_comb begin
    hsync <= invert[0] ^ (cx >= screen_width + hsync_pulse_start && cx < screen_width + hsync_pulse_start + hsync_pulse_size);
    if (cy == screen_height + vsync_pulse_start - 1)
        vsync <= invert[1] ^ (cx >= screen_width + hsync_pulse_start);
    else if (cy == screen_height + vsync_pulse_start + vsync_pulse_size - 1)
        vsync <= invert[1] ^ (cx < screen_width + hsync_pulse_start);
    else
        vsync <= invert[1] ^ (cy >= screen_height + vsync_pulse_start && cy < screen_height + vsync_pulse_start + vsync_pulse_size);
end

localparam real VIDEO_RATE = 40.5E6;

always_ff @(posedge clk_pixel)
begin
    if (reset) begin
        cx <= start_x;
        cy <= 10'd0;
    end else begin
        cx <= cx == frame_width-1'b1 ? 11'd0 : cx + 1'b1;
        cy <= cx == frame_width-1'b1 ? (cy == frame_height-1'b1 ? 10'd0 : cy + 1'b1) : cy;
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

// Optional internal color bars over the active area
function automatic [23:0] bars(input [10:0] x);
    automatic logic [23:0] c;
    case ( (x * 8) / 11'd800 )
        0: c = 24'hFFFFFF; // White
        1: c = 24'hFFFF00; // Yellow
        2: c = 24'h00FFFF; // Cyan
        3: c = 24'h00FF00; // Green
        4: c = 24'hFF00FF; // Magenta
        5: c = 24'hFF0000; // Red
        6: c = 24'h0000FF; // Blue
        default: c = 24'h000000;
    endcase
    return c;
endfunction

generate
    begin: true_hdmi_output
        logic video_guard = 1;
        logic video_preamble = 0;
        always_ff @(posedge clk_pixel)
        begin
            if (reset) begin
                video_guard <= 1;
                video_preamble <= 0;
            end else begin
                video_guard <= cx >= frame_width - 2 && cx < frame_width && (cy == frame_height - 1 || cy < screen_height - 1);
                video_preamble <= cx >= frame_width - 10 && cx < frame_width - 2 && (cy == frame_height - 1 || cy < screen_height - 1);
            end
        end

        int max_num_packets_alongside;
        logic [4:0] num_packets_alongside;
        always_comb begin
	        max_num_packets_alongside = (frame_width - screen_width  - 2 - 8 - 4 - 2 - 2 - 8 - 4) / 32;
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
            if (reset) begin
                data_island_guard <= 0;
                data_island_preamble <= 0;
                data_island_period <= 0;
            end else begin
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
            if (reset) begin
                mode <= 3'd2;
                video_data <= 24'd0;
                control_data = 6'd0;
                data_island_data <= 12'd0;
            end else begin
                mode <= data_island_guard ? 3'd4 : data_island_period ? 3'd3 : video_guard ? 3'd2 : video_data_period ? 3'd1 : 3'd0;
                video_data <= INTERNAL_BARS ? (video_data_period ? bars(cx) : 24'd0) : rgb;
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

