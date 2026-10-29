`timescale 1ns/1ps

module tb_alu8_addsub_exhaustive;
    reg clk = 1'b0;
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

    reg exp_valid = 1'b0;
    reg [10:0] exp_bundle = 11'd0;
    integer checked = 0;
    integer op, a, b;

    always #5 clk = ~clk;

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

    function automatic [10:0] reference_result;
        input [2:0] op;
        input [7:0] a;
        input [7:0] b;
        reg [8:0] temp;
        reg [7:0] result;
        reg carry;
        reg overflow;
        reg zero;
        begin
            temp = 9'd0;
            result = 8'd0;
            carry = 1'b0;
            overflow = 1'b0;

            case (op)
                3'd0: begin
                    temp = {1'b0, a} + {1'b0, b};
                    result = temp[7:0];
                    carry = temp[8];
                    overflow = (~(a[7] ^ b[7])) & (result[7] ^ a[7]);
                end

                3'd1: begin
                    temp = {1'b0, a} - {1'b0, b};
                    result = temp[7:0];
                    carry = (a >= b);
                    overflow = (a[7] ^ b[7]) & (result[7] ^ a[7]);
                end

                default: begin
                    result = 8'd0;
                    carry = 1'b0;
                    overflow = 1'b0;
                end
            endcase

            zero = (result == 8'd0);
            reference_result = {overflow, carry, zero, result};
        end
    endfunction

    always @(posedge clk) begin
        #1;
        if (!rst_n) begin
            exp_valid = 1'b0;
            exp_bundle = 11'd0;
        end else begin
            if (out_valid !== exp_valid)
                $fatal(1, "valid mismatch at checked=%0d", checked);

            if (exp_valid &&
                {out_overflow, out_carry, out_zero, out_result} !== exp_bundle)
                $fatal(1,
                    "mismatch at checked=%0d got=%h expected=%h",
                    checked,
                    {out_overflow, out_carry, out_zero, out_result},
                    exp_bundle);

            if (exp_valid)
                checked = checked + 1;

            exp_valid = in_valid;
            if (in_valid)
                exp_bundle = reference_result(in_op, in_a, in_b);
        end
    end

    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        for (op = 0; op < 2; op = op + 1) begin
            for (a = 0; a < 256; a = a + 1) begin
                for (b = 0; b < 256; b = b + 1) begin
                    @(negedge clk);
                    in_valid = 1'b1;
                    in_op = op[2:0];
                    in_a = a[7:0];
                    in_b = b[7:0];
                end
            end
        end

        @(negedge clk);
        in_valid = 1'b0;

        repeat (2) @(posedge clk);
        #2;

        if (checked != 131072)
            $fatal(1, "expected 131072 checks, got %0d", checked);

        $display("PASS: exhaustive ADD/SUB check; %0d cases", checked);
        $finish;
    end
endmodule