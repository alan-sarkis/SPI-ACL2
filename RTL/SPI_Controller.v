module spi_controller(
    input CLK,
    input OPERATION,
    input MISO,
    input READY,
    output reg CS,
    output reg SCLK,
    output reg MOSI,
    output reg [7:0] MISO_DATA
);
//// Instructions ////
localparam REG_READ = 2'b00;
localparam FIFO_READ = 2'b01;
localparam WRITE= 1'b10;

reg [7:0] INSTRUCTION;

always@(posedge CLK)begin
    case(OPERATION)
    REG_READ:  INSTRUCTION <= 8'b00001011;
    FIFO_READ: INSTRUCTION <= 8'b000001101;
    WRITE:     INSTRUCTION <= 8'b00001010;
    endcase
end

///// ADRESSES /////
wire [7:0] ADDRESS = 8'b01101101;

///// Initiate Slow Clock For SPI /////
localparam SLOW_CLOCK_DIVIDE = 1221;
integer SLOW_CLOCK_COUNTER = 0;

///// MODES ////
reg [1:0] MODE = 2'b00;

localparam IDLE = 2'b00, SEND_INSTR = 2'b01, RECIEVE_DATA = 2'b10;

always@(posedge CLK)begin
    if(MODE == SEND_INSTR || MODE == RECIEVE_DATA)begin
        SLOW_CLOCK_COUNTER <= SLOW_CLOCK_COUNTER + 1;
        if(SLOW_CLOCK_COUNTER == SLOW_CLOCK_DIVIDE)begin
            SCLK <= ~SCLK;
            SLOW_CLOCK_COUNTER <= 0;
        end
    end
    else begin
        SLOW_CLOCK_COUNTER <= 0;
        SCLK <= 0;
    end
end

//// TX and RX SPI RTL ////
wire [15:0] MOSI_DATA = {INSTRUCTION,ADDRESS};
integer i = 0;

always@(posedge CLK)begin
    case(MODE)
    IDLE:
        begin
            CS <= 1;
            MOSI <= 0;
            MISO_DATA <= 0;
            i <= 15;
            if(READY)begin
                MODE <= SEND_INSTR;
            end
        end
    
    SEND_INSTR:
        begin
            CS <= 0;
            if((SCLK == 1'b0) && (SLOW_CLOCK_COUNTER == SLOW_CLOCK_DIVIDE/2))begin // Positive Edge of SCLK(WRITE BEFORE CLOCK EDGE)
                i <= i - 1;
                MOSI <= MOSI_DATA[i];
                if(i == 0)begin
                    MODE <= RECIEVE_DATA;
                    i <= 8;
                end
            end
        end

    RECIEVE_DATA:
        begin
            if((SCLK == 1'b0) && (SLOW_CLOCK_COUNTER == SLOW_CLOCK_DIVIDE))begin // Positive Edge of SCLK FULL(READ ON CLOCK EDGE)
                i <= i - 1;
                MISO_DATA[i] <= MISO;
                if(i == 0)begin
                    MODE <= IDLE;
                end
                
            end
        end
    endcase

end


endmodule