module ALSU (
    input clk, cin, rst, red_op_A, red_op_B, bypass_A, bypass_B, direction, serial_in, en,
    input [2:0] opcode,
    input signed [7:0] A, B,
    output reg [15:0] leds,
    output reg signed [15:0] out
);
    parameter INPUT_PRIORITY = "A";
    parameter FULL_ADDER = "ON";


    //Registers to capture the Data
    reg red_op_A_reg, red_op_B_reg, bypass_A_reg, bypass_B_reg, direction_reg, serial_in_reg;
    reg signed cin_reg; 
    reg [2:0] opcode_reg;
    reg signed [7:0] A_reg, B_reg;

    //Invalid Checkers
    wire invalid_red_op = (red_op_A_reg | red_op_B_reg) & (opcode_reg != 0 && opcode_reg != 1);
    wire invalid_opcode = (opcode_reg ==  6) || (opcode_reg == 7);
    wire invalid = invalid_red_op | invalid_opcode;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cin_reg <= 0; 
            red_op_B_reg <= 0; 
            red_op_A_reg <= 0;
            bypass_B_reg <= 0; 
            bypass_A_reg <= 0; 
            direction_reg <= 0;
            serial_in_reg <= 0; 
            opcode_reg <= 0; 
            A_reg <= 0; 
            B_reg <= 0;
        end else if (en) begin //capture the data
            cin_reg <= cin; 
            red_op_B_reg <= red_op_B; 
            red_op_A_reg <= red_op_A;
            bypass_B_reg <= bypass_B; 
            bypass_A_reg <= bypass_A; 
            direction_reg <= direction;
            serial_in_reg <= serial_in; 
            opcode_reg <= opcode; 
            A_reg <= A; 
            B_reg <= B;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) 
            leds <= 0;
        else if (en) begin
            if (invalid) //Toggle the Leds 
                leds <= ~leds;
            else
                leds <= 0;
        end
    end

    always @(posedge clk or posedge rst) begin

        if (rst) begin
            out <= 0;
        end else if (en) begin
            if (bypass_A_reg && bypass_B_reg)begin
                if (INPUT_PRIORITY == "A")
                    out <= {{8{A_reg[7]}}, A_reg}; 
                else 
                    out <= {{8{B_reg[7]}}, B_reg};
            end

            else if (bypass_A_reg) 
                out <= {{8{A_reg[7]}}, A_reg};
            else if (bypass_B_reg) 
                out <= {{8{B_reg[7]}}, B_reg};
            else if (invalid) 
                out <= 0;


            else begin
                case (opcode_reg)

                    3'h0: begin // OR
                        if (red_op_A_reg && red_op_B_reg)begin 
                            if (INPUT_PRIORITY == "A")
                                out <= {15'b0, |A_reg};
                            else 
                                out <= {15'b0, |B_reg};
                        end 
                        else if (red_op_A_reg) 
                            out <= {15'b0, |A_reg};
                        else if (red_op_B_reg) 
                            out <= {15'b0, |B_reg};
                        else 
                            out <= {8'b0, (A_reg | B_reg)}; // Zero-extended logic
                    end

                    3'h1: begin // XOR
                        if (red_op_A_reg && red_op_B_reg)begin 
                            if (INPUT_PRIORITY == "A")
                                out <= {15'b0, ^A_reg};
                            else 
                                out <= {15'b0, ^B_reg};
                        end
                        else if (red_op_A_reg) 
                            out <= {15'b0, ^A_reg};
                        else if (red_op_B_reg) 
                            out <= {15'b0, ^B_reg};
                        else 
                            out <= {8'b0, (A_reg ^ B_reg)}; // Zero-extended logic
                    end

                    3'h2: begin // ADD
                        if (FULL_ADDER == "ON") 
                            out <= A_reg + B_reg + cin_reg;
                        else 
                            out <= A_reg + B_reg;
                    end


                    3'h3: begin // MULT
                        out <= A_reg * B_reg;
                    end


                    3'h4: begin // SHIFT
                        if (direction_reg) 
                            out <= {out[14:0], serial_in_reg};
                        else
                            out <= {serial_in_reg, out[15:1]};
                    end

                    3'h5: begin // ROTATE
                        if (direction_reg) 
                            out <= {out[14:0], out[15]};
                        else               
                            out <= {out[0], out[15:1]};
                    end
                    
                    default: out <= 0;
                endcase
            end
        end
    end
endmodule