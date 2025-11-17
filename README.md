# Serial_Communication_SPI_I2C

🔧 Serial Communication Project
SPI & I2C Build & Validation

👤 Author: 이동관
📅 2025-11-17

HARMAN System Semiconductor – SystemVerilog 기반 시리얼 통신 Master/Slave 설계 + Simulation + HW 검증 프로젝트


harman2_25_11_17--000

📌 Project Overview

본 프로젝트는 SPI / I2C 시리얼 통신 체계의 이해와 직접 구현,
그리고 Vivado Simulation, UVM Verification, 실제 FPGA 보드 간 통신 검증을 목표로 합니다.


harman2_25_11_17--000

🎯 Goals

SPI / I2C Master & Slave RTL 설계

Vivado 기반 Simulation & Logic Analyzer 실측 신호 분석

UVM 검증 환경 구성

Vitis C 프로그램을 통한 I2C HW 동작 검증


harman2_25_11_17--000

🧩 Architecture
🟦 SPI Block Diagram

4-Wire Communication: SCLK, MOSI, MISO, SS bar

Counter 모듈 데이터 송수신 반복


harman2_25_11_17--000

Simulation 결과

정상적인 8-bit 전송 검증

랜덤 데이터(예: 0x3E) 전송 확인 완료


harman2_25_11_17--000

기능	상세
통신 방식	Synchronous / Full-duplex
데이터 방향	Master <-> Slave
검증	Vivado Sim + 영상 데모
🟩 I2C Block Diagram

4개의 Register를 갖는 Slave

Address + R/W bit 처리

Write/Read 모두 MSB First


harman2_25_11_17--000

Simulation 결과

0xA0(Write) 정상 수신

Slave Registers(0~3) 데이터 저장 및 업데이트

Logic Analyzer 로 Read 확인


harman2_25_11_17--000

기능	상세
통신 방식	Synchronous / Half-duplex
Addressing	7-bit Address + R/W bit
검증	Vivado Sim + Saleae Logic + Vitis
🧪 Verification Environment
항목	SPI	I2C
Simulation	Vivado	Vivado
HW Debug	FPGA 보드 2대 연결	Saleae Logic Analyzer
Additional	UART 기반 Debug 연결	Vitis C 코드
UVM 적용	✔️	✔️
🚧 Trouble Shooting & Fixes
Issue	Cause	Solution
I2C Master가 READ 상태로 진입 못함	FSM 처리 오류	상태 분기 조건 수정
Read 시 FF 값 수신	마지막 비트 처리 문제	bit_cnt == 0 일 때 shift 금지


harman2_25_11_17--000

		
🙌 Retrospective (Thought)

Master / Slave 단일 설계보다 연동 단계에서 복잡도가 급증

작은 실수도 CRC, ACK 등 신뢰성 문제 발생 → 정밀한 디버깅 필요

협업한다면 통신 프로토콜/인터페이스 명세 공유의 필수성 체감

향후 개선:

Multi-Byte Read/Write 구조 확장 계획


harman2_25_11_17--000

📁 Project Structure (예시)
📦 serial-communication
├── spi/
│   ├── spi_master.sv
│   ├── spi_slave.sv
│   ├── tb_spi.sv
│   └── uvm_env_spi/
├── i2c/
│   ├── i2c_master.sv
│   ├── i2c_slave.sv
│   ├── tb_i2c.sv
│   └── uvm_env_i2c/
├── docs/
│   └── presentation.pdf  # 발표 자료
└── README.md

🎥 Demo & Results
항목	링크
SPI HW Demo 영상	(추가 예정)
I2C HW Demo 영상	(추가 예정)
Simulation Waveforms	포함 완료
🌱 Future Work

I2C Multi-Byte Burst Transfer

Error Handling / Repeated START / Timing Margin 개선

UVM Coverage Refine

AXI Bus Wrapper 연동

🏷 Skills Used

SystemVerilog RTL Design

Vivado Simulation & ILA Debug

Saleae Logic 2 분석

UVM Verification

FPGA SoC Firmware (Vitis)

📞 Contact

이동관 (DongGwan Lee)
Email: (원하면 추가)
GitHub: 추가 예정 링크
