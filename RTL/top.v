module top(
    input CLK, // 125.000 MHz SYSTEM CLOCK
    input [2:0] OPERATION, // SWITCH 1,2,3
    input [2:0] ADDRESS_CHOICE, // BUTTON 1,2,3,4
    input MISO, // DATA FROM SLAVE TO MASTER

    output CS, // CHIP SELECT
    output SCLK, // SLOW CLOCK FOR SPI PROTOCOL
    output MOSI, // DATA FROM MASTER TO SLAVE



    output [6:0] SEGMENTS,
    output DIGIT_SELECT
);

wire [7:0] DATA_OUT_IN;

spi_controller i1(
    .CLK(CLK),
    .OPERATION(OPERATION),
    .ADDRESS_CHOICE(ADDRESS_CHOICE),
    .MISO(MISO),
    .CS(CS),
    .SCLK(SCLK),
    .MOSI(MOSI),
    .DATA_OUT(DATA_OUT_IN)
);

display i2(
    .CLK(CLK),
    .DATA_IN(DATA_OUT_IN),
    .SEGMENTS(SEGMENTS),
    .DIGIT_SELECT(DIGIT_SELECT)
);

endmodule