module SoC_Top (
    input clk,
    input rst,
    input EN, 
    input Cin, 
    input bypass_A, bypass_B, 
    input red_op_A, red_op_B, 
    input Serial_in, direction,
    input [7:0] location_A, location_B, location_C,
    input [2:0] opcode,
    input par_en, par_typ,
    output [15:0] C,
    output [15:0] leds
);
    // wires to connect the two IPs
    wire master_tx_to_slave_rx;
    wire slave_tx_to_master_rx;

    FSM_ALSU Master (
        .clk(clk), 
        .EN(EN), 
        .rst(rst), 
        .Cin(Cin), 
        .bypass_A(bypass_A), 
        .bypass_B(bypass_B), 
        .red_op_A(red_op_A), 
        .red_op_B(red_op_B), 
        .Serial_in(Serial_in), 
        .direction(direction),
        .location_A(location_A), 
        .location_B(location_B), 
        .location_C(location_C),
        .opcode(opcode),
        .par_en(par_en), 
        .par_typ(par_typ),
        .Rx_in(slave_tx_to_master_rx),  
        .Tx_out(master_tx_to_slave_rx), 
        .C(C), 
        .leds(leds)
    );

    FSM_Memory Slave (
        .clk(clk),
        .rst(rst),
        .par_en(par_en), 
        .par_typ(par_typ),
        .Rx_in(master_tx_to_slave_rx),  
        .Tx_out(slave_tx_to_master_rx) 
    );

endmodule