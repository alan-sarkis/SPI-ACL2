module spi_controller(
    input RESET,
    input CLK, // 125.000 MHz SYSTEM CLOCK
    input [3:0] OPERATION, // SWITCH 1,2,3,4
    input MISO, // DATA FROM SLAVE TO MASTER

    output reg CS, // CHIP SELECT
    output reg SCLK, // SLOW CLOCK FOR SPI PROTOCOL
    output reg MOSI, // DATA FROM MASTER TO SLAVE

    output reg [7:0] DATA_OUT // SERIAL DATA FROM MISO COMBINED INTO AN ARRAY
);

//// Instructions and Addresses////
localparam REG_READ = 8'b00001011;
localparam FIFO_WRITE = 8'b00001010;

localparam X_ADDRESS_READ = 4'b0001;
localparam Y_ADDRESS_READ = 4'b0010;
localparam Z_ADDRESS_READ = 4'b0100;
localparam SETUP_WRITE = 4'b1000;

reg [7:0] INSTRUCTION;
reg [7:0] ADDRESS;
reg [7:0] SETUP_DATA;
reg [2:0] SETUP_STATE;


always@(posedge CLK)begin
    if(RESET)begin
        INSTRUCTION <= 0;
        ADDRESS <= 0;
    end
    case(OPERATION)
        X_ADDRESS_READ: begin
            INSTRUCTION <= REG_READ;
            ADDRESS <= 8'b00001001;
        end
        Y_ADDRESS_READ: begin
            INSTRUCTION <= REG_READ;
            ADDRESS <= 8'b00001010;
        end
        Z_ADDRESS_READ: begin
            INSTRUCTION <= REG_READ;
            ADDRESS <= 8'b00001011;
        end
        SETUP_WRITE: begin
            INSTRUCTION <= FIFO_WRITE;
            case(SETUP_STATE)
                0: begin
                    ADDRESS <= 8'h20;
                    SETUP_DATA <= 8'hFA;
                end
                1: begin
                    ADDRESS <= 8'h21;
                    SETUP_DATA <= 8'h00;
                end
                2: begin
                    ADDRESS <= 8'h23;
                    SETUP_DATA <= 8'h96;
                end
                3: begin
                    ADDRESS <= 8'h24;
                    SETUP_DATA <= 8'h0;
                end
                4: begin
                    ADDRESS <= 8'h25;
                    SETUP_DATA <= 8'h1E;
                end
                5: begin
                    ADDRESS <= 8'h27;
                    SETUP_DATA <= 8'h3F;
                end
                6: begin
                    ADDRESS <= 8'h2D;
                    SETUP_DATA <= 8'h0A;
                end
            endcase

        end
    endcase
end


//////// States /////////
reg [1:0] STATE;
localparam IDLE = 2'b00, SEND_DATA = 2'b01, RECIEVE_DATA = 2'b10;


///////// Initiate Slow Clock For SPI ////////
localparam SLOW_CLOCK_DIVIDE = 1221;
reg [10:0] SLOW_CLOCK_COUNTER = 0;

always@(posedge CLK)begin // Clock divider to achieve a SCLK of 51.875 kHz
    if(RESET)begin
        SLOW_CLOCK_COUNTER <= 0;
        SCLK <= 0;
    end
    else if(STATE == SEND_DATA || STATE == RECIEVE_DATA)begin
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

///////// CHECK CONDITIONS BEFORE START //////////
reg READY;

always@(posedge CLK)begin // To ensure all settings are selected before transactions
    if(RESET)
        READY <= 0;
    else if(OPERATION == X_ADDRESS_READ || OPERATION == Y_ADDRESS_READ || OPERATION == Z_ADDRESS_READ)
        READY <= 1;
    else
        READY <= 0;
end


/////// FSM FOR SPI OPERATION //////
wire [15:0] MOSI_DATA = {INSTRUCTION,ADDRESS};
wire [23:0] MOSI_SETUP_DATA = {INSTRUCTION,ADDRESS,SETUP_DATA};
reg [7:0] MISO_DATA;
reg [4:0] BIT_COUNTER;
reg DONE_SETUP;

always@(posedge CLK)begin
    if(RESET)begin
        CS <= 1;
        SETUP_STATE <= 0;
        DONE_SETUP <= 0;
        MISO_DATA <= 0;
        MOSI <= 0;
        BIT_COUNTER <= 0;
        STATE <= IDLE;
    end
    else if(OPERATION[3])begin // Setting UP Accelerometer
        case(STATE)
            IDLE:
                begin
                    if(SETUP_STATE == 7)begin
                        DONE_SETUP <= 1;
                        CS <= 1;
                    end
                    else if(~DONE_SETUP)begin
                        CS <= 1;
                        MOSI <= 0;
                        MISO_DATA <= 0;
                        BIT_COUNTER <= 23;
                        STATE <= SEND_DATA;
                    end
                end
            
            SEND_DATA: // Sending Instruction and Address to MOSI
                begin
                    CS <= 0;
                    if((SCLK == 1'b0) && (SLOW_CLOCK_COUNTER == SLOW_CLOCK_DIVIDE/2))begin // WRITE before POSEDGE
                        BIT_COUNTER <= BIT_COUNTER - 1;
                        MOSI <= MOSI_SETUP_DATA[BIT_COUNTER];
                        if(BIT_COUNTER == 0)begin
                            STATE <= IDLE;
                            SETUP_STATE <= SETUP_STATE + 1;
                        end
                    end
                end
                default: STATE <= IDLE;
        endcase
    end
    else begin
        case(STATE)
            IDLE: // RESET all COUNTERS and BUSSES to default conditions
                begin
                    CS <= 1;
                    MOSI <= 0;
                    MISO_DATA <= 0;
                    BIT_COUNTER <= 15;
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
                            BIT_COUNTER <= 7;
                        end
                    end
                end

            RECIEVE_DATA: // Recieving Data from MISO ///////DELAYS MIGHT MESS UP SAMPLING
                begin
                    if((SCLK == 1'b0) && (SLOW_CLOCK_COUNTER == SLOW_CLOCK_DIVIDE))begin // READ on POSEDGE
                        BIT_COUNTER <= BIT_COUNTER - 1;
                        MISO_DATA[BIT_COUNTER] <= MISO;
                        if(BIT_COUNTER == 0)begin
                            DATA_OUT <= MISO_DATA;
                            if(~READY) // If we no longer want to burst read, the device will go to idle
                                STATE <= IDLE;
                            else // The loop will continue until there is no need to burst read
                                BIT_COUNTER <= 7;
                        end
                    end
                end
            default: STATE <= IDLE;
        endcase
    end
end
endmodule