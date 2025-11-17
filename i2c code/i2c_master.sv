`timescale 1ns / 1ps

module I2C_master_ver1_5_v (
    // global signals
    input  wire       clk,
    input  wire       reset,
    // control
    input  wire       i2c_en,
    input  wire       i2c_start,
    input  wire       i2c_stop,
    // write path
    input  wire [7:0] tx_data,
    output wire       tx_done,
    output wire       tx_ready,
    // read path
    output wire [7:0] rx_data,
    output wire       rx_done,
    // external
    output wire       scl,
    inout  tri        sda
);

    // =============================
    // 내부 레지스터/와이어
    // =============================
    reg addr_phase, addr_phase_next;   // 1이면 '주소 바이트' 단계
    reg rw_mode,   rw_mode_next;       // 0=Write, 1=Read (주소 바이트 LSB)

    reg tx_done_reg,  tx_done_next;
    reg tx_ready_reg, tx_ready_next;
    reg rx_done_reg,  rx_done_next;
    reg scl_reg,      scl_next;

    reg [7:0] rx_data_reg,   rx_data_next;
    reg [7:0] tx_data_reg,   tx_data_next;
    reg [7:0] rx_shift_reg,  rx_shift_next;
    reg [8:0] clk_count_reg, clk_count_next;
    reg [2:0] bit_cnt_reg,   bit_cnt_next;

    // SDA 오픈드레인 제어
    reg sda_oe,  sda_oe_next;
    reg sda_out, sda_out_next;

    assign sda      = (sda_oe) ? sda_out : 1'bz;
    assign rx_data  = rx_data_reg;

    assign tx_done  = tx_done_reg;
    assign tx_ready = tx_ready_reg;
    assign rx_done  = rx_done_reg;
    assign scl      = scl_reg;

    // 상태 인코딩 (5비트)
    localparam [4:0]
        IDLE   = 5'd0,
        START_1= 5'd1,
        START_2= 5'd2,
        DATA_1 = 5'd3,
        DATA_2 = 5'd4,
        DATA_3 = 5'd5,
        DATA_4 = 5'd6,
        ACK_1  = 5'd7,
        ACK_2  = 5'd8,
        ACK_3  = 5'd9,
        ACK_4  = 5'd10,
        HOLD   = 5'd11,
        RX_1   = 5'd12,
        RX_2   = 5'd13,
        RX_3   = 5'd14,
        RX_4   = 5'd15,
        MACK_1 = 5'd16,
        MACK_2 = 5'd17,
        MACK_3 = 5'd18,
        MACK_4 = 5'd19,
        STOP1  = 5'd20,
        STOP2  = 5'd21;

    reg [4:0] state, state_next;

    // =============================
    // 순차 로직
    // =============================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state         <= IDLE;
            tx_data_reg   <= 8'h00;
            rx_shift_reg  <= 8'h00;
            clk_count_reg <= 9'd0;
            bit_cnt_reg   <= 3'd0;
            addr_phase    <= 1'b1;  // IDLE 이후 첫 바이트는 주소부터
            rw_mode       <= 1'b0;
            rx_data_reg   <= 8'h00;

            tx_done_reg   <= 1'b0;
            tx_ready_reg  <= 1'b0;
            rx_done_reg   <= 1'b0;
            scl_reg       <= 1'b0;

            sda_oe        <= 1'b0;
            sda_out       <= 1'b0;
        end else begin
            state         <= state_next;
            tx_data_reg   <= tx_data_next;
            rx_shift_reg  <= rx_shift_next;
            clk_count_reg <= clk_count_next;
            bit_cnt_reg   <= bit_cnt_next;
            addr_phase    <= addr_phase_next;
            rw_mode       <= rw_mode_next;
            rx_data_reg   <= rx_data_next;

            tx_done_reg   <= tx_done_next;
            tx_ready_reg  <= tx_ready_next;
            rx_done_reg   <= rx_done_next;
            scl_reg       <= scl_next;

            sda_oe        <= sda_oe_next;
            sda_out       <= sda_out_next;
        end
    end

    // =============================
    // 조합 로직 (상태기계)
    // =============================
    always @(*) begin
        // 기본값 (hold)
        state_next      = state;
        tx_data_next    = tx_data_reg;
        rx_shift_next   = rx_shift_reg;
        clk_count_next  = clk_count_reg;
        bit_cnt_next    = bit_cnt_reg;
        addr_phase_next = addr_phase;
        rw_mode_next    = rw_mode;
        rx_data_next    = rx_data_reg;

        tx_done_next    = tx_done_reg;
        tx_ready_next   = tx_ready_reg;
        rx_done_next    = 1'b0;      // rx_done은 펄스로 사용
        scl_next        = scl_reg;

        sda_oe_next     = 1'b0;
        sda_out_next    = 1'b0;

        case (state)
            // ------------------------------------------------
            IDLE: begin
                sda_oe_next     = 1'b1;
                sda_out_next    = 1'b1;
                scl_next        = 1'b1;
                tx_ready_next   = 1'b0;
                tx_done_next    = 1'b0;
                addr_phase_next = 1'b1;  // 항상 주소부터
                if (i2c_en) begin
                    // enable 되면 HOLD에서 start 기다림
                    clk_count_next = 9'd0;
                    bit_cnt_next   = 3'd7;
                    state_next     = HOLD;
                end
            end

            // ------------------------------------------------
            // START
            START_1: begin
                sda_oe_next  = 1'b1;
                sda_out_next = 1'b0;  // SDA low (while SCL high)
                scl_next     = 1'b1;
                if (clk_count_reg == 9'd499) begin
                    clk_count_next = 9'd0;
                    state_next     = START_2;
                end else clk_count_next = clk_count_reg + 1'b1;
            end

            START_2: begin
                sda_oe_next  = 1'b1;
                sda_out_next = 1'b0;
                scl_next     = 1'b0;
                if (clk_count_reg == 9'd499) begin
                    clk_count_next = 9'd0;
                    if (rw_mode == 0) begin
                        state_next     = DATA_1;
                    end else begin
                        state_next     = RX_1; 
                    end 
                    
                end else clk_count_next = clk_count_reg + 1'b1;
            end

            // ------------------------------------------------
            // WRITE 1비트 (4단)
            DATA_1: begin  // SCL Low, SDA에 비트 세팅
                if (tx_data_reg[7] == 1'b0) begin
                    sda_oe_next  = 1'b1;
                    sda_out_next = 1'b0;
                end else begin
                    sda_oe_next  = 1'b0; // Z
                end
                tx_ready_next = 1'b0;
                scl_next      = 1'b0;

                if (clk_count_reg == 9'd249) begin
                    clk_count_next = 9'd0;
                    state_next     = DATA_2;
                end else clk_count_next = clk_count_reg + 1'b1;
            end

            DATA_2: begin  // SCL High (샘플링)
                if (tx_data_reg[7] == 1'b0) begin
                    sda_oe_next  = 1'b1;
                    sda_out_next = 1'b0;
                end else begin
                    sda_oe_next  = 1'b0;
                end
                scl_next = 1'b1;

                if (clk_count_reg == 9'd249) begin
                    clk_count_next = 9'd0;
                    state_next     = DATA_3;
                end else clk_count_next = clk_count_reg + 1'b1;
            end

            DATA_3: begin  // SCL High 유지
                if (tx_data_reg[7] == 1'b0) begin
                    sda_oe_next  = 1'b1;
                    sda_out_next = 1'b0;
                end else begin
                    sda_oe_next  = 1'b0;
                end
                scl_next = 1'b1;

                if (clk_count_reg == 9'd249) begin
                    clk_count_next = 9'd0;
                    state_next     = DATA_4;
                end else clk_count_next = clk_count_reg + 1'b1;
            end

            DATA_4: begin  // SCL Low, 쉬프트
                if (tx_data_reg[7] == 1'b0) begin
                    sda_oe_next  = 1'b1;
                    sda_out_next = 1'b0;
                end else begin
                    sda_oe_next  = 1'b0;
                end
                scl_next = 1'b0;

                if (clk_count_reg == 9'd249) begin
                    clk_count_next = 9'd0;
                    tx_data_next   = {tx_data_reg[6:0], 1'b0};
                    if (bit_cnt_reg == 3'd0) begin
                        bit_cnt_next = 3'd7;
                        state_next   = ACK_1;
                    end else begin
                        bit_cnt_next = bit_cnt_reg - 3'd1;
                        state_next   = DATA_1;
                    end
                end else clk_count_next = clk_count_reg + 1'b1;
            end

            // ------------------------------------------------
            // SLAVE ACK 읽기 (SDA 입력, SCL High에서 샘플)
            ACK_1: begin  // 준비: SCL Low, SDA Hi-Z
                sda_oe_next = 1'b0;
                scl_next    = 1'b0;
                if (clk_count_reg == 9'd249) begin
                    clk_count_next = 9'd0;
                    state_next     = ACK_2;
                end else clk_count_next = clk_count_reg + 1'b1;
            end

            ACK_2: begin  // SCL High
                sda_oe_next = 1'b0;
                scl_next    = 1'b1;
                if (clk_count_reg == 9'd249) begin
                    clk_count_next = 9'd0;
                    state_next     = ACK_3;
                end else clk_count_next = clk_count_reg + 1'b1;
            end

            ACK_3: begin  // 유지
                sda_oe_next = 1'b0;
                scl_next    = 1'b1;
                if (clk_count_reg == 9'd249) begin
                    clk_count_next = 9'd0;
                    state_next     = ACK_4;
                end else clk_count_next = clk_count_reg + 1'b1;
            end

            ACK_4: begin  // 완료: SCL Low
                sda_oe_next = 1'b0;
                scl_next    = 1'b0;
                if (clk_count_reg == 9'd249) begin
                    clk_count_next = 9'd0;
                    tx_done_next   = 1'b1;

                    if (addr_phase) begin
                        // 방금 보낸 건 주소 바이트
                        addr_phase_next = 1'b0;
                        // ★ 여기서 tx_data_reg[0] 쓰지 않고, 이미 저장된 rw_mode 사용
                        if (rw_mode) begin
                            // READ 모드 → 바로 슬레이브 데이터 읽기 시작
                            state_next = RX_1;
                        end else begin
                            // WRITE 모드 → HOLD에서 데이터 바이트 대기
                            state_next = HOLD;
                        end
                    end else begin
                        // 방금 보낸 건 데이터 바이트
                        addr_phase_next = 1'b1;   // 다음에는 다시 주소 바이트
                        state_next      = HOLD;
                    end
                end else clk_count_next = clk_count_reg + 1'b1;
            end

            // ------------------------------------------------
            // 다음 액션 판단
            HOLD: begin
                sda_oe_next   = 1'b1;
                sda_out_next  = 1'b1;
                scl_next      = 1'b0;
                tx_ready_next = 1'b1;
                tx_done_next  = 1'b0;

                clk_count_next = 9'd0;

                // 1) START + 주소 바이트
                if (i2c_start && !i2c_stop && addr_phase) begin
                    // tx_data : 주소 + R/W
                    tx_data_next    = tx_data;
                    bit_cnt_next    = 3'd7;
                    addr_phase_next = 1'b1;           // 지금 보내는 건 주소
                    rw_mode_next    = tx_data[0];     // ★ 여기서 R/W 비트 저장
                    tx_ready_next   = 1'b0;
                    state_next      = START_1;

                // 2) WRITE 모드에서 데이터 바이트 전송 (START 펄스를 "데이터 전송" 요청으로 사용)
                end else if (i2c_start && !i2c_stop && !addr_phase && !rw_mode) begin
                    tx_data_next    = tx_data;
                    bit_cnt_next    = 3'd7;
                    tx_ready_next   = 1'b0;
                    // 실제 I2C START는 발생시키지 않음 → 슬레이브는 A2 뒤에 바로 데이터로 인식
                    state_next      = DATA_1;

                // 3) STOP 요청
                end else if (!i2c_start && i2c_stop) begin
                    state_next = STOP1;

                end
                // else : 아무 것도 안 하면서 다음 명령 대기
            end


            // ------------------------------------------------
            // READ 1비트 (4단)
            RX_1: begin  // SCL Low, 다음 비트 준비
                sda_oe_next = 1'b0;
                scl_next    = 1'b0;
                if (clk_count_reg == 9'd249) begin
                    clk_count_next = 9'd0;
                    state_next     = RX_2;
                end else clk_count_next = clk_count_reg + 1'b1;
            end

            RX_2: begin  // SCL High 진입: 샘플링 타이밍
                sda_oe_next = 1'b0;
                scl_next    = 1'b1;
                if (clk_count_reg == 9'd124) begin
                    rx_shift_next = {rx_shift_reg[6:0], sda};
                end
                if (clk_count_reg == 9'd249) begin
                    clk_count_next = 9'd0;
                    state_next     = RX_3;
                end else clk_count_next = clk_count_reg + 1'b1;
            end

            RX_3: begin  // SCL High 유지
                sda_oe_next = 1'b0;
                scl_next    = 1'b1;
                if (clk_count_reg == 9'd249) begin
                    clk_count_next = 9'd0;
                    state_next     = RX_4;
                end else clk_count_next = clk_count_reg + 1'b1;
            end

            RX_4: begin  // SCL Low, 비트 카운트 처리
                sda_oe_next = 1'b0;
                scl_next    = 1'b0;
                if (clk_count_reg == 9'd249) begin
                    clk_count_next = 9'd0;
                    if (bit_cnt_reg == 3'd0) begin
                        rx_data_next = rx_shift_reg;
                        bit_cnt_next = 3'd7;
                        state_next   = MACK_1;  // 마지막 바이트 NACK
                    end else begin
                        bit_cnt_next = bit_cnt_reg - 3'd1;
                        state_next   = RX_1;
                    end
                end else clk_count_next = clk_count_reg + 1'b1;
            end

            // ------------------------------------------------
            // Master NACK (마지막 바이트 가정)
            MACK_1: begin  // SCL Low, NACK('1') 준비 = release
                sda_oe_next  = 1'b1;
                sda_out_next = 1'b0;
                scl_next     = 1'b0;
                if (clk_count_reg == 9'd249) begin
                    clk_count_next = 9'd0;
                    state_next     = MACK_2;
                end else clk_count_next = clk_count_reg + 1'b1;
            end

            MACK_2: begin  // SCL High (슬레이브가 NACK 감지)
                sda_oe_next  = 1'b1;    // drive HIGH
                sda_out_next = 1'b1;
                scl_next     = 1'b1;
                scl_next     = 1'b1;
                if (clk_count_reg == 9'd249) begin
                    clk_count_next = 9'd0;
                    state_next     = MACK_3;
                end else clk_count_next = clk_count_reg + 1'b1;
            end

            MACK_3: begin  // 유지
                sda_oe_next  = 1'b1;
                sda_out_next = 1'b1;
                scl_next     = 1'b1;
                if (clk_count_reg == 9'd249) begin
                    clk_count_next = 9'd0;
                    state_next     = MACK_4;
                end else clk_count_next = clk_count_reg + 1'b1;
            end

            MACK_4: begin  // SCL Low, rx_done 펄스
                sda_oe_next  = 1'b0;    // release
                scl_next     = 1'b0;
                if (clk_count_reg == 9'd249) begin
                    clk_count_next = 9'd0;
                    rx_done_next   = 1'b1;
                    addr_phase_next= 1'b1;  // 다음에 다시 주소부터
                    rw_mode_next   = 1'b0;
                    state_next     = HOLD;
                end else clk_count_next = clk_count_reg + 1'b1;
            end

            // ------------------------------------------------
            // STOP
            STOP1: begin
                sda_oe_next   = 1'b1;
                sda_out_next  = 1'b0;
                scl_next      = 1'b1;
                tx_ready_next = 1'b0;
                tx_done_next  = 1'b0;
                if (clk_count_reg == 9'd499) begin
                    clk_count_next = 9'd0;
                    state_next     = STOP2;
                end else clk_count_next = clk_count_reg + 1'b1;
            end

            STOP2: begin
                sda_oe_next   = 1'b1;
                sda_out_next  = 1'b1;
                scl_next      = 1'b1;
                tx_ready_next = 1'b0;
                tx_done_next  = 1'b0;
                if (clk_count_reg == 9'd499) begin
                    clk_count_next = 9'd0;
                    state_next     = IDLE;
                end else clk_count_next = clk_count_reg + 1'b1;
            end
        endcase
    end

endmodule
