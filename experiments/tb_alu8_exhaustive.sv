`timescale 1ns/1ps

module tb_alu8_exhaustive;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst_n = 1'b0;
    reg in_valid = 1'b0;
    reg [2:0] in_op = 3'd0;
    reg [7:0] in_a = 8'd0;
    reg [7:0] in_b = 8'd0;

    wire out_valid;
    wire [7:0] out_result;
    wire out_zero;
    wire out_carry;
    wire out_overflow;

    reg expected_valid = 1'b0;
    reg [10:0] expected = 11'd0;
    integer checked = 0;
    integer op_i, a_i, b_i;

    alu8_pipeline dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_op(in_op),
        .in_a(in_a),
        .in_b(in_b),
        .out_valid(out_valid),
        .out_result(out_result),
        .out_zero(out_zero),
        .out_carry(out_carry),
        .out_overflow(out_overflow)
    );

    // Packed reference result: {zero, carry, overflow, result}.
    function automatic [10:0] reference_result;
        input [2:0] op;
        input [7:0] a;
        input [7:0] b;
        reg [8:0] wide;
        reg [7:0] result;
        reg carry;
        reg overflow;
        integer amount;
        begin
            wide = 9'd0;
            result = 8'd0;
            carry = 1'b0;
            overflow = 1'b0;
            amount = b[2:0];

            case (op)
                3'd0: begin
                    wide = {1'b0, a} + {1'b0, b};
                    result = wide[7:0];
                    carry = wide[8];
                    overflow = (~(a[7] ^ b[7])) & (result[7] ^ a[7]);
                end
                3'd1: begin
                    wide = {1'b0, a} - {1'b0, b};
                    result = wide[7:0];
                    carry = ~wide[8];
                    overflow = (a[7] ^ b[7]) & (result[7] ^ a[7]);
                end
                3'd2: result = a & b;
                3'd3: result = a | b;
                3'd4: result = a ^ b;
                3'd5: begin
                    result = a << amount;
                    if (amount != 0)
                        carry = (a >> (8 - amount)) & 1'b1;
                end
                3'd6: begin
                    result = a >> amount;
                    if (amount != 0)
                        carry = (a >> (amount - 1)) & 1'b1;
                end
                default: begin
                    result = 8'd0;
                    carry = 1'b0;
                    overflow = 1'b0;
                end
            endcase

            reference_result = {(result == 8'd0), carry, overflow, result};
        end
    endfunction

    task check_previous_result;
        begin
            if (out_valid !== expected_valid) begin
                $display("FAIL: valid mismatch at checked=%0d expected=%b got=%b",
                         checked, expected_valid, out_valid);
                $fatal(1);
            end

            if (expected_valid) begin
                if ({out_zero, out_carry, out_overflow, out_result} !== expected) begin
                    $display("FAIL: case=%0d expected=%03h got=%03h",
                             checked, expected,
                             {out_zero, out_carry, out_overflow, out_result});
                    $fatal(1);
                end
                checked = checked + 1;
            end
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        for (op_i = 0; op_i < 8; op_i = op_i + 1) begin
            for (a_i = 0; a_i < 256; a_i = a_i + 1) begin
                for (b_i = 0; b_i < 256; b_i = b_i + 1) begin
                    @(negedge clk);
                    in_valid = 1'b1;
                    in_op = op_i[2:0];
                    in_a = a_i[7:0];
                    in_b = b_i[7:0];

                    @(posedge clk);
                    #1;
                    check_previous_result();

                    expected_valid = 1'b1;
                    expected = reference_result(in_op, in_a, in_b);
                end
            end
        end

        @(negedge clk);
        in_valid = 1'b0;

        @(posedge clk);
        #1;
        check_previous_result();
        expected_valid = 1'b0;

        @(posedge clk);
        #1;
        if (out_valid !== 1'b0) begin
            $display("FAIL: out_valid did not clear after the final result");
            $fatal(1);
        end

        if (checked != 524288) begin
            $display("FAIL: checked %0d cases; expected 524288", checked);
            $fatal(1);
        end

        $display("PASS: exhaustive all-opcode check; %0d cases", checked);
        $finish;
    end

    initial begin
        #10000000;
        $display("FAIL: exhaustive all-opcode test timed out");
        $fatal(1);
    end
endmodule