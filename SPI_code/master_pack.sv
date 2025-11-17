`timescale 1ns / 1ps

module master_pack (
    //global signal
    input  logic       clk,
    input  logic       reset,
    input  logic       clear,
    input  logic       run_stop,
    
    //external ports
    output logic       sclk,
    output logic       mosi,
    input  logic       miso,
    output logic       ss_bar
);
    //internal signals
    logic       start;
    logic [7:0] tx_data;
    logic [7:0] rx_data;
    logic       tx_ready;
    logic       done;

    control_unit_master U_control_unit_master(
        .clk      (clk),
        .reset    (reset),
        .run_stop (run_stop),
        .clear    (clear),
        .tx_data  (tx_data),
        .start    (start),
        .ready    (tx_ready),
        .done     (done),
        .ss_bar   (ss_bar)
    );

    spi_master U_spi_master (
        //global signal
        .clk      (clk),
        .reset    (reset),
        //internal signals
        .start    (start),
        .tx_data  (tx_data),
        .rx_data  (rx_data),
        .tx_ready (tx_ready),
        .done     (done),
        //external ports
        .sclk     (sclk),
        .mosi     (mosi),
        .miso     (miso)
    );

endmodule

/*
module control_unit_master (
    //interal signals
    input logic clk,
    input logic reset,
    input logic run_stop,
    input logic clear,
    //external ports
    output logic [7:0] tx_data,
    output logic       start,
    input  logic       ready,
    input  logic       done,
    output logic       ss_bar
);
    logic tick;
    logic [15:0] o_counter;
    logic [7:0] tx_data_reg, tx_data_next;
    logic [15:0] o_counter_reg, o_counter_next;

    assign tx_data = tx_data_reg;
    
    typedef enum { IDLE, SEND_LOW, WAIT, SEND_HIGH } state_e;

    state_e state, state_next;

    clk_tick_gen_10hz U_tick_gen(
        .clk_in    (clk),
        .reset     (reset),
        .run_stop  (run_stop),
        .clear     (clear),
        .tick_10hz (tick)
    );

    counter_10000 U_counter_10000(
        .clk       (clk),
        .reset     (reset),
        .clear     (clear),
        .tick      (tick),
        .o_counter (o_counter)
    );

    always_ff @( posedge clk, posedge reset ) begin
        if (reset) begin
            state <= IDLE;
            tx_data_reg <= 0;
            o_counter_reg <= 0;
        end else begin
            state <= state_next;
            tx_data_reg <= tx_data_next;
            o_counter_reg <= o_counter_next;
        end
    end

    always_comb begin
        state_next = state;
        tx_data_next = tx_data_reg;
        o_counter_next = o_counter_reg;
        case (state)
            IDLE     : begin
                start = 1'b0;
                if (ready) begin
                    state_next = SEND_LOW;
                    o_counter_next = o_counter;
                end
            end
            SEND_LOW : begin
                start = 1'b1;
                tx_data_next = o_counter_reg[7:0];
                if (done) begin
                    state_next = WAIT;
                end
            end
            WAIT: begin
                start = 1'b0;
                if (ready) begin
                    state_next = SEND_HIGH;
                end
            end
            SEND_HIGH: begin
                start = 1'b1;
                tx_data_next = o_counter_reg[15:8];
                if (done) begin
                    state_next = IDLE;
                end
            end  
        endcase
    end

endmodule
*/

module control_unit_master (
    input  logic       clk,
    input  logic       reset,
    input  logic       run_stop,
    input  logic       clear,
    output logic [7:0] tx_data,
    output logic       start,
    input  logic       ready,
    input  logic       done,
    output logic       ss_bar
);
    logic tick;
    logic [15:0] o_counter;
    logic [7:0]  tx_data_reg, tx_data_next;
    logic [15:0] o_counter_reg, o_counter_next;

    // SS_n 레지스터
    logic ss_n_reg, ss_n_next;
    assign ss_bar  = ss_n_reg;
    assign tx_data = tx_data_reg;

    typedef enum logic [1:0] { IDLE, SEND_LOW, WAIT, SEND_HIGH } state_e;
    state_e state, state_next;

    // ... tick/counter 인스턴스 동일 ...
    clk_tick_gen_10hz U_tick_gen(
        .clk_in    (clk),
        .reset     (reset),
        .run_stop  (run_stop),
        .clear     (clear),
        .tick_10hz (tick)
    );

    counter_10000 U_counter_10000(
        .clk       (clk),
        .reset     (reset),
        .clear     (clear),
        .tick      (tick),
        .o_counter (o_counter)
    );
    // 상태/데이터/카운터/SS 레지스터
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state         <= IDLE;
            tx_data_reg   <= '0;
            o_counter_reg <= '0;
            ss_n_reg      <= 1'b1;   // 유휴 시 HIGH
        end else begin
            state         <= state_next;
            tx_data_reg   <= tx_data_next;
            o_counter_reg <= o_counter_next;
            ss_n_reg      <= ss_n_next;
        end
    end

    always_comb begin
        // 기본 유지
        state_next       = state;
        tx_data_next     = tx_data_reg;
        o_counter_next   = o_counter_reg;
        start            = 1'b0;
        ss_n_next        = ss_n_reg;

        unique case (state)
            IDLE: begin
                ss_n_next = 1'b1;           // 유휴 HIGH
                if (ready) begin
                    // 전송 시작: SS 낮추고 카운터 샘플링
                    ss_n_next      = 1'b0;  // <= 여기서 Slave 선택
                    o_counter_next = o_counter;
                    state_next     = SEND_LOW;
                end
            end

            SEND_LOW: begin
                start        = 1'b1;                    // 바이트 전송 트리거
                tx_data_next = o_counter_reg[7:0];
                ss_n_next    = 1'b0;                    // 전송 중 유지
                if (done)    state_next = WAIT;
            end

            WAIT: begin
                start     = 1'b0;
                ss_n_next = 1'b0;                       // 멀티바이트 유지
                if (ready) state_next = SEND_HIGH;
            end

            SEND_HIGH: begin
                start        = 1'b1;
                tx_data_next = o_counter_reg[15:8];
                ss_n_next    = 1'b0;                    // 전송 중 유지
                if (done) begin
                    ss_n_next  = 1'b1;                  // 마지막 바이트 완료 → 해제
                    state_next = IDLE;
                end
            end
        endcase
    end
endmodule


module counter_10000(
    input  logic        clk,
    input  logic        reset,
    input  logic        clear,
    input  logic        tick,
    output logic [15:0] o_counter
);

    reg[$clog2(10000)-1:0] c_counter, n_counter;
    assign o_counter = c_counter;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_counter <= 0;
        end else begin
            c_counter <= n_counter;
        end    
    end

    always @(*) begin
        n_counter = c_counter;
        if (tick) begin
            if (c_counter == (10000 - 1)) begin
                n_counter = 0;
            end else n_counter = c_counter + 1;
        end else if (clear) begin
            n_counter = 0;
        end

    end

endmodule

module clk_tick_gen_10hz(
    input  logic clk_in,
    input  logic reset,
    input  logic run_stop,
    input  logic clear,
    output logic tick_10hz
);

    parameter DIV = 10_000_000;
    localparam WIDTH = $clog2(DIV);
    reg[WIDTH-1:0] r_count;

    always @(posedge clk_in, posedge reset) begin
        if (reset) begin
            r_count <= 0;
            tick_10hz <= 1'b0;
        end else begin
            if (run_stop) begin
                if (r_count == DIV - 1) begin
                    r_count <= 0;
                    tick_10hz <= 1'b1;
                end else begin
                    r_count <= r_count +1;
                    tick_10hz <= 1'b0;
                end   
            end else if (clear) begin
                r_count <= 0;
            end
        end
    end

endmodule