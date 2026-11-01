# Pipelined 8-bit ALU — Project Completion Summary

**Repository:** [Krnroyy/pipelined-8bit-alu](https://github.com/Krnroyy/pipelined-8bit-alu)  
**Status:** Verification and implementation experiments complete  
**Latest pushed commit:** `f439b6e` — exhaustive three-stage ALU verification
**Release:** [v1.0.0](https://github.com/Krnroyy/pipelined-8bit-alu/releases/tag/v1.0.0)

## Design

Implemented a two-stage, 8-bit SystemVerilog ALU with one-cycle response latency and one-request-per-cycle throughput. Operations cover ADD, SUB, AND, OR, XOR, left/right shifts, and a reserved opcode. Arithmetic status flags include zero, carry/no-borrow, and signed overflow.

## Verification evidence

- Icarus Verilog: 14 directed checks and 64 consecutive pseudo-random requests passed.
- Exhaustive all-opcode tests cover 524,288 combinations for each one-cycle candidate; the regression now includes the same full sweep for the two-cycle three-stage candidate.
- Exhaustive arithmetic: all 131,072 ADD/SUB operand pairs passed.
- Yosys formal equivalence: all 43 equivalence points for the shared ADD/SUB implementation were proven.
- Vivado UVM 1.2: 121 responses checked; 40 idle cycles; 2 reset pulses; 1 in-flight request flushed by reset; 100% opcode/flag cross coverage; zero warnings, errors, or fatals on the clean baseline.
- Mutation sensitivity: an intentionally inverted SUB carry/no-borrow flag produced 14 scoreboard errors and a test fatal, confirming that the UVM checker detects the injected defect. The clean RTL passed again afterward.
- GitHub Actions: the workflow for commit `939d059` completed successfully.

## Routed SKY130HD estimates

The physical implementation used OpenROAD Flow Scripts (ORFS), combining Yosys
RTL synthesis with OpenROAD floorplanning, placement, clock-tree synthesis, and
routing. SKY130HD supplied the 130 nm high-density standard-cell library and
technology views used for mapping, physical implementation, and timing/area
estimation. The flow generated GDSII for this educational design; the results
are not silicon measurements or production foundry signoff.

Runs used a 3.0 ns clock target and 1.2 ns input/output delays. These are OpenROAD-flow estimates, not silicon measurements.

| Candidate | Latency | Area (um^2) | Worst slack (ns) | Minimum period (ns) | Estimated Fmax (MHz) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Baseline | 1 cycle | 3,615 | +0.20 | 2.80 | 357.30 |
| Shared ADD/SUB | 1 cycle | 3,401 | +0.13 | 2.87 | 348.44 |
| Zero-direct flag | 1 cycle | 3,633 | +0.17 | 2.83 | 352.82 |
| Three-stage | 2 cycles | 4,159 | +0.04 | 2.96 | 337.27 |
| Carry-lookahead | 1 cycle | 3,548 | 0.00 | 3.00 | 333.43 |

The baseline is the timing choice. Shared ADD/SUB is the area choice, reducing routed area by about 5.9% while retaining positive timing slack. The other tested variants did not improve that area/timing tradeoff.

## Resume-ready summary

Designed and verified a pipelined 8-bit SystemVerilog ALU using directed, randomized, exhaustive, formal-equivalence, and UVM testing. Compared five RTL implementations through a SKY130HD RTL-to-GDS flow; the shared ADD/SUB variant reduced estimated routed area by 5.9% while meeting a 3 ns target. Added mutation testing to demonstrate that the UVM scoreboard detects a SUB carry defect, and automated regression checks with GitHub Actions.
