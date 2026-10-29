`timescale 1ns/1ps

// Two-stage, one-result-per-cycle 8-bit ALU.
// ADD and SUB share one arithmetic adder.
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

    logic       subtract;
    logic [8:0] wide_result;
    logic [7:0] result_comb;
    logic       carry_comb;
    logic       overflow_comb;
    logic       zero_comb;

    // Two's-complement subtraction:
    // A - B = A + (~B) + 1.
    always_comb begin
        subtract = (op_s1 == OP_SUB);

        wide_result =
            {1'b0, a_s1}
            + {1'b0, (b_s1 ^ {8{subtract}})}
            + {{8{1'b0}}, subtract};

        result_comb   = 8'd0;
        carry_comb    = 1'b0;
        overflow_comb = 1'b0;
        zero_comb     = 1'b0;

        case (op_s1)
            OP_ADD: begin
                result_comb   = wide_result[7:0];
                carry_comb    = wide_result[8];
                overflow_comb = (~(a_s1[7] ^ b_s1[7])) &
                                (result_comb[7] ^ a_s1[7]);
                zero_comb     = (wide_result[7:0] == 8'd0);
            end

            OP_SUB: begin
                result_comb   = wide_result[7:0];
                // For subtraction, carry=1 means no unsigned borrow.
                carry_comb    = wide_result[8];
                overflow_comb = (a_s1[7] ^ b_s1[7]) &
                                (result_comb[7] ^ a_s1[7]);
                zero_comb     = (wide_result[7:0] == 8'd0);
            end

            OP_AND: begin
                result_comb = a_s1 & b_s1;
                zero_comb   = ~|(a_s1 & b_s1);
            end

            OP_OR: begin
                result_comb = a_s1 | b_s1;
                zero_comb   = ~|(a_s1 | b_s1);
            end

            OP_XOR: begin
                result_comb = a_s1 ^ b_s1;
                zero_comb   = (a_s1 == b_s1);
            end

            OP_SLL: begin
                result_comb = a_s1 << b_s1[2:0];
                if (b_s1[2:0] != 3'd0)
                    carry_comb = (a_s1 >> (8 - b_s1[2:0])) & 1'b1;
                zero_comb = (result_comb == 8'd0);
            end

            OP_SRL: begin
                result_comb = a_s1 >> b_s1[2:0];
                if (b_s1[2:0] != 3'd0)
                    carry_comb = (a_s1 >> (b_s1[2:0] - 1'b1)) & 1'b1;
                zero_comb = (result_comb == 8'd0);
            end

            // Reserved opcode returns zero with all flags clear,
            // except zero, which is set because the result is zero.
            default: begin
                result_comb   = 8'd0;
                carry_comb    = 1'b0;
                overflow_comb = 1'b0;
                zero_comb     = 1'b1;
            end
        endcase
    end

    // Pipeline stage 2 registers the result.
    // Requests can be accepted on consecutive cycles.
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