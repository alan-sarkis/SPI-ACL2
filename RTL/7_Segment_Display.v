module display(
    input RESET,
    input CLK,
    input [7:0] DATA_IN,
    output reg [6:0] SEGMENTS,
    output reg DIGIT_SELECT
);

//////// Define Segments for Each Number Value ////////
localparam NUM_0 = 7'b1111110;
localparam NUM_1 = 7'b0110000;
localparam NUM_2 = 7'b1101101;
localparam NUM_3 = 7'b1111001;
localparam NUM_4 = 7'b0110011;
localparam NUM_5 = 7'b1011011;
localparam NUM_6 = 7'b1011111;
localparam NUM_7 = 7'b1110000;
localparam NUM_8 = 7'b1111111;
localparam NUM_9 = 7'b1110011;


/////// Counter to Account for Display Refresh Rate ///////
reg [21:0] COUNTER;
localparam REFRESH_RATE = 2_500_000;

always@(posedge CLK)begin
    if(RESET)
        COUNTER <= 0;
    else if(COUNTER == REFRESH_RATE)
        COUNTER <= 0;
    else
        COUNTER <= COUNTER + 1;
end

////// Store DATA for Refresh Rate Cycle //////
reg [7:0] TEMP_DATA;

always@(posedge CLK)begin
    if(RESET)
        TEMP_DATA <= 0;
    if(COUNTER == REFRESH_RATE)
        TEMP_DATA <= DATA_IN;
end
///////// Convert to BCD ///////
wire [3:0] tens = TEMP_DATA / 10;
wire [3:0] ones = TEMP_DATA % 10;


/////// Assigning Values to Segment Display ////////
always@(posedge CLK)begin
    if(RESET)begin
        DIGIT_SELECT <= 0;
        SEGMENTS <= NUM_0;
    end
    
    else if(COUNTER == 0)begin // First Digit
        DIGIT_SELECT <= 0;
        if(TEMP_DATA > 99)begin
            SEGMENTS <= NUM_9;
        end
        
        else begin
            case(tens)
                0: SEGMENTS <= NUM_0;
                1: SEGMENTS <= NUM_1;
                2: SEGMENTS <= NUM_2;
                3: SEGMENTS <= NUM_3;
                4: SEGMENTS <= NUM_4;
                5: SEGMENTS <= NUM_5;
                6: SEGMENTS <= NUM_6;
                7: SEGMENTS <= NUM_7;
                8: SEGMENTS <= NUM_8;
                9: SEGMENTS <= NUM_9;
            endcase
        end
    end

    else if(COUNTER == REFRESH_RATE/2)begin // Second Digit
        DIGIT_SELECT <= 1;
        if(TEMP_DATA > 99)begin
            SEGMENTS <= NUM_9;
        end
        else begin
            case(ones)
                0: SEGMENTS <= NUM_0;
                1: SEGMENTS <= NUM_1;
                2: SEGMENTS <= NUM_2;
                3: SEGMENTS <= NUM_3;
                4: SEGMENTS <= NUM_4;
                5: SEGMENTS <= NUM_5;
                6: SEGMENTS <= NUM_6;
                7: SEGMENTS <= NUM_7;
                8: SEGMENTS <= NUM_8;
                9: SEGMENTS <= NUM_9;
            endcase
        end
    end  
end
endmodule
