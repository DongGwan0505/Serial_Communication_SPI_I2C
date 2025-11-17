`timescale 1ns/1ps

module I2C_Slave_Formal #(
    parameter SLAVE_ADDR = 7'h51
)(
    input  wire clk,     // 시스템 clk (비동기 입력 동기화용)
    input  wire reset,

    input  wire SCL,
    inout  wire SDA,

    output reg [7:0] slv_reg0,
    output reg [7:0] slv_reg1,
    output reg [7:0] slv_reg2,
    output reg [7:0] slv_reg3
);

    //-----------------------------------------
    // Open-drain SDA
    //-----------------------------------------
    reg sda_drive;
    assign SDA = sda_drive ? 1'b0 : 1'bz;
    wire sda_in = SDA;

    //-----------------------------------------
    // SCL/SDA 동기화
    //-----------------------------------------
    reg scl_r1, scl_r2;
    reg sda_r1, sda_r2;

    always @(posedge clk) begin
        scl_r1 <= SCL;
        scl_r2 <= scl_r1;

        sda_r1 <= SDA;
        sda_r2 <= sda_r1;
    end

    wire scl = scl_r2;
    wire sda = sda_r2;

    //-----------------------------------------
    // Edge detect on SCL
    //-----------------------------------------
    reg scl_prev;
    always @(posedge clk) scl_prev <= scl;

    wire scl_pos = (scl_prev == 0 && scl == 1);
    wire scl_neg = (scl_prev == 1 && scl == 0);

    //-----------------------------------------
    // START & STOP detect
    //-----------------------------------------
    reg sda_prev;
    always @(posedge clk) sda_prev <= sda;

    wire start_cond = (sda_prev == 1 && sda == 0 && scl == 1);
    wire stop_cond  = (sda_prev == 0 && sda == 1 && scl == 1);

    //-----------------------------------------
    // FSM state
    //-----------------------------------------
    typedef enum logic [3:0] {
        IDLE,
        ADDR,
        ADDR_ACK,
        WRITE_DATA,
        WRITE_ACK,
        READ_DATA,
        READ_WAIT_ACK
    } state_t;

    state_t state, state_next;

    //-----------------------------------------
    // Registers
    //-----------------------------------------
    reg [7:0] rx_shift, rx_shift_next;
    reg [7:0] tx_shift, tx_shift_next;

    reg [3:0] bit_cnt, bit_cnt_next;

    reg rw_bit, rw_bit_next;    // 0 = write, 1 = read

    // 포인터
    reg [1:0] wr_ptr, wr_ptr_next;
    reg [1:0] rd_ptr, rd_ptr_next;

    reg sda_drive_next_ACK;
    reg sda_drive_next_TX;

    //-----------------------------------------
    // Sequential
    //-----------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state     <= IDLE;
            bit_cnt   <= 4'd8;
            rx_shift  <= 8'h00;
            tx_shift  <= 8'h00;
            sda_drive <= 1'b0;

            wr_ptr    <= 2'd0;
            rd_ptr    <= 2'd0;

            slv_reg0  <= 8'h00;
            slv_reg1  <= 8'h00;
            slv_reg2  <= 8'h00;
            slv_reg3  <= 8'h00;

            rw_bit    <= 1'b0;
        end else begin
            state     <= state_next;
            bit_cnt   <= bit_cnt_next;
            rx_shift  <= rx_shift_next;
            tx_shift  <= tx_shift_next;
            rw_bit    <= rw_bit_next;

            wr_ptr    <= wr_ptr_next;
            rd_ptr    <= rd_ptr_next;

            // 다음 상태 기준으로 SDA 드라이브 결정
            sda_drive <= (state_next == ADDR_ACK || state_next == WRITE_ACK) ?
                         (sda_drive_next_ACK) :
                         (state_next == READ_DATA) ?
                         (sda_drive_next_TX) :
                         1'b0;
        end
    end

    //-----------------------------------------
    // Combinational FSM
    //-----------------------------------------
    always @(*) begin
        state_next = state;

        bit_cnt_next   = bit_cnt;
        rx_shift_next  = rx_shift;
        tx_shift_next  = tx_shift;
        rw_bit_next    = rw_bit;

        wr_ptr_next = wr_ptr;
        rd_ptr_next = rd_ptr;

        sda_drive_next_ACK = 1'b0;
        sda_drive_next_TX  = sda_drive;   // 기본: 직전값 유지

        case (state)

        //-----------------------------------------
        // IDLE
        //-----------------------------------------
        IDLE: begin
            if (start_cond) begin
                bit_cnt_next  = 4'd8;
                rx_shift_next = 8'h00;
                state_next    = ADDR;
            end
        end

        //-----------------------------------------
        // 주소 수신
        //-----------------------------------------
        ADDR: begin
            if (scl_pos) begin
                rx_shift_next <= {rx_shift[6:0], sda};
                if (bit_cnt != 0)
                    bit_cnt_next = bit_cnt - 1;
            end

            if (bit_cnt == 0 && scl_neg)
                state_next = ADDR_ACK;
        end

        //-----------------------------------------
        // Address ACK
        //-----------------------------------------
        ADDR_ACK: begin
            sda_drive_next_ACK = 1'b1; // ACK

            if (scl_pos) begin
                if (rx_shift[7:1] == SLAVE_ADDR) begin
                    rw_bit_next = rx_shift[0];

                    if (rx_shift[0] == 1'b0) begin
                        // WRITE 모드
                        bit_cnt_next  = 4'd8;
                        rx_shift_next = 8'h00;
                        state_next    = WRITE_DATA;
                    end else begin
                        // READ 모드: 첫 바이트 준비
                        bit_cnt_next  = 4'd8;  // MSB index

                        case (rd_ptr)
                            2'd0: tx_shift_next = slv_reg0;
                            2'd1: tx_shift_next = slv_reg1;
                            2'd2: tx_shift_next = slv_reg2;
                            2'd3: tx_shift_next = slv_reg3;
                        endcase

                        state_next = READ_DATA;
                    end
                end else begin
                    state_next = IDLE;
                end
            end
        end

        //-----------------------------------------
        // WRITE: data 수신
        //-----------------------------------------
        WRITE_DATA: begin
            if (scl_pos) begin
                rx_shift_next <= {rx_shift[6:0], sda};
                if (bit_cnt != 0)
                    bit_cnt_next = bit_cnt - 1;
            end
            if (bit_cnt == 0 && scl_neg)
                state_next = WRITE_ACK;
        end

        //-----------------------------------------
        // WRITE ACK + 저장
        //-----------------------------------------
        WRITE_ACK: begin
            sda_drive_next_ACK = 1'b1;

            if (scl_pos) begin
                case (wr_ptr)
                    2'd0: slv_reg0 = rx_shift;
                    2'd1: slv_reg1 = rx_shift;
                    2'd2: slv_reg2 = rx_shift;
                    2'd3: slv_reg3 = rx_shift;
                endcase

                wr_ptr_next = wr_ptr + 1;

                state_next = IDLE;
            end
        end

        //-----------------------------------------
        // READ: 마스터로 전송
        //-----------------------------------------
        READ_DATA: begin

            // SDA 출력은 항상 SCL LOW에서만 결정
            if (!scl) begin
                sda_drive_next_TX = (tx_shift[7] == 1'b0);
            end

            // --- SCL rising: 비트 샘플 후 쉬프트 ---
            if (scl_pos) begin
                if (bit_cnt != 0) begin
                    // 정상 shift
                    tx_shift_next = {tx_shift[6:0], 1'b0};
                    bit_cnt_next  = bit_cnt - 1;

                end else begin
                    // bit_cnt == 0 → 마지막 비트 처리
                    // ❌ 여기서 절대 shift 하면 안됨
                    // ACK 비트로 넘어가기
                    state_next = READ_WAIT_ACK;
                end
            end
        end

        //-----------------------------------------
        // READ ACK from master
        //-----------------------------------------
        READ_WAIT_ACK: begin
            // SDA는 항상 release
            sda_drive_next_TX = 1'b0;

            if (scl_pos) begin
                // 무조건 종료
                rd_ptr_next = rd_ptr + 1;   // 다음 read부터 다음 레지스터
                state_next  = IDLE;
            end
        end
        endcase
    end

endmodule
