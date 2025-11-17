`timescale 1ns / 1ps

module FPGA(
    //global signal
    input  logic       clk,
    input  logic       reset,
    input  logic       clear,
    input  logic       run_stop,
    
    //external ports
    output logic       sclk,
    output logic       mosi,
    input  logic       miso,
    output logic       ss_bar,

    // SPI pins
    input  logic SCLK,  // 외부 SPI SCLK
    input  logic MOSI,
    output logic MISO,  // 현재 미사용(Z)
    input  logic SS,    // Active-Low

    // 7-seg
    output logic [7:0] fnd_font,
    output logic [3:0] fnd_comm
);

master_pack U_master_pack(.*);

slave_pack U_slave_pack(.*);

endmodule
