`timescale 1ns/1ps

module tb_alu8_pipeline_3stage;
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

    integer sent = 0;
    integer checked = 0;

    localparam logic [2:0] OP_ADD = 3'd0;
    localparam logic [2:0] OP_SUB = 3'd1;
    localparam logic [2:0] OP_AND = 3'd2;
    localparam logic [2:0] OP_OR  = 3'd3;
    localparam logic [2:0] OP_XOR = 3'd4;
    localparam logic [2:0] OP_SLL = 3'd5;
    localparam logic [2:0] OP_SRL = 3'd6;

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

    task automatic send(
        input logic valid,
        input logic [2:0] op,
        input logic [7:0] a,
        input logic [7:0] b
    );
        begin
            @(negedge clk);
            in_valid = valid;
            in_op = op;
            in_a = a;
            in_b = b;
        end
    endtask

    // Check output two cycles after each accepted request.
    always @(posedge clk) begin
        if (!rst_n) begin
            expected_valid_0 = 1'b0;
            expected_valid_1 = 1'b0;
            expected_data_0 = 11'd0;
            expected_data_1 = 11'd0;
            sent = 0;
            checked = 0;
        end else begin
            #1;
            if (out_valid !== expected_valid_1)
                $fatal(1, "valid mismatch: got %b expected %b",
                       out_valid, expected_valid_1);

            if (expected_valid_1) begin
                if ({out_zero, out_carry, out_overflow, out_result}
                    !== expected_data_1)
                    $fatal(1, "data/flags mismatch: got %h expected %h",
                           {out_zero, out_carry, out_overflow, out_result},
                           expected_data_1);
                checked = checked + 1;
            end

            expected_valid_1 = expected_valid_0;
            expected_data_1 = expected_data_0;
            expected_valid_0 = in_valid;

            if (in_valid) begin
                expected_data_0 = model(in_op, in_a, in_b);
                sent = sent + 1;
            end
        end
    end

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        // Directed arithmetic, flag, logic, shift, and reserved-op cases.
        send(1, OP_ADD, 8'h09, 8'h04);
        send(1, OP_ADD, 8'hF0, 8'h30);
        send(1, OP_ADD, 8'h7F, 8'h01);
        send(1, OP_SUB, 8'h09, 8'h04);
        send(1, OP_SUB, 8'h04, 8'h09);
        send(1, OP_SUB, 8'h80, 8'h01);
        send(1, OP_AND, 8'hA5, 8'h3C);
        send(1, OP_OR,  8'hA5, 8'h3C);
        send(1, OP_XOR, 8'hA5, 8'hA5);
        send(1, OP_SLL, 8'h81, 8'h00);
        send(1, OP_SLL, 8'h81, 8'h01);
        send(1, OP_SRL, 8'h81, 8'h01);
        send(1, OP_SRL, 8'h80, 8'h07);
        send(1, 3'd7,   8'h55, 8'hAA);

        // Back-to-back requests check one-request-per-cycle throughput.
        repeat (64)
            send(1, $urandom_range(0, 7), $urandom, $urandom);

        // Insert bubbles to drain the pipeline.
        repeat (3)
            send(0, 3'd0, 8'd0, 8'd0);

        repeat (3) @(posedge clk);
        #2;

        if (sent != 78 || checked != 78)
            $fatal(1, "count mismatch: sent=%0d checked=%0d", sent, checked);

        $display("PASS: 14 directed checks; 64 consecutive pseudo-random requests; 2-cycle latency; one request per cycle");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Testbench timeout");
    end
endmodule