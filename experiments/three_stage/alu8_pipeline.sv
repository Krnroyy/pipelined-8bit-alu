`timescale 1ns/1ps

// Three-stage, one-result-per-cycle 8-bit ALU.
// An accepted request produces its result two clock cycles later.
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

    // Stage 1: capture request.
    logic [2:0] op_s1;
    logic [7:0] a_s1, b_s1;
    logic       valid_s1;

    // Combinational ALU between stages 1 and 2.
    logic [8:0] wide_result;
    logic [7:0] result_comb;
    logic       carry_comb, overflow_comb, zero_comb;

    // Stage 2: register the ALU result and flags.
    logic       valid_s2;
    logic [7:0] result_s2;
    logic       zero_s2, carry_s2, overflow_s2;

    always_comb begin
        wide_result   = 9'd0;
        result_comb   = 8'd0;
        carry_comb    = 1'b0;
        overflow_comb = 1'b0;
        zero_comb     = 1'b0;

        case (op_s1)
            OP_ADD: begin
                wide_result   = {1'b0, a_s1} + {1'b0, b_s1};
                result_comb   = wide_result[7:0];
                carry_comb    = wide_result[8];
                overflow_comb = (~(a_s1[7] ^ b_s1[7])) &
                                (result_comb[7] ^ a_s1[7]);
            end

            OP_SUB: begin
                wide_result   = {1'b0, a_s1} - {1'b0, b_s1};
                result_comb   = wide_result[7:0];
                // For SUB, carry=1 means no unsigned borrow.
                carry_comb    = ~wide_result[8];
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

            // Reserved opcode returns zero with carry and overflow clear.
            default: begin
                result_comb   = 8'd0;
                carry_comb    = 1'b0;
                overflow_comb = 1'b0;
            end
        endcase

        zero_comb = (result_comb == 8'd0);
    end

    // Stage 1 request registers.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            op_s1    <= OP_ADD;
            a_s1     <= 8'd0;
            b_s1     <= 8'd0;
            valid_s1 <= 1'b0;
        end else begin
            valid_s1 <= in_valid;
            if (in_valid) begin
                op_s1 <= in_op;
                a_s1  <= in_a;
                b_s1  <= in_b;
            end
        end
    end

    // Stage 2 ALU-result registers.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_s2    <= 1'b0;
            result_s2   <= 8'd0;
            zero_s2     <= 1'b0;
            carry_s2    <= 1'b0;
            overflow_s2 <= 1'b0;
        end else begin
            valid_s2 <= valid_s1;
            if (valid_s1) begin
                result_s2   <= result_comb;
                zero_s2     <= zero_comb;
                carry_s2    <= carry_comb;
                overflow_s2 <= overflow_comb;
            end
        end
    end

    // Stage 3 output registers.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid    <= 1'b0;
            out_result   <= 8'd0;
            out_zero     <= 1'b0;
            out_carry    <= 1'b0;
            out_overflow <= 1'b0;
        end else begin
            out_valid <= valid_s2;
            if (valid_s2) begin
                out_result   <= result_s2;
                out_zero     <= zero_s2;
                out_carry    <= carry_s2;
                out_overflow <= overflow_s2;
            end
        end
    end
endmodule