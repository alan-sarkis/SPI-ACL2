module spi_controller(
    input CLK, // 125.000 MHz SYSTEM CLOCK
    input [2:0] OPERATION, // SWITCH 1,2,3
    input [2:0] ADDRESS_CHOICE, // BUTTON 1,2,3,4
    input MISO, // DATA FROM SLAVE TO MASTER

    output reg CS = 1, // CHIP SELECT
    output reg SCLK = 0, // SLOW CLOCK FOR SPI PROTOCOL
    output reg MOSI = 0, // DATA FROM MASTER TO SLAVE

    output reg [7:0] DATA_OUT = 0, // SERIAL DATA FROM MISO COMBINED INTO AN ARRAY
    output reg DATA_VALID  = 0// TO COMMUNICATE TO 7 SEGMENT THAT THE DATA is READY TO BE DISPLAYED
);

////////////////////// THE FIFO READ AND WRITE COMMANDS ARE NOT DEVELOPED YET ///////////////////////////

//// SPI Instructions ////
localparam REG_READ = 3'b001;
localparam FIFO_READ = 3'b010;
localparam WRITE = 3'b100;

reg [7:0] INSTRUCTION = 0;

always@(posedge CLK)begin
    case(OPERATION)
        REG_READ:  INSTRUCTION <= 8'b00001011; // SWITCH 1
        FIFO_READ: INSTRUCTION <= 8'b00001101; // SWITCH 2
        WRITE:     INSTRUCTION <= 8'b00001010; // SWITCH 3
        default:   INSTRUCTION <= 0;
    endcase
end


//// Addresses ////
localparam X_ADDRESS = 3'b001;
localparam Y_ADDRESS = 3'b010;
localparam Z_ADDRESS = 3'b100;

reg [7:0] ADDRESS = 0;

always@(posedge CLK)begin
    case(ADDRESS_CHOICE)
        X_ADDRESS: ADDRESS <= 8'h08; // BUTTON 1
        Y_ADDRESS: ADDRESS <= 8'h09; // BUTTON 2
        Z_ADDRESS: ADDRESS <= 8'h0A; // BUTTON 3
        default:   ADDRESS <= ADDRESS; // Latch as we need to capture the button value and not reset when unclicked
    endcase
end


//////// States /////////
reg [1:0] STATE = 2'b00;
localparam IDLE = 2'b00, SEND_DATA = 2'b01, RECIEVE_DATA = 2'b10;


///////// Initiate Slow Clock For SPI ////////
localparam SLOW_CLOCK_DIVIDE = 1221; // Original CLOCK DIVIDE is 2442 but we use 1221 as we need the clock edge two times per period
integer SLOW_CLOCK_COUNTER = 0;

always@(posedge CLK)begin // Clock divider to achieve a SCLK of 51.875 kHz
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

///////// TX and RX SPI RTL //////////
integer BIT_COUNTER = 0;
wire [15:0] MOSI_DATA = {INSTRUCTION,ADDRESS};
reg [7:0] MISO_DATA = 0;
reg READY = 0;

always@(posedge CLK)begin // To ensure all settings are selected before transactions
    if((OPERATION == (REG_READ || FIFO_READ || WRITE)) && (ADDRESS_CHOICE == (X_ADDRESS || Y_ADDRESS || Z_ADDRESS)))
        READY <= 1;
    else
        READY <= 0;
end

always@(posedge CLK)begin
    case(STATE)
        IDLE: // RESET all COUNTERS and BUSSES to default conditions
            begin
                CS <= 1;
                MOSI <= 0;
                MISO_DATA <= 0;
                BIT_COUNTER <= 15;
                DATA_VALID <= 0;
                if(READY)begin
                    STATE <= SEND_DATA;
                end
            end
        
        SEND_DATA: // Sending Instruction and Address to MOSI
            begin
                CS <= 0;
                if((SCLK == 1'b0) && (SLOW_CLOCK_COUNTER == SLOW_CLOCK_DIVIDE/2))begin // WRITE before POSEDGE
                    BIT_COUNTER <= BIT_COUNTER - 1;
                    MOSI <= MOSI_DATA[BIT_COUNTER];
                    if(BIT_COUNTER == 0)begin
                        STATE <= RECIEVE_DATA;
                        BIT_COUNTER <= 8;
                    end
                end
            end

        RECIEVE_DATA: // Recieving Data from MISO
            begin
                if((SCLK == 1'b0) && (SLOW_CLOCK_COUNTER == SLOW_CLOCK_DIVIDE))begin // READ on POSEDGE
                    DATA_VALID <= 0;
                    BIT_COUNTER <= BIT_COUNTER - 1;
                    MISO_DATA[BIT_COUNTER] <= MISO;
                    if(BIT_COUNTER == 0)begin
                        DATA_VALID <= 1;
                        DATA_OUT <= MISO_DATA;
                        if(~READY)begin // If we no longer want to burst read, the device will go to idle
                            STATE <= IDLE;
                        end
                        else begin // The loop will continue until there is no need to burst read
                            BIT_COUNTER <= 8;
                            MISO_DATA <= 0;
                        end
                    end
                end
            end
    endcase
end


endmodule