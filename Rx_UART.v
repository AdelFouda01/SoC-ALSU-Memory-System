module Rx_UART (
    input clk, rst, Rx_in, par_en, par_typ,
    input [4:0] prescale,
    output reg [7:0] P_data,
    output reg data_valid, PARITY_ERROR, STP_ERROR
);
    reg [2:0] cs, ns; 
    reg [3:0] bit_count;  
    reg [4:0] prescale_count; 
    reg [7:0] P_data_reg; 
    
    
    wire [4:0] half_prescale = prescale/2; //claculate the half prescale to capture the bit in this count 

    //State Encoding 
    parameter IDLE = 3'b000, START = 3'b001, DATA = 3'b010, PARITY = 3'b011, STOP = 3'b100;

    // STATE REG
    always @(posedge clk or posedge rst) begin
        if (rst) 
            cs <= IDLE; 
        else     
            cs <= ns;
    end

    //Next State logic
    always @(*) begin
        ns = cs;
        case (cs)
            IDLE: begin   //Waiting for start bit which is low 
                if (!Rx_in) 
                    ns = START;
            end 
            START: begin   
                if (prescale_count == half_prescale && Rx_in == 1) // if there is noise in the start bit return to IDLE State 
                    ns = IDLE;
                else if (prescale_count == prescale - 1) // wait the prescale pulses
                    ns = DATA;
            end 
            DATA: begin   
                if (prescale_count == prescale - 1 && bit_count == 7)  begin  // if data are complete
                    if (par_en) //if parity enabled go to Parity Check if not go to Stop condition 
                        ns =  PARITY; 
                    else 
                        ns =  STOP;
                end
            end 

            PARITY: begin 
                if (prescale_count == prescale - 1)  
                    ns = STOP;
            end 

            STOP: begin
                if (prescale_count == prescale - 1) 
                    ns = IDLE; 
            end   
            default: ns = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            prescale_count <= 0; 
            bit_count <= 0; 
            P_data_reg <= 0;
            PARITY_ERROR <= 0; 
            STP_ERROR <= 0; 
            data_valid <= 0;
        end 
        else begin
            data_valid <= 0; //make sure the data_valid is low to complete all bits 
            case (cs)
                IDLE: begin
                    prescale_count <= 0; 
                    bit_count <= 0; 
                    data_valid <= 0;
                end
                
                START: begin
                    if (prescale_count == half_prescale && Rx_in == 1'b1) begin // if there is noise in half of start bit 
                        prescale_count <= 0; 
                    end 
                    else if (prescale_count < prescale - 1) begin
                        prescale_count <= prescale_count + 1;
                    end 
                    else begin
                        prescale_count <= 0; // End of Start Bit
                    end
                end
                
                DATA: begin
                    if (prescale_count < prescale - 1) 
                        prescale_count <= prescale_count + 1; 
                    else begin 
                        prescale_count <= 0; 
                        bit_count <= bit_count + 1; // start the next bit 
                    end
                    if (prescale_count == half_prescale) begin //capture the bit in the Half Sampling bit  
                        P_data_reg[bit_count] <= Rx_in; 
                    end
                end
                
                PARITY: begin

                    if (prescale_count < prescale - 1) 
                        prescale_count <= prescale_count + 1; 
                    else 
                        prescale_count <= 0;
                    

                    if (prescale_count == half_prescale) begin
                        if (par_typ == 0) 
                            PARITY_ERROR <= ^P_data_reg ^ Rx_in; // Even Parity Check
                        else             
                             PARITY_ERROR <= ~(^P_data_reg ^ Rx_in); // Odd Parity Check 
                    end
                end

                STOP: begin
                    if (prescale_count < prescale - 1) begin
                        prescale_count <= prescale_count + 1'b1; 
                    end else begin 
                        prescale_count <= 0;
                        if (!STP_ERROR) begin
                            data_valid <= 1; 
                            P_data <= P_data_reg; 
                        end
                    end
                    if (prescale_count == half_prescale) begin
                        STP_ERROR <= (Rx_in == 0); //if there is noise in the Stop bit 
                    end
                end
            endcase
        end 
    end
endmodule