module dvi_640x480(
    input  logic clk_pixel_x5,
    input  logic clk_pixel,
    input  logic reset,
    output logic [2:0] tmds,
    output logic tmds_clock
);

localparam int NUM_CHANNELS = 3;

wire [10:0] start_x           = 11'd0;
wire [11:0] frame_width       = 12'd800;
wire [10:0] screen_width      = 11'd640;
wire [10:0] hsync_pulse_start = 11'd16;
wire [10:0] hsync_pulse_size  = 11'd96;
wire [9:0]  frame_height      = 10'd525;
wire [9:0]  screen_height     = 10'd480;
wire [9:0]  vsync_pulse_start = 10'd10;
wire [9:0]  vsync_pulse_size  = 10'd2;

logic [1:0] invert = 2'b11;

reg [10:0] cx;
reg [9:0]  cy;
always_ff @(posedge clk_pixel) begin
    if (reset) begin
        cx <= start_x;
        cy <= 10'd0;
    end else begin
        cx <= (cx == frame_width-1) ? 11'd0 : cx + 11'd1;
        if (cx == frame_width-1)
            cy <= (cy == frame_height-1) ? 10'd0 : cy + 10'd1;
    end
end

logic hsync, vsync;
always_comb begin
    hsync = invert[0] ^ (cx >= screen_width + hsync_pulse_start &&
                         cx <  screen_width + hsync_pulse_start + hsync_pulse_size);
    if (cy == screen_height + vsync_pulse_start - 1)
        vsync = invert[1] ^ (cx >= screen_width + hsync_pulse_start);
    else if (cy == screen_height + vsync_pulse_start + vsync_pulse_size - 1)
        vsync = invert[1] ^ (cx < screen_width + hsync_pulse_start);
    else
        vsync = invert[1] ^ (cy >= screen_height + vsync_pulse_start &&
                             cy <  screen_height + vsync_pulse_start + vsync_pulse_size);
end

logic video_data_period;
always_ff @(posedge clk_pixel) begin
    if (reset)
        video_data_period <= 1'b0;
    else
        video_data_period <= (cx < screen_width) && (cy < screen_height);
end

logic [2:0] mode;
logic [23:0] video_data;
logic [5:0] control_data;
logic [11:0] data_island_data;

function automatic [23:0] bars(input [10:0] x);
    automatic logic [23:0] c;
    case ( (x * 8) / 11'd640 )
        0: c = 24'hFFFFFF;
        1: c = 24'hFFFF00;
        2: c = 24'h00FFFF;
        3: c = 24'h00FF00;
        4: c = 24'hFF00FF;
        5: c = 24'hFF0000;
        6: c = 24'h0000FF;
        default: c = 24'h000000;
    endcase
    return c;
endfunction

always_ff @(posedge clk_pixel) begin
    if (reset) begin
        mode <= 3'd0;
        video_data <= 24'd0;
        control_data <= 6'd0;
        data_island_data <= 12'd0;
    end else begin
        mode <= video_data_period ? 3'd1 : 3'd0;
        video_data <= video_data_period ? bars(cx) : 24'd0;
        control_data <= {2'b00, vsync, hsync};
        data_island_data <= 12'd0;
    end
end

logic [9:0] tmds_internal [NUM_CHANNELS-1:0];
genvar i;
generate
    for (i = 0; i < NUM_CHANNELS; i=i+1) begin: tmds_gen
        tmds_channel #(.CN(i)) u_chan (
            .clk_pixel(clk_pixel),
            .video_data(video_data[i*8+7:i*8]),
            .data_island_data(data_island_data[i*4+3:i*4]),
            .control_data(control_data[i*2+1:i*2]),
            .mode(mode),
            .tmds(tmds_internal[i])
        );
    end
endgenerate

serializer #(.NUM_CHANNELS(NUM_CHANNELS)) u_ser (
    .clk_pixel(clk_pixel),
    .clk_pixel_x5(clk_pixel_x5),
    .reset(reset),
    .tmds_internal(tmds_internal),
    .tmds(tmds),
    .tmds_clock(tmds_clock)
);

endmodule
