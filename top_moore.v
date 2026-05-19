`timescale 1ns / 1ps

module top_moore(
    input wire clk,
    input wire btnC,
    input wire btnU,
    input wire sw0,
    output wire [6:0] seg,
    output wire dp,
    output wire [7:0] an,
    output wire [15:0] led
);

    wire reset;
    wire step_pulse;
    wire w;
    wire y;
    wire [2:0] state;

    assign reset = btnU;
    assign w = sw0;

    assign led[0] = y;
    assign led[1] = w;
    assign led[4:2] = state;
    assign led[15:5] = 11'b0;

    debounce_onepulse debounce_btnC(
        .clk(clk),
        .reset(reset),
        .button(btnC),
        .pulse(step_pulse)
    );

    fsm_moore_1011 fsm(
        .clk(step_pulse),
        .reset(reset),
        .w(w),
        .y(y),
        .state(state)
    );

    sevenseg_display display(
        .clk(clk),
        .reset(reset),
        .w(w),
        .y(y),
        .state(state[1:0]),
        .seg(seg),
        .dp(dp),
        .an(an)
    );

endmodule


module fsm_moore_1011(
    input wire clk,
    input wire reset,
    input wire w,
    output reg y,
    output reg [2:0] state
);

    parameter S0 = 3'b000; // belum ada pola
    parameter S1 = 3'b001; // sudah dapat 1
    parameter S2 = 3'b010; // sudah dapat 10
    parameter S3 = 3'b011; // sudah dapat 101
    parameter S4 = 3'b100; // sudah dapat 1011, y = 1

    reg [2:0] next_state;

    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= S0;
        else
            state <= next_state;
    end

    always @(*) begin
        case (state)
            S0: begin
                if (w == 1'b0)
                    next_state = S0;
                else
                    next_state = S1;
            end

            S1: begin
                if (w == 1'b0)
                    next_state = S2;
                else
                    next_state = S1;
            end

            S2: begin
                if (w == 1'b0)
                    next_state = S0;
                else
                    next_state = S3;
            end

            S3: begin
                if (w == 1'b0)
                    next_state = S2;
                else
                    next_state = S4;
            end

            S4: begin
                if (w == 1'b0)
                    next_state = S2;
                else
                    next_state = S1;
            end

            default: begin
                next_state = S0;
            end
        endcase
    end

    always @(*) begin
        case (state)
            S4: y = 1'b1;
            default: y = 1'b0;
        endcase
    end

endmodule


module debounce_onepulse(
    input wire clk,
    input wire reset,
    input wire button,
    output reg pulse
);

    reg [19:0] count;
    reg button_sync_0;
    reg button_sync_1;
    reg button_stable;
    reg button_last;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            button_sync_0 <= 1'b0;
            button_sync_1 <= 1'b0;
        end else begin
            button_sync_0 <= button;
            button_sync_1 <= button_sync_0;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count <= 20'd0;
            button_stable <= 1'b0;
        end else begin
            if (button_sync_1 == button_stable) begin
                count <= 20'd0;
            end else begin
                count <= count + 20'd1;

                if (count == 20'd999999) begin
                    button_stable <= button_sync_1;
                    count <= 20'd0;
                end
            end
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            button_last <= 1'b0;
            pulse <= 1'b0;
        end else begin
            pulse <= button_stable & ~button_last;
            button_last <= button_stable;
        end
    end

endmodule


module sevenseg_display(
    input wire clk,
    input wire reset,
    input wire w,
    input wire y,
    input wire [1:0] state,
    output reg [6:0] seg,
    output wire dp,
    output reg [7:0] an
);

    reg [16:0] scan;
    wire [2:0] sel;

    assign sel = scan[16:14];
    assign dp = 1'b1;

    always @(posedge clk or posedge reset) begin
        if (reset)
            scan <= 17'd0;
        else
            scan <= scan + 17'd1;
    end

    always @(*) begin
        an = 8'b11111111;
        an[sel] = 1'b0;

        case (sel)
            3'd7: begin
                seg = 7'b1100011; // w, terlihat seperti u/w
            end

            3'd6: begin
                if (w == 1'b1)
                    seg = 7'b1111001; // 1
                else
                    seg = 7'b1000000; // 0
            end

            3'd5: begin
                seg = 7'b0010001; // y
            end

            3'd4: begin
                if (y == 1'b1)
                    seg = 7'b1111001; // 1
                else
                    seg = 7'b1000000; // 0
            end

            3'd3: begin
                seg = 7'b0010010; // S
            end

            3'd2: begin
                seg = 7'b0000111; // t
            end

            3'd1: begin
                if (state[1] == 1'b1)
                    seg = 7'b1111001; // 1
                else
                    seg = 7'b1000000; // 0
            end

            3'd0: begin
                if (state[0] == 1'b1)
                    seg = 7'b1111001; // 1
                else
                    seg = 7'b1000000; // 0
            end

            default: begin
                seg = 7'b1111111;
            end
        endcase
    end

endmodule
