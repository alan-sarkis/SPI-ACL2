module top(
    input RESET,
    input CLK, // 125.000 MHz SYSTEM CLOCK
    input [3:0] OPERATION, // SWITCH 1,2,3,4
    input MISO, // DATA FROM SLAVE TO MASTER

    output CS, // CHIP SELECT
    output SCLK, // SLOW CLOCK FOR SPI PROTOCOL
    output MOSI, // DATA FROM MASTER TO SLAVE

    output [6:0] SEGMENTS,
    output DIGIT_SELECT

    output DONE_SETUP;
);

wire [7:0] DATA_OUT_IN;

spi_controller i1(
    .RESET(RESET),
    .CLK(CLK),
    .OPERATION(OPERATION),
    .MISO(MISO),
    .CS(CS),
    .SCLK(SCLK),
    .MOSI(MOSI),
    .DATA_OUT(DATA_OUT_IN),
    .DONE_SETUP(DONE_SETUP)
);

display i2(
    .RESET(RESET),
    .CLK(CLK),
    .DATA_IN(DATA_OUT_IN),
    .SEGMENTS(SEGMENTS),
    .DIGIT_SELECT(DIGIT_SELECT)
);

endmodule