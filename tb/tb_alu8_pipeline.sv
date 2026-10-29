`timescale 1ns/1ps

module tb_alu8_pipeline;
    localparam logic [2:0] OP_ADD = 3'd0;
    localparam logic [2:0] OP_SUB = 3'd1;
    localparam logic [2:0] OP_AND = 3'd2;
    localparam logic [2:0] OP_OR  = 3'd3;
    localparam logic [2:0] OP_XOR = 3'd4;
    localparam logic [2:0] OP_SLL = 3'd5;
    localparam logic [2:0] OP_SRL = 3'd6;
    localparam integer STREAM_LENGTH = 64;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic in_valid = 1'b0;
    logic [2:0] in_op = 3'd0;
    logic [7:0] in_a = 8'd0, in_b = 8'd0;
    logic out_valid;
    logic [7:0] out_result;
    logic out_zero, out_carry, out_overflow;

    logic [2:0] stream_op [0:STREAM_LENGTH-1];
    logic [7:0] stream_a  [0:STREAM_LENGTH-1];
    logic [7:0] stream_b  [0:STREAM_LENGTH-1];
    logic [31:0] lfsr;
    logic [10:0] expected;
    integer directed_checks = 0;
    integer stream_checks = 0;
    integer i;

    alu8_pipeline dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .in_op(in_op), .in_a(in_a), .in_b(in_b),
        .out_valid(out_valid), .out_result(out_result),
        .out_zero(out_zero), .out_carry(out_carry),
        .out_overflow(out_overflow)
    );

    always #5 clk = ~clk;

    // Independent reference model. Packed return value:
    // [10]=overflow, [9]=carry/no-borrow, [8]=zero, [7:0]=result.
    function automatic logic [10:0] reference_result(
        input logic [2:0] op,
        input logic [7:0] a,
        input logic [7:0] b
    );
        logic [8:0] wide;
        logic [7:0] result_value;
        logic carry_value, overflow_value;
        begin
            wide = 9'd0;
            result_value = 8'd0;
            carry_value = 1'b0;
            overflow_value = 1'b0;
            case (op)
                OP_ADD: begin
                    wide = {1'b0, a} + {1'b0, b};
                    result_value = wide[7:0];
                    carry_value = wide[8];
                    overflow_value = (~(a[7] ^ b[7])) &
                                     (result_value[7] ^ a[7]);
                end
                OP_SUB: begin
                    wide = {1'b0, a} - {1'b0, b};
                    result_value = wide[7:0];
                    carry_value = ~wide[8];
                    overflow_value = (a[7] ^ b[7]) &
                                     (result_value[7] ^ a[7]);
                end
                OP_AND: result_value = a & b;
                OP_OR:  result_value = a | b;
                OP_XOR: result_value = a ^ b;
                OP_SLL: begin
                    result_value = a << b[2:0];
                    if (b[2:0] != 0)
                        carry_value = a[8 - b[2:0]];
                end
                OP_SRL: begin
                    result_value = a >> b[2:0];
                    if (b[2:0] != 0)
                        carry_value = a[b[2:0] - 1'b1];
                end
                default: begin
                    result_value = 8'd0;
                    carry_value = 1'b0;
                    overflow_value = 1'b0;
                end
            endcase
            reference_result = {overflow_value, carry_value,
                                (result_value == 8'd0), result_value};
        end
    endfunction

    task automatic check_directed(
        input logic [2:0] op,
        input logic [7:0] a,
        input logic [7:0] b,
        input logic [7:0] expected_result,
        input logic expected_carry,
        input logic expected_overflow,
        input logic expected_zero
    );
        begin
            @(negedge clk);
            in_valid = 1'b1;
            in_op = op;
            in_a = a;
            in_b = b;
            @(posedge clk);       // request enters stage 1
            @(negedge clk);
            in_valid = 1'b0;
            @(posedge clk); #1;    // result is registered by stage 2

            if (!out_valid || out_result !== expected_result ||
                out_carry !== expected_carry ||
                out_overflow !== expected_overflow ||
                out_zero !== expected_zero) begin
                $display("FAIL directed: op=%0d A=%02h B=%02h got R=%02h Z=%b C=%b V=%b expected R=%02h Z=%b C=%b V=%b",
                         op, a, b, out_result, out_zero, out_carry,
                         out_overflow, expected_result, expected_zero,
                         expected_carry, expected_overflow);
                $fatal(1);
            end
            directed_checks = directed_checks + 1;
        end
    endtask

    task automatic check_stream_item(input integer index);
        begin
            expected = reference_result(stream_op[index],
                                        stream_a[index], stream_b[index]);
            if (!out_valid || out_result !== expected[7:0] ||
                out_zero !== expected[8] ||
                out_carry !== expected[9] ||
                out_overflow !== expected[10]) begin
                $display("FAIL stream[%0d]: op=%0d A=%02h B=%02h got R=%02h Z=%b C=%b V=%b expected packed=%03h",
                         index, stream_op[index], stream_a[index],
                         stream_b[index], out_result, out_zero, out_carry,
                         out_overflow, expected);
                $fatal(1);
            end
            stream_checks = stream_checks + 1;
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        // Directed operation and flag checks.
        check_directed(OP_ADD, 8'h12, 8'h34, 8'h46, 0, 0, 0);
        check_directed(OP_ADD, 8'hff, 8'h01, 8'h00, 1, 0, 1);
        check_directed(OP_ADD, 8'h7f, 8'h01, 8'h80, 0, 1, 0);
        check_directed(OP_SUB, 8'h09, 8'h04, 8'h05, 1, 0, 0);
        check_directed(OP_SUB, 8'h03, 8'h04, 8'hff, 0, 0, 0);
        check_directed(OP_SUB, 8'h80, 8'h01, 8'h7f, 1, 1, 0);
        check_directed(OP_AND, 8'hf0, 8'h0f, 8'h00, 0, 0, 1);
        check_directed(OP_OR,  8'h80, 8'h01, 8'h81, 0, 0, 0);
        check_directed(OP_XOR, 8'haa, 8'hff, 8'h55, 0, 0, 0);
        check_directed(OP_SLL, 8'h81, 8'h01, 8'h02, 1, 0, 0);
        check_directed(OP_SLL, 8'h5a, 8'h00, 8'h5a, 0, 0, 0);
        check_directed(OP_SRL, 8'h81, 8'h01, 8'h40, 1, 0, 0);
        check_directed(OP_SRL, 8'h5a, 8'h00, 8'h5a, 0, 0, 0);
        check_directed(3'd7, 8'hff, 8'hff, 8'h00, 0, 0, 1);

        // Build reproducible pseudo-random traffic, including reserved opcode.
        lfsr = 32'h1ace_b00c;
        for (i = 0; i < STREAM_LENGTH; i = i + 1) begin
            lfsr = {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
            stream_op[i] = lfsr[2:0];
            stream_a[i]  = lfsr[15:8];
            stream_b[i]  = lfsr[23:16];
        end

        // Send one request every cycle and check ordered results as they return.
        for (i = 0; i < STREAM_LENGTH; i = i + 1) begin
            @(negedge clk);
            in_valid = 1'b1;
            in_op = stream_op[i];
            in_a = stream_a[i];
            in_b = stream_b[i];
            @(posedge clk); #1;
            if (i == 0) begin
                if (out_valid) begin
                    $display("FAIL: unexpected valid before first stream result");
                    $fatal(1);
                end
            end else begin
                check_stream_item(i - 1);
            end
        end

        // Drain and check the last pipeline result.
        @(negedge clk);
        in_valid = 1'b0;
        @(posedge clk); #1;
        check_stream_item(STREAM_LENGTH - 1);
        @(posedge clk); #1;
        if (out_valid) begin
            $display("FAIL: out_valid did not clear after the stream drained");
            $fatal(1);
        end

        $display("PASS: %0d directed checks; %0d consecutive pseudo-random requests; one request per cycle",
                 directed_checks, stream_checks);
        $finish;
    end

    initial begin
        #10000;
        $display("FAIL: testbench timeout");
        $fatal(1);
    end
endmodule
