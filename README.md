# Serial_Communication_SPI_I2C

# 🔧 Serial Communication Project  
### SPI & I2C Build & Validation  
👤 **Author: 이동관**  
📅 **2025-11-17**

> HARMAN System Semiconductor – SystemVerilog 기반 시리얼 통신  
> Master/Slave 설계 + Simulation + HW 검증 프로젝트

---

## 📌 Project Overview
본 프로젝트는 **SPI / I2C 시리얼 통신 체계**를 직접 설계하고  
**Vivado Simulation & FPGA HW 테스트**를 통해 동작을 검증하는 것을 목표로 합니다.

### 🎯 Goals
- SPI / I2C **Master & Slave RTL 설계**
- Vivado 기반 Simulation & Logic Analyzer 실측 데이터 분석
- UVM Testbench 구성 및 기능 검증
- Vitis C 프로그램 기반 실동작 확인

---

## 🧩 Architecture

### 🟦 SPI Block Diagram
- SCLK, MOSI, MISO, SS_bar 4-Line 통신
- Counter 모듈 데이터를 Master에서 Slave로 반복 전송
- 8bit MSB First 전송

**Simulation Result**
- 데이터 전송 정상 동작 확인
- 랜덤 데이터(예: `0x3E`) 수신 확인

| 기능 | 상세 |
|------|------|
| 통신 방식 | Synchronous / Full-duplex |
| 데이터 방향 | Master ↔ Slave |
| 검증 | Vivado Simulation |

---

### 🟩 I2C Block Diagram
- 7bit Slave Address + R/W bit
- Slave 내부 4개의 Register에 데이터 Read/Write 가능
- MSB First 전송 / 수신

**Simulation Result**
- `0xA0` Write 정상 수신 → Register 저장 확인
- Read 시 Logic Analyzer로 데이터 검증 완료

| 기능 | 상세 |
|------|-----|
| 통신 방식 | Synchronous / Half-duplex |
| 검증 방식 | Vivado + Saleae Logic Analyzer + Vitis FW |

---

## 🧪 Verification Environment

| 항목 | SPI | I2C |
|------|-----|-----|
| Simulation | Vivado | Vivado |
| HW Test | FPGA 보드 2대 연결 | Logic Analyzer 사용 |
| Software Control | - | Vitis C 코드 |
| UVM 적용 | ✔️ | ✔️ |

---

## 🚧 Trouble Shooting

| Issue | Cause | Fix |
|------|------|-----|
| READ State 진입 실패 | FSM 분기 조건 문제 | 상태 조건 로직 수정 |
| Read 시 FF 값 수신 | 마지막 비트 처리 오류 | bit_cnt == 0 shift 방지 |

---

## 🙌 Retrospective
- Master, Slave 개별 구현은 수월했지만 **연동 단계에서 디버깅 난이도 급상승**
- HW 통신 특성상 **작은 타이밍 오류**도 전체 동작에 영향
- 협업 시 **인터페이스 명세 & 신호 공유가 매우 중요**하다는 점 체감  
- 향후 개선 예정:
  - Multi-Byte 전송 구조 확장
  - 다양한 Error Handling 추가

---

## 📁 Project Structure (예시)
```bash
📦 serial-communication
├── spi/
│   ├── spi_master.sv
│   ├── spi_slave.sv
│   ├── tb_spi.sv
│   └── uvm_spi/
├── i2c/
│   ├── i2c_master.sv
│   ├── i2c_slave.sv
│   ├── tb_i2c.sv
│   └── uvm_i2c/
├── docs/
│   └── presentation.pdf
└── README.md

