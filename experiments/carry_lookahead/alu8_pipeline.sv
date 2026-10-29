`timescale 1ns/1ps

// Two-stage, one-result-per-cycle 8-bit ALU.
// ADD and SUB use a two-block carry-lookahead structure.
module alu8_pipeline (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       in_valid,
    input  logic [2:0] in_op,
    input  logic [7:0] in_a,
    input  logic [7:0] in_b,
    output logic       out_valid,
    output logic [7:0] out_result,
    output logic       out_zero,
    output logic       out_carry,
    output logic       out_overflow
);
    localparam logic [2:0] OP_ADD = 3'd0;
    localparam logic [2:0] OP_SUB = 3'd1;
    localparam logic [2:0] OP_AND = 3'd2;
    localparam logic [2:0] OP_OR  = 3'd3;
    localparam logic [2:0] OP_XOR = 3'd4;
    localparam logic [2:0] OP_SLL = 3'd5;
    localparam logic [2:0] OP_SRL = 3'd6;

    // Pipeline stage 1 captures the request.
    logic [2:0] op_s1;
    logic [7:0] a_s1, b_s1;
    logic       valid_s1;

    // Carry-lookahead arithmetic signals.
    logic       subtract;
    logic [7:0] arithmetic_b;
    logic [7:0] propagate;
    logic [7:0] generate_bit;
    logic [8:0] carry;
    logic [7:0] arithmetic_result;

    logic [7:0] result_comb;
    logic       carry_comb, overflow_comb, zero_comb;

    always_comb begin
        subtract    = (op_s1 == OP_SUB);
        arithmetic_b = b_s1 ^ {8{subtract}};
        propagate   = a_s1 ^ arithmetic_b;
        generate_bit = a_s1 & arithmetic_b;

        carry = 9'd0;
        carry[0] = subtract;

        // Lookahead carries for bits 0 through 3.
        carry[1] = generate_bit[0] |
                   (propagate[0] & carry[0]);

        carry[2] = generate_bit[1] |
                   (propagate[1] & generate_bit[0]) |
                   (propagate[1] & propagate[0] & carry[0]);

        carry[3] = generate_bit[2] |
                   (propagate[2] & generate_bit[1]) |
                   (propagate[2] & propagate[1] & generate_bit[0]) |
                   (propagate[2] & propagate[1] & propagate[0] & carry[0]);

        carry[4] = generate_bit[3] |
                   (propagate[3] & generate_bit[2]) |
                   (propagate[3] & propagate[2] & generate_bit[1]) |
                   (propagate[3] & propagate[2] & propagate[1] & generate_bit[0]) |
                   (propagate[3] & propagate[2] & propagate[1] &
                    propagate[0] & carry[0]);

        // Lookahead carries for bits 4 through 7, using carry[4].
        carry[5] = generate_bit[4] |
                   (propagate[4] & carry[4]);

        carry[6] = generate_bit[5] |
                   (propagate[5] & generate_bit[4]) |
                   (propagate[5] & propagate[4] & carry[4]);

        carry[7] = generate_bit[6] |
                   (propagate[6] & generate_bit[5]) |
                   (propagate[6] & propagate[5] & generate_bit[4]) |
                   (propagate[6] & propagate[5] & propagate[4] & carry[4]);

        carry[8] = generate_bit[7] |
                   (propagate[7] & generate_bit[6]) |
                   (propagate[7] & propagate[6] & generate_bit[5]) |
                   (propagate[7] & propagate[6] & propagate[5] & generate_bit[4]) |
                   (propagate[7] & propagate[6] & propagate[5] &
                    propagate[4] & carry[4]);

        arithmetic_result = propagate ^ carry[7:0];

        result_comb   = 8'd0;
        carry_comb    = 1'b0;
        overflow_comb = 1'b0;
        zero_comb     = 1'b0;

        case (op_s1)
            OP_ADD: begin
                result_comb   = arithmetic_result;
                carry_comb    = carry[8];
                overflow_comb = (~(a_s1[7] ^ b_s1[7])) &
                                (result_comb[7] ^ a_s1[7]);
            end

            OP_SUB: begin
                result_comb   = arithmetic_result;
                // For SUB, carry=1 means no unsigned borrow.
                carry_comb    = carry[8];
                overflow_comb = (a_s1[7] ^ b_s1[7]) &
                                (result_comb[7] ^ a_s1[7]);
            end

            OP_AND: result_comb = a_s1 & b_s1;
            OP_OR:  result_comb = a_s1 | b_s1;
            OP_XOR: result_comb = a_s1 ^ b_s1;

            OP_SLL: begin
                result_comb = a_s1 << b_s1[2:0];
                if (b_s1[2:0] != 3'd0)
                    carry_comb = (a_s1 >> (8 - b_s1[2:0])) & 1'b1;
            end

            OP_SRL: begin
                result_comb = a_s1 >> b_s1[2:0];
                if (b_s1[2:0] != 3'd0)
                    carry_comb = (a_s1 >> (b_s1[2:0] - 1'b1)) & 1'b1;
            end

            // Reserved opcode returns zero with all flags clear.
            default: begin
                result_comb   = 8'd0;
                carry_comb    = 1'b0;
                overflow_comb = 1'b0;
            end
        endcase

        zero_comb = (result_comb == 8'd0);
    end

    // Pipeline stage 2 registers the result.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            op_s1        <= OP_ADD;
            a_s1         <= 8'd0;
            b_s1         <= 8'd0;
            valid_s1     <= 1'b0;
            out_valid    <= 1'b0;
            out_result   <= 8'd0;
            out_zero     <= 1'b0;
            out_carry    <= 1'b0;
            out_overflow <= 1'b0;
        end else begin
            out_valid <= valid_s1;

            if (valid_s1) begin
                out_result   <= result_comb;
                out_zero     <= zero_comb;
                out_carry    <= carry_comb;
                out_overflow <= overflow_comb;
            end

            valid_s1 <= in_valid;

            if (in_valid) begin
                op_s1 <= in_op;
                a_s1  <= in_a;
                b_s1  <= in_b;
            end
        end
    end
endmodule