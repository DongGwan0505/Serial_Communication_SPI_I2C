`timescale 1ns / 1ps

module slave_pack (
    input logic clk,   // 내부 동기 클럭(예: 100MHz)
    input logic reset,

    // SPI pins
    input  logic SCLK,  // 외부 SPI SCLK
    input  logic MOSI,
    output logic MISO,  // 현재 미사용(Z)
    input  logic SS,    // Active-Low

    // 7-seg
    output logic [7:0] fnd_font,
    output logic [3:0] fnd_comm
);
    // 8-bit 수신
    logic [7:0] rx_data;
    logic       rx_done;
    logic       ss_n_sync;

    spi_slave_intf_sv U_INTF (
        .clk,
        .reset,
        .SCLK,
        .MOSI,
        .MISO,
        .SS,
        .rx_data,
        .rx_done,
        .ss_n_sync
    );

    // 8b×2 → 16b 조립 (펄스 카운트 방식)
    logic [15:0] value16;
    logic        value_valid;

    ctrl_2byte_assembler_sv #(
        .LSB_FIRST(1)
    ) U_CTRL (
        .clk,
        .reset,
        .ss_n (ss_n_sync),
        .rx_data,
        .rx_done,
        .value16,
        .valid(value_valid)
    );

    // FND 표시
    fnd_controller U_FND (
        .clk,
        .reset,
        .so_data(value16),
        .fnd_font,
        .fnd_comm
    );
endmodule

module spi_slave_intf_sv (
    input  logic clk,
    input  logic reset,
    input  logic SCLK,
    input  logic MOSI,
    output logic MISO,
    input  logic SS,

    output logic [7:0] rx_data,
    output logic       rx_done,   // 1clk pulse (sysclk)
    output logic       ss_n_sync
);
    // SCLK/SS 동기화
    logic sclk_d0, sclk_d1, sclk_d2;
    logic ss_d0, ss_d1, ss_d2;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            sclk_d0 <= 0;
            sclk_d1 <= 0;
            sclk_d2 <= 0;
            ss_d0   <= 1;
            ss_d1   <= 1;
            ss_d2   <= 1;
        end else begin
            sclk_d0 <= SCLK;
            sclk_d1 <= sclk_d0;
            sclk_d2 <= sclk_d1;
            ss_d0   <= SS;
            ss_d1   <= ss_d0;
            ss_d2   <= ss_d1;
        end
    end

    wire sclk_rise = sclk_d1 & ~sclk_d2;  // 상승엣지
    wire ss_deassert = ss_d1 & ~ss_d2;  // 0→1
    assign ss_n_sync = ss_d1;

    // LSB-first: 좌시프트 + MOSI 삽입
    logic [2:0] bit_cnt;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            bit_cnt <= '0;
            rx_data <= '0;
            rx_done <= 1'b0;
        end else begin
            rx_done <= 1'b0;
            if (ss_deassert) begin
                bit_cnt <= '0;  // 프레임 종료 시 카운터 초기화
            end else if (!ss_n_sync && sclk_rise) begin
                rx_data <= {rx_data[6:0], MOSI};
                if (bit_cnt == 3'd7) begin
                    bit_cnt <= '0;
                    rx_done <= 1'b1;  // 8비트 완료 펄스
                end else begin
                    bit_cnt <= bit_cnt + 3'd1;
                end
            end
        end
    end

    assign MISO = 1'bz;  // 현재 송신 미사용
endmodule

// SS가 Low인 동안 rx_done 펄스를 카운트:
//  - 1번째 펄스: 첫 바이트 저장
//  - 2번째 펄스: 둘째 바이트 저장 + 16b 결합 + valid=1clk
module ctrl_2byte_assembler_sv #(
    parameter bit LSB_FIRST = 1  // 1: LSB 바이트 먼저 들어옴
) (
    input logic       clk,
    input logic       reset,
    input logic       ss_n,     // High=비선택(동기화됨)
    input logic [7:0] rx_data,
    input logic       rx_done,  // 1clk 펄스

    output logic [15:0] value16,  // {MSB,LSB}
    output logic        valid     // 1clk 펄스
);
    logic [7:0] first_byte;
    logic       have_first;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            first_byte <= '0;
            have_first <= 1'b0;
            value16    <= '0;
            valid      <= 1'b0;
        end else begin
            valid <= 1'b0;

            // SS High 이면 언제든 프레임/상태 초기화
            if (ss_n) begin
                have_first <= 1'b0;
            end else if (rx_done) begin
                if (!have_first) begin
                    // 첫 바이트 저장
                    first_byte <= rx_data;
                    have_first <= 1'b1;
                end else begin
                    // 둘째 바이트 수신 → 16비트 결합 + valid 펄스
                    value16 <= LSB_FIRST ? {first_byte, rx_data}  // (MSB,LSB)
                    : {first_byte, rx_data};
                    valid <= 1'b1;
                    have_first <= 1'b0;  // 다음 프레임 준비
                end
            end
        end
    end
endmodule

`timescale 1ns / 1ps


module fnd_controller(
        input clk,
        input reset,
        input [15:0] so_data,
        output [7:0] fnd_font,
        output [3:0] fnd_comm
    );

    wire [3:0] w_digit_1, w_digit_10;
    wire [3:0] w_digit_100, w_digit_1000;

    wire [3:0] w_bcd;
    wire [1:0] o_sel;
    wire w_clk_400hz;

    counter_4 U_counter4 (
        .clk(w_clk_400hz),
        .reset(reset),
        .o_sel(o_sel)
    );

    bcdtoseg U_bcdtoseg( 
        .bcd(w_bcd),
        .seg(fnd_font)
    );

    digit_splitter #(.BIT_WIDTH(8)) U_Msec_ds(
        .bcd(so_data),
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000)
    );

    mux_4X1 U_mux41(
        .sel(o_sel),
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000),
        .bcd(w_bcd)
    );

    decoder_2to4 U_decoder(
        .btn(o_sel),
        .seg_comm(fnd_comm)
    );


     clk_divide U_clkdiv0(
         .clk(clk),
         .reset(reset),
         .o_clk(w_clk_400hz)
     );



endmodule




module bcdtoseg( // 4bit(0~15까지)입력으로 해서 출력을 (0~9) 디스플레이로 출력(이때는 8bit가 쓰임) 
    input [3:0] bcd,
    output reg [7:0] seg
);


    always@(bcd) begin // 대상(bcd)의 값의 변화를 추적
            case(bcd) 
                4'h0: seg=8'hc0;
                4'h1: seg=8'hf9;
                4'h2: seg=8'ha4;
                4'h3: seg=8'hb0; 
                4'h4: seg=8'h99;
                4'h5: seg=8'h92;
                4'h6: seg=8'h82;
                4'h7: seg=8'hf8;
                4'h8: seg=8'h80;
                4'h9: seg=8'h90;
                4'ha: seg=8'h88;
                4'hb: seg=8'h83;
                4'hc: seg=8'hc6;
                4'hd: seg=8'ha1; 
                4'he: seg=8'h86;
                4'hf: seg=8'h8e;
                default: seg = 8'hff;
            endcase

        end

endmodule


module decoder_2to4(
    input [1:0] btn,
    output reg [3:0] seg_comm
);

    always@(btn) begin
        case(btn)
            2'b00: seg_comm=4'b1110;
            2'b01: seg_comm=4'b1101;
            2'b10: seg_comm=4'b1011;
            2'b11: seg_comm=4'b0111;
            default: seg_comm=4'b1110;
        endcase
    end


endmodule


module digit_splitter #(parameter BIT_WIDTH = 16) (
    input [BIT_WIDTH - 1:0] bcd,
    output [3:0] digit_1,
    output [3:0] digit_10,
    output [3:0] digit_100,
    output [3:0] digit_1000
);
// 1의자리 ~ 1000의 자리
    assign digit_1 = bcd % 10;
    assign digit_10 = bcd / 10 % 10;
    assign digit_100 = bcd / 100 % 10;
    assign digit_1000 = bcd / 1000 % 10;

endmodule


module mux_4X1(
    input [1:0] sel,
    input [3:0] digit_1,
    input [3:0] digit_10,
    input [3:0] digit_100,
    input [3:0] digit_1000,
    output reg [3:0] bcd
);

// always 안에서는 assign x
// always 안에서 출력은 reg type
    always @(*) begin
        case(sel)
            2'b00: bcd = digit_1;
            2'b01: bcd = digit_10;
            2'b10: bcd = digit_100;
            2'b11: bcd = digit_1000;
            default: bcd = 4'bx;
        endcase

    end

endmodule

module counter_4(
    input clk,
    input reset,
    output reg [1:0] o_sel
);

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            o_sel <= 0;
        end

        else begin
            o_sel <= o_sel + 1;
        end

    end


endmodule


module clk_divide(
    input clk,
    input reset,
    output reg o_clk
);

    parameter FCOUNT = 250_000 ; //10hz

    reg [$clog2(FCOUNT)-1:0] r_counter; // log로 필요 bit 수 계산 가능


    always@(posedge clk, posedge reset) begin
        if(reset) begin
            r_counter <= 0;
            o_clk <= 1'b0;
        end

        else begin
            if (r_counter == FCOUNT - 1) begin  // 100Mhz를 100hz로
                r_counter <= 0;
                o_clk <= o_clk + 1;
            end
            else begin 
                r_counter <= r_counter + 1;
            end
        end 

    end

endmodule