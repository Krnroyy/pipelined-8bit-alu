`timescale 1ns/1ps

interface alu_if(input logic clk);
    logic       rst_n;
    logic       in_valid;
    logic [2:0] in_op;
    logic [7:0] in_a;
    logic [7:0] in_b;
    logic       out_valid;
    logic [7:0] out_result;
    logic       out_zero;
    logic       out_carry;
    logic       out_overflow;
endinterface

package alu_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `uvm_analysis_imp_decl(_req)
    `uvm_analysis_imp_decl(_rsp)

    class alu_txn extends uvm_sequence_item;
        rand bit       valid;
        rand bit [2:0] op;
        rand bit [7:0] a;
        rand bit [7:0] b;

        bit [7:0] result;
        bit       zero;
        bit       carry;
        bit       overflow;

        `uvm_object_utils_begin(alu_txn)
            `uvm_field_int(valid,    UVM_DEFAULT)
            `uvm_field_int(op,       UVM_DEFAULT)
            `uvm_field_int(a,        UVM_DEFAULT)
            `uvm_field_int(b,        UVM_DEFAULT)
            `uvm_field_int(result,   UVM_DEFAULT)
            `uvm_field_int(zero,     UVM_DEFAULT)
            `uvm_field_int(carry,    UVM_DEFAULT)
            `uvm_field_int(overflow, UVM_DEFAULT)
        `uvm_object_utils_end

        function new(string name = "alu_txn");
            super.new(name);
        endfunction
    endclass

    class alu_sequence extends uvm_sequence #(alu_txn);
        `uvm_object_utils(alu_sequence)

        function new(string name = "alu_sequence");
            super.new(name);
        endfunction

        task automatic send_directed(bit [2:0] op,
                                     bit [7:0] a,
                                     bit [7:0] b);
            alu_txn tr = alu_txn::type_id::create("directed_item");
            start_item(tr);
            tr.valid = 1'b1;
            tr.op = op;
            tr.a = a;
            tr.b = b;
            finish_item(tr);
        endtask

        task body();
            // Arithmetic carry, borrow, signed overflow, and zero cases.
            send_directed(3'd0, 8'hff, 8'h01);
            send_directed(3'd0, 8'h7f, 8'h01);
            send_directed(3'd0, 8'h00, 8'h00);
            send_directed(3'd1, 8'h09, 8'h04);
            send_directed(3'd1, 8'h03, 8'h05);
            send_directed(3'd1, 8'h80, 8'h01);
            send_directed(3'd1, 8'h55, 8'h55);

            // Logical operations, shifts by zero, and shifts by seven.
            send_directed(3'd2, 8'hf0, 8'h0f);
            send_directed(3'd3, 8'h80, 8'h01);
            send_directed(3'd4, 8'ha5, 8'ha5);
            send_directed(3'd5, 8'h81, 8'h00);
            send_directed(3'd5, 8'h81, 8'h07);
            send_directed(3'd6, 8'h81, 8'h00);
            send_directed(3'd6, 8'h81, 8'h07);
            send_directed(3'd7, 8'hff, 8'hff);

            // Mixed continuous and bubbled traffic, still one item per cycle.
            repeat (128) begin
                alu_txn tr = alu_txn::type_id::create("random_item");
                start_item(tr);
                if (!tr.randomize())
                    `uvm_fatal("RAND", "Could not randomize ALU transaction")
                tr.valid = ($urandom_range(0, 3) != 0);
                finish_item(tr);
            end
        endtask
    endclass

    class alu_driver extends uvm_driver #(alu_txn);
        `uvm_component_utils(alu_driver)
        virtual alu_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual alu_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "alu_if virtual interface was not configured")
        endfunction

        task run_phase(uvm_phase phase);
            alu_txn req;
            vif.in_valid = 1'b0;
            vif.in_op = '0;
            vif.in_a = '0;
            vif.in_b = '0;
            forever begin
                @(negedge vif.clk);
                if (!vif.rst_n) begin
                    vif.in_valid <= 1'b0;
                    vif.in_op <= '0;
                    vif.in_a <= '0;
                    vif.in_b <= '0;
                end else begin
                    req = null;
                    seq_item_port.try_next_item(req);
                    if (req != null) begin
                        vif.in_valid <= req.valid;
                        vif.in_op <= req.op;
                        vif.in_a <= req.a;
                        vif.in_b <= req.b;
                        seq_item_port.item_done();
                    end else begin
                        vif.in_valid <= 1'b0;
                    end
                end
            end
        endtask
    endclass

    class alu_monitor extends uvm_component;
        `uvm_component_utils(alu_monitor)
        virtual alu_if vif;
        uvm_analysis_port #(alu_txn) req_ap;
        uvm_analysis_port #(alu_txn) rsp_ap;
        bit previous_input_valid;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            req_ap = new("req_ap", this);
            rsp_ap = new("rsp_ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual alu_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "alu_if virtual interface was not configured")
        endfunction

        task run_phase(uvm_phase phase);
            alu_txn tr;
            previous_input_valid = 1'b0;
            forever begin
                @(posedge vif.clk);
                #1ps; // Observe registered DUT outputs after nonblocking assignments.
                if (!vif.rst_n) begin
                    previous_input_valid = 1'b0;
                end else begin
                    if (vif.out_valid !== previous_input_valid)
                        `uvm_error("LATENCY", $sformatf(
                            "Expected out_valid=%0b one cycle after in_valid; got %0b",
                            previous_input_valid, vif.out_valid))

                    if (vif.in_valid) begin
                        tr = alu_txn::type_id::create("observed_request");
                        tr.valid = vif.in_valid;
                        tr.op = vif.in_op;
                        tr.a = vif.in_a;
                        tr.b = vif.in_b;
                        req_ap.write(tr);
                    end

                    if (vif.out_valid) begin
                        tr = alu_txn::type_id::create("observed_response");
                        tr.result = vif.out_result;
                        tr.zero = vif.out_zero;
                        tr.carry = vif.out_carry;
                        tr.overflow = vif.out_overflow;
                        rsp_ap.write(tr);
                    end
                    previous_input_valid = vif.in_valid;
                end
            end
        endtask
    endclass

    class alu_agent extends uvm_agent;
        `uvm_component_utils(alu_agent)
        uvm_sequencer #(alu_txn) sequencer;
        alu_driver driver;
        alu_monitor monitor;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sequencer = uvm_sequencer#(alu_txn)::type_id::create("sequencer", this);
            driver = alu_driver::type_id::create("driver", this);
            monitor = alu_monitor::type_id::create("monitor", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
        endfunction
    endclass

    class alu_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(alu_scoreboard)
        uvm_analysis_imp_req #(alu_txn, alu_scoreboard) req_export;
        uvm_analysis_imp_rsp #(alu_txn, alu_scoreboard) rsp_export;
        alu_txn expected_q[$];
        bit [7:0] seen_ops;
        int unsigned checked_count;
        int unsigned dropped_count;

        bit [2:0] cov_op;
        bit cov_zero, cov_carry, cov_overflow;
        covergroup alu_cg;
            cp_op: coverpoint cov_op { bins opcodes[] = {[0:7]}; }
            cp_zero: coverpoint cov_zero { bins zero = {1}; bins nonzero = {0}; }
            cp_carry: coverpoint cov_carry { bins carry = {1}; bins no_carry = {0}; }
            cp_overflow: coverpoint cov_overflow { bins overflow = {1}; bins no_overflow = {0}; }
        endgroup

        function new(string name, uvm_component parent);
            super.new(name, parent);
            req_export = new("req_export", this);
            rsp_export = new("rsp_export", this);
            alu_cg = new();
            seen_ops = '0;
            checked_count = 0;
            dropped_count = 0;
        endfunction

        function void model(alu_txn tr);
            logic [8:0] wide;
            logic [2:0] amount;
            wide = '0;
            amount = tr.b[2:0];
            tr.result = '0;
            tr.carry = 1'b0;
            tr.overflow = 1'b0;
            case (tr.op)
                3'd0: begin
                    wide = {1'b0, tr.a} + {1'b0, tr.b};
                    tr.result = wide[7:0];
                    tr.carry = wide[8];
                    tr.overflow = (~(tr.a[7] ^ tr.b[7])) & (tr.result[7] ^ tr.a[7]);
                end
                3'd1: begin
                    wide = {1'b0, tr.a} - {1'b0, tr.b};
                    tr.result = wide[7:0];
                    tr.carry = ~wide[8];
                    tr.overflow = (tr.a[7] ^ tr.b[7]) & (tr.result[7] ^ tr.a[7]);
                end
                3'd2: tr.result = tr.a & tr.b;
                3'd3: tr.result = tr.a | tr.b;
                3'd4: tr.result = tr.a ^ tr.b;
                3'd5: begin
                    tr.result = tr.a << amount;
                    if (amount != 0)
                        tr.carry = (tr.a >> (8 - amount)) & 1'b1;
                end
                3'd6: begin
                    tr.result = tr.a >> amount;
                    if (amount != 0)
                        tr.carry = (tr.a >> (amount - 1'b1)) & 1'b1;
                end
                default: begin
                    tr.result = 8'h00;
                end
            endcase
            tr.zero = (tr.result == 8'h00);
        endfunction

        function void write_req(alu_txn tr);
            alu_txn exp;
            exp = alu_txn::type_id::create("expected_response");
            exp.op = tr.op;
            exp.a = tr.a;
            exp.b = tr.b;
            model(exp);
            expected_q.push_back(exp);
            seen_ops[tr.op] = 1'b1;
        endfunction

        function void write_rsp(alu_txn got);
            alu_txn exp;
            if (expected_q.size() == 0) begin
                `uvm_error("SCOREBOARD", "Received a response with no pending request")
                return;
            end
            exp = expected_q.pop_front();
            checked_count++;
            cov_op = exp.op;
            cov_zero = exp.zero;
            cov_carry = exp.carry;
            cov_overflow = exp.overflow;
            alu_cg.sample();
            if ({got.result, got.zero, got.carry, got.overflow} !==
                {exp.result, exp.zero, exp.carry, exp.overflow}) begin
                `uvm_error("SCOREBOARD", $sformatf(
                    "op=%0d a=%02h b=%02h got={%02h z%b c%b v%b} expected={%02h z%b c%b v%b}",
                    exp.op, exp.a, exp.b, got.result, got.zero, got.carry,
                    got.overflow, exp.result, exp.zero, exp.carry, exp.overflow))
            end
        endfunction

        function int unsigned pending_count();
            return expected_q.size();
        endfunction

        function void check_all_opcodes();
            if (seen_ops !== 8'hff)
                `uvm_error("COVERAGE", $sformatf("Not all opcodes were observed; mask=%02h", seen_ops))
            else
                `uvm_info("COVERAGE", $sformatf("All opcode bins hit; flag coverage %.1f%%", alu_cg.get_coverage()), UVM_LOW)
        endfunction

        function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("SUMMARY", $sformatf("Responses checked=%0d, pending=%0d, coverage=%.1f%%",
                checked_count, expected_q.size(), alu_cg.get_coverage()), UVM_NONE)
        endfunction
    endclass

    class alu_env extends uvm_env;
        `uvm_component_utils(alu_env)
        alu_agent agent;
        alu_scoreboard scb;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agent = alu_agent::type_id::create("agent", this);
            scb = alu_scoreboard::type_id::create("scb", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            agent.monitor.req_ap.connect(scb.req_export);
            agent.monitor.rsp_ap.connect(scb.rsp_export);
        endfunction
    endclass

    class alu_uvm_test extends uvm_test;
        `uvm_component_utils(alu_uvm_test)
        alu_env env;
        virtual alu_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = alu_env::type_id::create("env", this);
            if (!uvm_config_db#(virtual alu_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "alu_if virtual interface was not configured for test")
        endfunction

        task run_phase(uvm_phase phase);
            alu_sequence seq;
            phase.raise_objection(this);
            wait (vif.rst_n === 1'b1);
            seq = alu_sequence::type_id::create("seq");
            seq.start(env.agent.sequencer);
            repeat (3) @(posedge vif.clk);
            #1ps;
            if (env.scb.pending_count() != 0)
                `uvm_error("DRAIN", $sformatf("Scoreboard still has %0d requests pending", env.scb.pending_count()))
            if (env.scb.checked_count == 0)
                `uvm_error("DRAIN", "No responses were checked")
            env.scb.check_all_opcodes();
            if (uvm_report_server::get_server().get_severity_count(UVM_ERROR) != 0)
                `uvm_fatal("TEST", "UVM test completed with one or more errors")
            `uvm_info("PASS", "UVM ALU test passed: latency, results, flags, and opcode coverage checked", UVM_NONE)
            phase.drop_objection(this);
        endtask
    endclass
endpackage

module alu_uvm_top;
    import uvm_pkg::*;
    import alu_uvm_pkg::*;

    logic clk = 1'b0;
    always #5ns clk = ~clk;

    alu_if bus(clk);

    alu8_pipeline dut (
        .clk(clk),
        .rst_n(bus.rst_n),
        .in_valid(bus.in_valid),
        .in_op(bus.in_op),
        .in_a(bus.in_a),
        .in_b(bus.in_b),
        .out_valid(bus.out_valid),
        .out_result(bus.out_result),
        .out_zero(bus.out_zero),
        .out_carry(bus.out_carry),
        .out_overflow(bus.out_overflow)
    );

    initial begin
        bus.rst_n = 1'b0;
        bus.in_valid = 1'b0;
        bus.in_op = '0;
        bus.in_a = '0;
        bus.in_b = '0;
        repeat (4) @(negedge clk);
        bus.rst_n = 1'b1;
    end

    initial begin
        uvm_config_db#(virtual alu_if)::set(null, "*", "vif", bus);
        run_test("alu_uvm_test");
    end

    initial begin
        #100us;
        $fatal(1, "UVM test timed out");
    end
endmodule
