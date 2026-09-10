module TB;
    logic clk, rst, EN, Cin, bypass_A, bypass_B, red_op_A, red_op_B, Serial_in, direction; 
    logic [7:0] location_A, location_B, location_C;
    logic [2:0] opcode;
    logic par_en, par_typ;
    logic [15:0] C; 
    logic [15:0] leds; 

    logic Cin_reg, bypass_A_reg, bypass_B_reg, red_op_A_reg, red_op_B_reg, Serial_in_reg, direction_reg;
    logic [2:0] opcode_reg;
    logic [7:0] A, B;
    logic alsu_en_reg;
    logic [15:0] C_expected; 
    logic [15:0] leds_expected; 

    // C in the location at mem 
    logic [15:0] C_in_MEM;

    assign C_in_MEM = {dut.Slave.RAM_inst.mem [location_C + 1],dut.Slave.RAM_inst.mem [location_C]};

    integer correct_count, error_count; 

    SoC_Top dut (.clk(clk), .rst(rst), .EN(EN), .Cin(Cin), .bypass_A(bypass_A), .bypass_B(bypass_B), .red_op_A(red_op_A), .red_op_B(red_op_B),
        .Serial_in(Serial_in), .direction(direction), .location_A(location_A), .location_B(location_B), .location_C(location_C), .opcode(opcode),
        .par_en(par_en), .par_typ(par_typ), .C(C), .leds(leds)
    );

    ALSU ALSU_golden(.A(A), .B(B), .cin(Cin_reg), .serial_in(Serial_in_reg), .red_op_A(red_op_A_reg), .red_op_B(red_op_B_reg), 
            .opcode(opcode_reg), .bypass_A(bypass_A_reg), .bypass_B(bypass_B_reg), .clk(clk), .rst(rst), .direction(direction_reg),
            .en(alsu_en_reg), .leds(leds_expected), .out(C_expected));

    initial begin
        clk = 0;
        forever #1 clk = !clk;
    end

    initial begin
        correct_count = 0; error_count = 0; 
        assert_reset();

        location_A = $urandom_range(0, 255); location_B = $urandom_range(0, 255); location_C = $urandom_range(0, 255);
        run_test_case("OR", 0, 0, 0, 0, 0, 0, 0, 0);

        location_A = $urandom_range(0, 255); location_B = $urandom_range(0, 255); location_C = $urandom_range(0, 255);
        run_test_case("XOR", 1, 0, 0, 0, 0, 0, 0, 0);

        location_A = $urandom_range(0, 255); location_B = $urandom_range(0, 255); location_C = $urandom_range(0, 255);
        run_test_case("ADD", 2, 0, 0, 0, 0, 0, 0, 0);

        location_A = $urandom_range(0, 255); location_B = $urandom_range(0, 255); location_C = $urandom_range(0, 255);
        run_test_case("ADD Cin", 2, 0, 0, 0, 0, 1, 0, 0);

        location_A = $urandom_range(0, 255); location_B = $urandom_range(0, 255); location_C = $urandom_range(0, 255);
        run_test_case("MULT", 3, 0, 0, 0, 0, 0, 0, 0);

        location_A = $urandom_range(0, 255); location_B = $urandom_range(0, 255); location_C = $urandom_range(0, 255);
        run_test_case("OR  Red_A ", 3'h0, 0, 0, 1, 0, 0, 0, 0);

        location_A = $urandom_range(0, 255); location_B = $urandom_range(0, 255); location_C = $urandom_range(0, 255);
        run_test_case("XOR Red_B ", 3'h1, 0, 0, 0, 1, 0, 0, 0);

        location_A = $urandom_range(0, 255); location_B = $urandom_range(0, 255); location_C = $urandom_range(0, 255);
        run_test_case("Bypass A  ", 3'h2, 1, 0, 0, 0, 0, 0, 0);

        location_A = $urandom_range(0, 255); location_B = $urandom_range(0, 255); location_C = $urandom_range(0, 255);
        run_test_case("Bypass A,B", 3'h3, 1, 1, 0, 0, 0, 0, 0); 

        location_A = $urandom_range(0, 255); location_B = $urandom_range(0, 255); location_C = $urandom_range(0, 255);
        run_test_case("Shift Left", 3'h4, 0, 0, 0, 0, 0, 1, 1);

        location_A = $urandom_range(0, 255); location_B = $urandom_range(0, 255); location_C = $urandom_range(0, 255);
        run_test_case("Rotate Rgt", 3'h5, 0, 0, 0, 0, 0, 0, 0);

        location_A = $urandom_range(0, 255); location_B = $urandom_range(0, 255); location_C = $urandom_range(0, 255);
        run_test_case("Invalid Op", 3'h6, 0, 0, 0, 0, 0, 0, 0);
        
        if (leds === leds_expected) 
            $display("Invalid Opcode toggled LEDs matching Golden Model.");
        else 
            $display("[FAIL] Invalid Opcode LEDs mismatch!");

        $display("Total Passed : %0d", correct_count);
        $display("Total Failed : %0d", error_count);
        $stop;
    end

    task assert_reset;
        rst = 1; 
        EN = 0; 
        Cin = 0; 
        bypass_A = 0; 
        bypass_B = 0; 
        red_op_A = 0; 
        red_op_B = 0; 
        Serial_in = 0; 
        direction = 0; 
        par_en = 0; 
        par_typ = 0; 
        location_A = 0; 
        location_B = 1; 
        location_C = 2; 
        opcode = 0;

        //initailization of RAM
        $readmemb("MEM.txt", dut.Slave.RAM_inst.mem);

        repeat (20) @(negedge clk);
        rst = 0;
        repeat (20) @(negedge clk);
    endtask 

    task setup_inputs; //capture data and make calc on the data in the golden model
        Cin_reg = Cin; 
        bypass_A_reg = bypass_A; 
        bypass_B_reg = bypass_B; 
        red_op_A_reg = red_op_A; 
        red_op_B_reg = red_op_B; 
        Serial_in_reg = Serial_in; 
        direction_reg = direction; 
        opcode_reg = opcode;
        
        A = dut.Slave.RAM_inst.mem [location_A];
        B = dut.Slave.RAM_inst.mem [location_B];
        
        alsu_en_reg = 1;
        @(negedge clk);
        @(negedge clk); // PIPELINE BUG FIXED: Added 2nd edge to allow ALSU to compute
        alsu_en_reg = 0;
    endtask 

    task Check_result(input string test_name); 
        begin
            if (C_in_MEM !== C_expected) begin 
                error_count = error_count + 1;
                $display("FAIL %s  ERROR: A=%0h, B=%0h, Op=%0b, C_in_mem=%0h, C_Exp=%0h", test_name, A, B, opcode_reg, C_in_MEM, C_expected);
            end else begin
                correct_count = correct_count + 1;
                $display("PASS %s A=%0h, B=%0h, Op=%0b, C_in_mem=%0h, C_Exp=%0h", test_name, A, B, opcode_reg, C_in_MEM, C_expected);
            end
        end
    endtask

    task run_test_case(input string name, input [2:0] op, input logic bp_A, bp_B, r_A, r_B, c_in, s_in, dir);
            opcode = op; 
            bypass_A = bp_A; 
            bypass_B = bp_B; 
            red_op_A = r_A; 
            red_op_B = r_B; 
            Cin = c_in; 
            Serial_in = s_in; 
            direction = dir;

            setup_inputs();

            @(negedge clk);
            EN = 1;
            @(negedge clk);
            EN = 0;

            wait(dut.Master.cs != 0);
            wait (dut.Slave.cs != 0);
            wait(dut.Master.cs == 0); 
            wait (dut.Slave.cs == 0);

            repeat(2) @(negedge clk);
            Check_result(name);
    endtask
endmodule