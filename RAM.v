module RAM (
    input clk,
    input rst,
    input en,           
    input mem_we,
    input [7:0] addr, 
    input [7:0] data_in,
    output reg [7:0] data_out
);
    parameter DATA_WIDTH = 8;
    parameter MEM_DEPTH = 256;

    reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            data_out <= 0;
        end else if (en) begin  
            if (mem_we) begin //if Write process
                mem[addr] <= data_in; 
            end
            else 
                data_out <= mem[addr];
        end
    end
endmodule