`timescale 1ns/1ps

// Exhaustively checks every opcode and 8-bit operand pair for the two-cycle
// three-stage ALU. Requests are issued on consecutive cycles, then the pipe is
// drained and the accepted/checked counts are compared.
module tb_alu8_3stage_exhaustive;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic in_valid = 1'b0;
    logic [2:0] in_op = 3'd0;
    logic [7:0] in_a = 8'd0;
    logic [7:0] in_b = 8'd0;

    wire out_valid;
    wire [7:0] out_result;
    wire out_zero, out_carry, out_overflow;

    logic expected_valid_0 = 1'b0;
    logic expected_valid_1 = 1'b0;
    logic [10:0] expected_data_0 = 11'd0;
    logic [10:0] expected_data_1 = 11'd0;
    logic [18:0] expected_tag_0 = 19'd0;
    logic [18:0] expected_tag_1 = 19'd0;

    integer sent = 0;
    integer checked = 0;
    integer op_i, a_i, b_i;

    localparam logic [2:0] OP_ADD = 3'd0;
    localparam logic [2:0] OP_SUB = 3'd1;
    localparam logic [2:0] OP_AND = 3'd2;
    localparam logic [2:0] OP_OR  = 3'd3;
    localparam logic [2:0] OP_XOR = 3'd4;
    localparam logic [2:0] OP_SLL = 3'd5;
    localparam logic [2:0] OP_SRL = 3'd6;

    alu8_pipeline dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .in_op(in_op), .in_a(in_a), .in_b(in_b),
        .out_valid(out_valid), .out_result(out_result),
        .out_zero(out_zero), .out_carry(out_carry),
        .out_overflow(out_overflow)
    );

    always #5 clk = ~clk;

    function automatic [10:0] model(
        input logic [2:0] op,
        input logic [7:0] a,
        input logic [7:0] b
    );
        logic [8:0] wide;
        logic [7:0] result;
        logic z, c, v;
        begin
            wide = 9'd0;
            result = 8'd0;
            z = 1'b0;
            c = 1'b0;
            v = 1'b0;

            case (op)
                OP_ADD: begin
                    wide = {1'b0, a} + {1'b0, b};
                    result = wide[7:0];
                    c = wide[8];
                    v = (~(a[7] ^ b[7])) & (result[7] ^ a[7]);
                end
                OP_SUB: begin
                    wide = {1'b0, a} - {1'b0, b};
                    result = wide[7:0];
                    c = ~wide[8];
                    v = (a[7] ^ b[7]) & (result[7] ^ a[7]);
                end
                OP_AND: result = a & b;
                OP_OR:  result = a | b;
                OP_XOR: result = a ^ b;
                OP_SLL: begin
                    result = a << b[2:0];
                    if (b[2:0] != 3'd0)
                        c = (a >> (8 - b[2:0])) & 1'b1;
                end
                OP_SRL: begin
                    result = a >> b[2:0];
                    if (b[2:0] != 3'd0)
                        c = (a >> (b[2:0] - 1'b1)) & 1'b1;
                end
                default: result = 8'd0;
            endcase

            z = (result == 8'd0);
            model = {z, c, v, result};
        end
    endfunction

    // Match the DUT's two-cycle request-to-output latency.
    always @(posedge clk) begin
        if (!rst_n) begin
            expected_valid_0 = 1'b0;
            expected_valid_1 = 1'b0;
            expected_data_0 = 11'd0;
            expected_data_1 = 11'd0;
            expected_tag_0 = 19'd0;
            expected_tag_1 = 19'd0;
            sent = 0;
            checked = 0;
        end else begin
            #1;
            if (out_valid !== expected_valid_1)
                $fatal(1, "valid mismatch at checked=%0d: got %b expected %b",
                       checked, out_valid, expected_valid_1);

            if (expected_valid_1) begin
                if ({out_zero, out_carry, out_overflow, out_result}
                    !== expected_data_1)
                    $fatal(1,
                        "mismatch op=%0d a=%02h b=%02h: got %03h expected %03h",
                        expected_tag_1[18:16], expected_tag_1[15:8],
                        expected_tag_1[7:0],
                        {out_zero, out_carry, out_overflow, out_result},
                        expected_data_1);
                checked = checked + 1;
            end

            expected_valid_1 = expected_valid_0;
            expected_data_1 = expected_data_0;
            expected_tag_1 = expected_tag_0;
            expected_valid_0 = in_valid;

            if (in_valid) begin
                expected_data_0 = model(in_op, in_a, in_b);
                expected_tag_0 = {in_op, in_a, in_b};
                sent = sent + 1;
            end
        end
    end

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        // Cover all 8 opcode values and all 65,536 operand pairs per opcode.
        for (op_i = 0; op_i < 8; op_i = op_i + 1) begin
            for (a_i = 0; a_i < 256; a_i = a_i + 1) begin
                for (b_i = 0; b_i < 256; b_i = b_i + 1) begin
                    @(negedge clk);
                    in_valid = 1'b1;
                    in_op = op_i[2:0];
                    in_a = a_i[7:0];
                    in_b = b_i[7:0];
                end
            end
        end

        @(negedge clk);
        in_valid = 1'b0;
        in_op = 3'd0;
        in_a = 8'd0;
        in_b = 8'd0;

        repeat (3) @(posedge clk);
        #2;

        if (sent != 524288 || checked != 524288)
            $fatal(1, "count mismatch: sent=%0d checked=%0d", sent, checked);

        $display("PASS: exhaustive three-stage ALU check; 524288 cases; 2-cycle latency; one request per cycle");
        $finish;
    end

    initial begin
        #6000000;
        $fatal(1, "Testbench timeout");
    end
endmodule
