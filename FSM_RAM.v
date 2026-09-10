module FSM_Memory (
    input clk,
    input rst,
    input Rx_in,
    input par_en, par_typ,         
    output Tx_out 
);

    parameter DATA_WIDTH = 8;
    parameter LOCATION_WIDTH = 8;
    // CMDs Encoding 
    parameter CMD_READ = 8'h0A;
    parameter CMD_WRITE = 8'h0B;

    // UART Signals 
    wire [4:0] prescale = 8; 
    wire rx_valid, tx_busy, rx_parity_err, rx_stp_err, rx_err;
    wire [7:0] rx_data;
    assign rx_err = rx_parity_err | rx_stp_err;
    reg tx_start;
    reg [7:0] tx_data;
    reg mem_en;
    reg mem_we;

    //detect the low edge of Busy to make Sure that Tx is done 
    reg tx_busy_q;
    always @(posedge clk or posedge rst) begin
        if (rst) 
            tx_busy_q <= 0;
        else     
            tx_busy_q <= tx_busy;
    end
    wire tx_done = (tx_busy_q && !tx_busy);

    // STATES  Encoding 
    parameter WAIT_CMD = 0, WAIT_RD_ADDR = 1, READ_MEM = 2, READ_WAIT = 3, TX_DATA = 4, WAIT_WR_ADDR = 5, WAIT_WR_DATA = 6, WRITE_MEM = 7;

    reg [2:0] cs, ns;

    //Registers to capture the data 
    reg [LOCATION_WIDTH-1:0] ram_addr_reg;
    reg [DATA_WIDTH-1:0]     ram_data_in_reg;

    wire [DATA_WIDTH-1:0]    ram_data_out;

    //RAM INS
    RAM RAM_inst (
        .clk(clk),
        .rst(rst),
        .en(mem_en),
        .mem_we(mem_we),
        .addr(ram_addr_reg),
        .data_in(ram_data_in_reg),
        .data_out(ram_data_out)
    );

    Rx_UART Rx_MEM (
        .clk(clk),
        .rst(rst),
        .Rx_in(Rx_in),
        .prescale(prescale),
        .par_en(par_en),
        .par_typ(par_typ),
        .P_data(rx_data),
        .data_valid(rx_valid),
        .PARITY_ERROR(rx_parity_err),
        .STP_ERROR(rx_stp_err)
    );

    Tx_UART Tx_MEM (
        .clk(clk),
        .rst(rst),
        .P_data(tx_data),
        .data_valid(tx_start), 
        .par_en(par_en),
        .par_typ(par_typ),
        .prescale(prescale), 
        .Tx_out(Tx_out),
        .Busy(tx_busy)    
    );

    //STATE REG
    always @(posedge clk or posedge rst) begin
        if (rst) 
            cs <= WAIT_CMD;
        else     
            cs <= ns;
    end

    // Next State Logic
    always @(*) begin
        ns = cs; // if there is no transition stay in the current state 

        tx_start = 0;
        tx_data = 0;
        mem_we = 0;
        mem_en = 0;

        case (cs)
            WAIT_CMD: begin //waiting for the Rx to complete deserializition without errors 
                if (rx_valid && !rx_err) begin 
                    if (rx_data == CMD_READ) 
                        ns = WAIT_RD_ADDR;
                    else if (rx_data == CMD_WRITE) 
                        ns = WAIT_WR_ADDR;
                end
            end

            WAIT_RD_ADDR: begin 
                if (rx_valid) begin
                    if (rx_err) 
                        ns = WAIT_CMD;
                    else 
                        ns = READ_MEM;
                end 
            end


            READ_MEM: begin
                mem_en = 1;
                ns     = READ_WAIT; 
            end


            READ_WAIT: begin // Waiting the data from RAM
                mem_en = 1;
                ns     = TX_DATA;
            end

            TX_DATA: begin //Sending DATA
                tx_data = ram_data_out;
                if (!tx_busy && !tx_busy_q) 
                    tx_start = 1; // Start of Tx

                if (tx_done) 
                    ns = WAIT_CMD; 
            end

            WAIT_WR_ADDR: begin
                if (rx_valid) begin
                    if (rx_err) 
                        ns = WAIT_CMD;
                    else 
                        ns = WAIT_WR_DATA;
                end 
            end

            WAIT_WR_DATA: begin
                if (rx_valid) begin
                    if (rx_err) 
                        ns = WAIT_CMD;
                    else 
                        ns = WRITE_MEM;
                end 
            end

            WRITE_MEM: begin
                mem_en = 1;
                mem_we = 1;
                ns = WAIT_CMD;
            end
            
            default: ns = WAIT_CMD;
        endcase
    end

    // output logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ram_addr_reg <= 0;
            ram_data_in_reg <= 0;
        end else begin
            if ((cs == WAIT_RD_ADDR || cs == WAIT_WR_ADDR) && rx_valid && !rx_err)
                ram_addr_reg <= rx_data; //capture the data address

            if (cs == WAIT_WR_DATA && rx_valid && !rx_err)
                ram_data_in_reg <= rx_data; // capture the data 
        end
    end

endmodule