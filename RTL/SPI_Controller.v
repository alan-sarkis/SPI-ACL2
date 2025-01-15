module spi_controller(
    input CLK,
    input [2:0] OPERATION, // SWITCH 1,2,3
    input [2:0] ADDRESS_CHOICE, // BUTTON 1,2,3,4
    input MISO,
    output reg CS,
    output reg SCLK,
    output reg MOSI,
    output reg [7:0] MISO_DATA
);
//// Instructions ////
localparam REG_READ = 3'b001;
localparam FIFO_READ = 3'b010;
localparam WRITE = 3'b100;

reg [7:0] INSTRUCTION;

always@(posedge CLK)begin
    case(OPERATION)
        REG_READ:  INSTRUCTION <= 8'b00001011; // SWITCH 1
        FIFO_READ: INSTRUCTION <= 8'b00001101; // SWITCH 2
        WRITE:     INSTRUCTION <= 8'b00001010; // SWITCH 3
    endcase
end

//// Addresses ////
localparam X_ADDRESS = 3'b001;
localparam Y_ADDRESS = 3'b010;
localparam Z_ADDRESS = 3'b100;

always@(posedge CLK)begin
    case(ADDRESS_CHOICE)
        X_ADDRESS: ADDRESS <= 8'h08; // BUTTON 1
        Y_ADDRESS: ADDRESS <= 8'h09; // BUTTON 2
        Z_ADDRESS: ADDRESS <= 8'h0A; // BUTTON 3
    endcase
end


///// States /////
reg [1:0] STATE = 2'b00;
localparam IDLE = 2'b00, SEND_DATA = 2'b01, RECIEVE_DATA = 2'b10;

///// Initiate Slow Clock For SPI /////
localparam SLOW_CLOCK_DIVIDE = 1221;
integer SLOW_CLOCK_COUNTER = 0;

always@(posedge CLK)begin
    if(STATE == SEND_DATA || STATE == RECIEVE_DATA)begin
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
    case(STATE)
    IDLE:
        begin
            CS <= 1;
            MOSI <= 0;
            MISO_DATA <= 0;
            i <= 15;
            if(OPERATION == (REG_READ || FIFO_READ || WRITE))begin
                STATE <= SEND_DATA;
            end
        end
    
    SEND_DATA: // Sending Instruction and Address to MOSI
        begin
            CS <= 0;
            if((SCLK == 1'b0) && (SLOW_CLOCK_COUNTER == SLOW_CLOCK_DIVIDE/2))begin // Positive Edge of SCLK(WRITE BEFORE CLOCK EDGE)
                i <= i - 1;
                MOSI <= MOSI_DATA[i];
                if(i == 0)begin
                    STATE <= RECIEVE_DATA;
                    i <= 8;
                end
            end
        end

    RECIEVE_DATA: // Recieving Data from MISO
        begin
            if((SCLK == 1'b0) && (SLOW_CLOCK_COUNTER == SLOW_CLOCK_DIVIDE))begin // Positive Edge of SCLK FULL(READ ON CLOCK EDGE)
                i <= i - 1;
                MISO_DATA[i] <= MISO;
                if((i == 0) && (OPERATION ~= REG_READ))begin // If we no longer want to burst read, the device will go to idle
                    STATE <= IDLE;
                end
                else if(i == 0)begin // The loop will continue until there is no need to burst read
                    i <= 8;
                end
                
            end
        end
    endcase

end


endmodule