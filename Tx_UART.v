module Tx_UART (
    input clk, rst, data_valid, par_en, par_typ,
    input [4:0] prescale, 
    input [7:0] P_data,
    output reg Tx_out, Busy
    );



    reg [2:0] cs, ns; //STATES 

    reg [4:0] prescale_count; //count to send the bits 

    reg [7:0] P_data_reg; // Register to serialize the data
    reg [3:0] bit_count;  // Counter to keep track of the number of bits transmitted
    reg parity_bit; // Register to hold the calculated parity bit
    reg par_en_reg; // Register to hold the parity enable signal

    parameter IDLE = 3'b000, START = 3'b001, DATA = 3'b010, PARITY = 3'b011, STOP = 3'b100; //STATE encoding 




    //STATE REG
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
            IDLE: begin //IDLE State wait for the parallel data 
                if (data_valid) 
                    ns = START; 
            end
            
            START: begin 
                if (prescale_count == prescale - 1) // wait for prescale clks
                ns = DATA;
            end
            
            DATA: begin
                if (prescale_count == prescale - 1 && bit_count == 7) begin // if data is completely sent 
                    if (par_en_reg) //if there is parity bit go to parity if not go to Stop condition
                        ns = PARITY;
                    else 
                        ns = STOP;
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
        endcase
    end

    // output logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            Tx_out <= 1; // keep Tx out high
            Busy <= 0;
            P_data_reg <= 0;
            bit_count <= 0;
            parity_bit <= 0;
            par_en_reg <= 0;
        end 
        else begin
            case (cs)
                IDLE: begin 
                    Tx_out <= 1; 
                    Busy <= 0;
                    bit_count <= 0;
                    if (data_valid) begin //Start Condition 
                        //capture the parallel data
                        P_data_reg <= P_data; 
                        par_en_reg <= par_en;
                        Busy <= 1;
                        parity_bit <= par_typ ? ~(^P_data) : (^P_data);  //parity bit calculation
                    end
                end

                START: begin
                    Tx_out <= 0; // Start bit is low
                    if (prescale_count < prescale - 1) //wait for the prescale pulses
                        prescale_count <= prescale_count + 1;
                    else 
                        prescale_count <= 0;
                end

                DATA: begin // PISO
                    Tx_out <= P_data_reg[0]; //send the least sign bit 
                    Busy <= 1; // set the busy flag high to prevent any other data to be sent 
                    if (prescale_count < prescale - 1) 
                        prescale_count <= prescale_count + 1;
                    else begin
                        prescale_count <= 0; // set the count to zero to send the next bit
                        bit_count <= bit_count + 1; 
                        P_data_reg <= {1'b0, P_data_reg[7:1]}; //shift to next bit
                    end
                end
                PARITY: begin
                    Tx_out <= parity_bit;  // sending parity bit 
                    if (prescale_count < prescale - 1) 
                        prescale_count <= prescale_count + 1;
                    else 
                        prescale_count <= 0;
                end
                STOP: begin
                    Tx_out <= 1; // Stop bit is high
                    if (prescale_count < prescale - 1) 
                        prescale_count <= prescale_count + 1;
                    else begin
                        prescale_count <= 0; 
                        Busy <= 0; //set the busy high to start capture a new data 
                    end
                end
            endcase
        end
    end
endmodule