`timescale 1ns / 1ps

module FPGA_sim(
    input logic clk,
    input logic reset,
    input logic clear,
    input logic run_stop,
    output logic [7:0] fnd_font,
    output logic [3:0] fnd_comm
);

logic       sclk;
logic       mosi;
logic       miso;
logic       ss_bar;

master_pack U_master_pack(
    //global signal
    .clk   (clk),
    .reset (reset),
    .clear (clear),
    .run_stop(run_stop),
    
    //external ports
    .sclk   (sclk),
    .mosi   (mosi),
    .miso   (miso),
    .ss_bar (ss_bar)
);

slave_pack U_slave_pack(
    .clk  (clk),   // 내부 동기 클럭(예: 100MHz)
    .reset(reset),

    // SPI pins
    .SCLK (sclk),  // 외부 SPI SCLK
    .MOSI (mosi),
    .MISO (miso),  // 현재 미사용(Z)
    .SS   (ss_bar),    // Active-Low

    // 7-seg
    .fnd_font (fnd_font),
    .fnd_comm (fnd_comm)
);

endmodule

