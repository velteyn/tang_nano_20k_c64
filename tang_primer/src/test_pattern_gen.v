module test_pattern_gen (
    input  wire       clk,
    input  wire       rst_n,
    output reg        hs,
    output reg        vs,
    output reg        de,
    output reg  [7:0] r,
    output reg  [7:0] g,
    output reg  [7:0] b
);

    // 640x480 @ 60Hz Timing (25.175 MHz)
    parameter H_DISPLAY = 640;
    parameter H_FRONT   = 16;
    parameter H_SYNC    = 96;
    parameter H_BACK    = 48;
    parameter H_TOTAL   = 800;

    parameter V_DISPLAY = 480;
    parameter V_FRONT   = 10;
    parameter V_SYNC    = 2;
    parameter V_BACK    = 33;
    parameter V_TOTAL   = 525;

    reg [11:0] h_cnt;
    reg [11:0] v_cnt;

    // Color Bars
    // 8 bars: White, Yellow, Cyan, Green, Magenta, Red, Blue, Black
    // Width per bar = 640 / 8 = 80 pixels

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt <= 0;
            v_cnt <= 0;
            hs <= 1; // Active Low, default high
            vs <= 1; // Active Low, default high
            de <= 0;
            r <= 0;
            g <= 0;
            b <= 0;
        end else begin
            // Counters
            if (h_cnt < H_TOTAL - 1)
                h_cnt <= h_cnt + 12'd1;
            else begin
                h_cnt <= 0;
                if (v_cnt < V_TOTAL - 1)
                    v_cnt <= v_cnt + 12'd1;
                else
                    v_cnt <= 0;
            end

            // Sync Signals (Active Low)
            // H_SYNC starts after H_DISPLAY + H_FRONT
            if (h_cnt >= H_DISPLAY + H_FRONT && h_cnt < H_DISPLAY + H_FRONT + H_SYNC)
                hs <= 0;
            else
                hs <= 1;

            // V_SYNC starts after V_DISPLAY + V_FRONT
            if (v_cnt >= V_DISPLAY + V_FRONT && v_cnt < V_DISPLAY + V_FRONT + V_SYNC)
                vs <= 0;
            else
                vs <= 1;

            // Data Enable
            if (h_cnt < H_DISPLAY && v_cnt < V_DISPLAY) begin
                de <= 1;
                // Generate Color Bars
                // 0-79: White (111)
                // 80-159: Yellow (110)
                // 160-239: Cyan (011)
                // 240-319: Green (010)
                // 320-399: Magenta (101)
                // 400-479: Red (100)
                // 480-559: Blue (001)
                // 560-639: Black (000)
                
                // Use h_cnt[8:0] to check range? 80 is not power of 2.
                // Divide by 80? Or use comparisons.
                if (h_cnt < 80) begin r <= 255; g <= 255; b <= 255; end
                else if (h_cnt < 160) begin r <= 255; g <= 255; b <= 0; end
                else if (h_cnt < 240) begin r <= 0;   g <= 255; b <= 255; end
                else if (h_cnt < 320) begin r <= 0;   g <= 255; b <= 0; end
                else if (h_cnt < 400) begin r <= 255; g <= 0;   b <= 255; end
                else if (h_cnt < 480) begin r <= 255; g <= 0;   b <= 0; end
                else if (h_cnt < 560) begin r <= 0;   g <= 0;   b <= 255; end
                else begin r <= 0; g <= 0; b <= 0; end

            end else begin
                de <= 0;
                r <= 0;
                g <= 0;
                b <= 0;
            end
        end
    end

endmodule
