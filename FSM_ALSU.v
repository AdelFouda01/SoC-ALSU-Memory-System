module FSM_ALSU (
    input clk, EN, rst, Cin, bypass_A, bypass_B, red_op_A, red_op_B, Serial_in, direction,
    input [7:0] location_A, location_B, location_C,
    input [2:0] opcode,
    input Rx_in,  
    input par_en, par_typ,        
    output Tx_out,        
    output [15:0] C,      
    output [15:0] leds
    );

    parameter DATA_WIDTH = 8;
    parameter LOCATION_WIDTH = 8;



    // UART Signals
    wire rx_valid;
    wire [7:0] rx_data;
    wire rx_err, rx_parity_err, rx_stp_err;

    assign rx_err = rx_parity_err | rx_stp_err; //error

    reg uart_err_flag; // LED 15 Control
    wire [15:0] alsu_leds;
    assign leds = {uart_err_flag, alsu_leds[14:0]};

    wire [4:0] prescale = 8;
    wire tx_busy;
    reg tx_start;
    reg [7:0] tx_data;

    // ALSU Signal to start CALC
    reg alsu_en;
    
    // States
    reg [3:0] cs, ns;

    // Register to capture Inputs
    reg [LOCATION_WIDTH - 1:0] location_A_reg, location_B_reg, location_C_reg;
    reg Cin_reg, bypass_A_reg, bypass_B_reg, red_op_A_reg, red_op_B_reg, Serial_in_reg, direction_reg;
    reg [2:0] opcode_reg;
    reg [DATA_WIDTH - 1:0] A_reg, B_reg;

    // capture the negedge of Busy to make sure that Tx is done
    reg tx_busy_q;
    always @(posedge clk or posedge rst) begin
        if (rst)
            tx_busy_q <= 0;
        else    
            tx_busy_q <= tx_busy;
    end
    wire tx_done;
    assign tx_done = (tx_busy_q && !tx_busy);

//ALSU INST
    ALSU ALSU_inst (.A(A_reg), .B(B_reg), .cin(Cin_reg), .serial_in(Serial_in_reg),
        .red_op_A(red_op_A_reg), .red_op_B(red_op_B_reg), .opcode(opcode_reg),
        .bypass_A(bypass_A_reg), .bypass_B(bypass_B_reg), .en(alsu_en),
        .clk(clk), .rst(rst), .direction(direction_reg), .leds(alsu_leds), .out(C));


    //Tx INST
    Tx_UART Tx_ALSU (
        .P_data(tx_data),
        .data_valid(tx_start),
        .par_en(par_en),
        .par_typ(par_typ),
        .prescale(prescale),
        .clk(clk),
        .rst(rst),
        .Tx_out(Tx_out),
        .Busy(tx_busy)    
    );



    //Rx INST
    Rx_UART Rx_ALSU (
        .clk(clk), .rst(rst), .Rx_in(Rx_in), .par_en(par_en), .par_typ(par_typ),
        .prescale(prescale), .P_data(rx_data), .data_valid(rx_valid),
        .PARITY_ERROR(rx_parity_err), .STP_ERROR(rx_stp_err)
    );

    //State encoding
    parameter IDLE = 0, CMD_READ_A = 1, ADDR_A = 2, WAIT_A = 3,CMD_READ_B = 4, ADDR_B = 5, WAIT_B = 6, CALC_1 = 7, CMD_WRITE_C_LSB = 8, ADDR_C_LSB = 9, DATA_C_LSB = 10, CMD_WRITE_C_MSB = 11, ADDR_C_MSB = 12, DATA_C_MSB = 13, CALC_2 = 14;

    //opcode encoding
    parameter OR_OP = 3'h0, XOR_OP = 3'h1, ADD_OP = 3'h2, MULT_OP = 3'h3, SHIFT_OP = 3'h4, ROTATE_OP = 3'h5, INVALID1 = 3'h6, INVALID2 = 3'h7;





    // STATE REGISTER
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cs <= IDLE;
        end else begin
            cs <= ns;
        end
    end





    // Next State logic
    always @(*) begin
        ns = cs;
        tx_start = 0;
        tx_data = 0;
        alsu_en = 0;



        case (cs)
            IDLE: begin
                if (EN) begin
                    if ((red_op_B || bypass_B) && !red_op_A && !bypass_A) // if A is not enabled it will take B only
                        ns = CMD_READ_B;
                    else
                        ns = CMD_READ_A;
                end
            end



            CMD_READ_A: begin
                tx_data = 8'h0A; //CMD to Mem to Read Data
                if (tx_done)
                    ns = ADDR_A;
                else if (!tx_busy) // Wait Tx to be done
                    tx_start = 1;
            end

            ADDR_A: begin
                tx_data = location_A_reg; // send Location of A to MEM
                if (tx_done)
                    ns = WAIT_A;
                else if (!tx_busy)
                    tx_start = 1;
            end



            WAIT_A: begin
                if (rx_valid) begin //Wait the Rx process to be done
                    if (rx_err)
                        ns = IDLE;
                    else if (red_op_A_reg || bypass_A_reg)  // if B is not enabled it will take A only
                        ns = CALC_1;
                    else                              
                        ns = CMD_READ_B;
                end
            end



            CMD_READ_B: begin
                tx_data = 8'h0A; //CMD to Mem to Read Data
                if (tx_done)
                    ns = ADDR_B;
                else if (!tx_busy) // Wait Tx to be done
                    tx_start = 1;
            end


            ADDR_B: begin
                tx_data = location_B_reg; // send Location of A to MEM
                if (tx_done)
                    ns = WAIT_B;
                else if (!tx_busy)
                    tx_start = 1;
            end



            WAIT_B: begin
                if (rx_valid) begin //Wait Rx process to be done
                    if (rx_err)
                        ns = IDLE;
                    else  
                        ns = CALC_1;
                end
            end



            CALC_1: begin
                alsu_en = 1; //Enable ALSU To CALC
                ns = CALC_2;
            end



            CALC_2: begin
                alsu_en = 1; //Enable ALSU To CALC
                ns = CMD_WRITE_C_LSB;
            end



            CMD_WRITE_C_LSB: begin
                    tx_data = 8'h0B; //CMD to MEM to Write Data
                if (tx_done)
                    ns = ADDR_C_LSB;
                else if (!tx_busy)
                    tx_start = 1;
            end



            ADDR_C_LSB: begin
                tx_data = location_C_reg; // sending location of C
                if (tx_done)
                    ns = DATA_C_LSB;
                else if (!tx_busy)
                    tx_start = 1;
            end



            DATA_C_LSB: begin  // Cause of C is Double Size of Inputs it will send in two write process
                tx_data = C[7:0]; // sending The Least Sig Byte of C
                if (tx_done)          
                    ns = CMD_WRITE_C_MSB;
                else if (!tx_busy)
                    tx_start = 1;
            end

            CMD_WRITE_C_MSB: begin
                tx_data = 8'h0B;
                if (tx_done)
                    ns = ADDR_C_MSB;
                else if (!tx_busy)
                    tx_start = 1;
            end



            ADDR_C_MSB: begin
                tx_data = location_C_reg + 1'b1; // send the location of the next index after C location
                if (tx_done)
                    ns = DATA_C_MSB;
                else if (!tx_busy)
                    tx_start = 1;
            end



            DATA_C_MSB: begin
                tx_data = C[15:8]; // sending The Most Sig Byte of C
                if (tx_done)
                    ns = IDLE;
                else if (!tx_busy)
                    tx_start = 1;
            end

            default: ns = IDLE;
        endcase

    end



    always @(posedge clk or posedge rst) begin
        if (rst) begin
            location_A_reg <= 0;
            location_B_reg <= 0;
            location_C_reg <= 0;
            Cin_reg <= 0;
            bypass_A_reg <= 0;
            bypass_B_reg <= 0;
            red_op_A_reg <= 0;
            red_op_B_reg <= 0;
            Serial_in_reg <= 0;
            direction_reg <= 0;
            opcode_reg <= 0;
            A_reg <= 0;
            B_reg <= 0;
            uart_err_flag <= 0;
        end

        else begin
            if (cs == IDLE && EN) begin  // capture the inputs
                location_A_reg <= location_A;
                location_B_reg <= location_B;
                location_C_reg <= location_C;
                Cin_reg <= Cin;
                bypass_A_reg <= bypass_A;
                bypass_B_reg <= bypass_B;
                red_op_A_reg <= red_op_A;
                red_op_B_reg <= red_op_B;
                Serial_in_reg <= Serial_in;
                direction_reg <= direction;
                opcode_reg <= opcode;
                uart_err_flag <= 0;
            end

            if (cs == WAIT_A && rx_valid) begin 
                if (rx_err)
                    uart_err_flag <= 1;
                else
                    A_reg <= rx_data;
            end

            if (cs == WAIT_B && rx_valid) begin
                if (rx_err)
                    uart_err_flag <= 1;
                else
                    B_reg <= rx_data;
            end
        end
    end
endmodule

