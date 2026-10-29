# Pipelined 8-bit ALU — learning project

This starter project implements a two-stage 8-bit arithmetic logic unit in
SystemVerilog. It accepts one request per clock when `in_valid` is high and
asserts `out_valid` one clock later. Requests can be accepted on consecutive
cycles.

## Operations

| `in_op` | Operation |
| --- | --- |
| `3'd0` | ADD |
| `3'd1` | SUB |
| `3'd2` | AND |
| `3'd3` | OR |
| `3'd4` | XOR |
| `3'd5` | Shift left by `in_b[2:0]` |
| `3'd6` | Shift right by `in_b[2:0]` |
| `3'd7` | Reserved; returns zero |

`out_zero` is set when the result is zero. `out_carry` reports the adder carry
for ADD and means “no unsigned borrow” for SUB. For shifts it reports the last
bit shifted out. `out_overflow` is signed two's-complement overflow for ADD/SUB.
Logical operations and reserved operations clear carry and overflow.

## Run the directed test

From WSL Ubuntu, in this project directory, run:

```bash
bash scripts/run_sim.sh
```

The script requires Icarus Verilog (`iverilog` and `vvp`). Expected final line:

```text
PASS: 14 directed checks; 64 consecutive pseudo-random requests; one request per cycle
```

## Learning milestones

1. Understand the RTL and flags; review the directed self-checking cases.
2. Confirm the 64-request consecutive stream passes and preserves result order.
3. Synthesize with Yosys and inspect the mapped cell counts.
4. Run an RTL-to-GDS learning flow with OpenROAD and SKY130.
5. Record timing, area, utilization, tool versions, and constraints.

This is a learning flow. SKY130's published PDK documentation describes its
current release as an experimental preview; these results are not production
signoff.

## OpenROAD timing sweep

The ALU was implemented with ORFS using the SKY130HD platform. Each run used
1.2 ns input and output delays. Results below are tool estimates from the
implementation reports, not measurements from fabricated silicon.

| Clock constraint | Worst slack | Estimated minimum period | Reported Fmax |
| ---: | ---: | ---: | ---: |
| 4.0 ns | +1.08 ns | 2.92 ns | 342.36 MHz |
| 3.0 ns | +0.20 ns | 2.80 ns | 357.30 MHz |
| 2.8 ns | +0.10 ns | 2.70 ns | 370.37 MHz |
| 2.7 ns | +0.04 ns | 2.66 ns | 375.44 MHz |

TNS was 0.00 in each run. The 2.7 ns run had only 0.04 ns slack, so 3.0 ns
is the more practical target from this sweep. The corresponding SDC files and
final timing reports are in `constraints/orfs_timing_sweep/` and
`reports/orfs_timing_sweep/`.

### Shared ADD/SUB candidate

A separate candidate shares one adder for ADD and SUB. It passed the existing
14 directed and 64 consecutive pseudo-random checks, plus an exhaustive check
of all 131,072 ADD/SUB operand combinations.

| Variant | Routed area | Worst slack at 3 ns | Estimated Fmax |
| --- | ---: | ---: | ---: |
| Baseline | 3,615 µm² | +0.20 ns | 357.30 MHz |
| Shared ADD/SUB | 3,401 µm² | +0.13 ns | 348.44 MHz |

The candidate reduced area by about 5.9% and retained positive slack at 3 ns,
with 0.07 ns less timing margin than the baseline. ORFS routing ended with
zero violations and final LEC passed. These are SKY130HD flow estimates, not
measured silicon results. The baseline remains in `rtl/alu8_pipeline.sv`;
the candidate is in `experiments/shared_add_sub/alu8_pipeline.sv`.

### Zero-direct flag candidate

The candidate computes the zero flag within each opcode branch. It passed the 14 directed checks, 64 consecutive pseudo-random requests, and all 131,072 exhaustive ADD/SUB cases. The ORFS run completed final LEC, detailed routing with zero DRC violations, and final GDS generation.

All PPA runs used SKY130HD, a 3.0 ns clock target, and 1.2 ns input/output delays.

| Version | Area (um^2) | Worst slack (ns) | Minimum period (ns) | Fmax (MHz) |
| --- | ---: | ---: | ---: | ---: |
| Baseline | 3615 | +0.20 | 2.80 | 357.30 |
| Shared ADD/SUB | 3401 | +0.13 | 2.87 | 348.44 |
| Zero-direct flag | 3633 | +0.17 | 2.83 | 352.82 |

The zero-direct candidate is larger and slower than the baseline, so it is retained as a tested experiment and is not selected as the improved design. The shared ADD/SUB candidate gives the smallest area, with a timing tradeoff. These are ORFS implementation estimates, not silicon measurements.

### Three-stage pipeline experiment

Added an output pipeline stage, keeping one request per cycle while increasing latency from one cycle to two. The candidate passed 14 directed checks and 64 consecutive pseudo-random requests. The ORFS run completed final LEC, detailed routing with zero violations, and final GDS generation.

At the same SKY130HD 3.0 ns clock target with 1.2 ns input/output delays, the candidate used 4,159 um^2, had +0.04 ns worst slack, a 2.96 ns minimum period, and estimated Fmax of 337.27 MHz. It meets the target, but is larger and slower than the baseline. This experiment is retained for comparison and is not selected.

### Carry-lookahead candidate

The candidate passed the directed/random regression and all 131,072 exhaustive ADD/SUB cases. The ORFS flow generated the final GDS, passed final LEC, and detailed routing reported zero violations.

With SKY130HD, a 3.0 ns clock target, and 1.2 ns input/output delays, the routed area was 3,548 um^2. Worst slack was 0.00 ns, minimum period was 3.00 ns, and estimated Fmax was 333.43 MHz. This is effectively at the timing limit. The shared ADD/SUB candidate is both smaller and faster, so carry-lookahead is retained as an experiment and is not selected.

## Consolidated PPA summary

All runs used SKY130HD, a 3.0 ns clock target, and 1.2 ns input/output delays. Fmax and area are ORFS estimates, not silicon measurements. All candidates sustain one request per cycle; the three-stage candidate has two-cycle latency, while the others have one-cycle latency.

| Candidate | Latency (cycles) | Area (um^2) | Worst slack (ns) | Minimum period (ns) | Fmax (MHz) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Baseline | 1 | 3615 | +0.20 | 2.80 | 357.30 |
| Shared ADD/SUB | 1 | 3401 | +0.13 | 2.87 | 348.44 |
| Zero-direct flag | 1 | 3633 | +0.17 | 2.83 | 352.82 |
| Three-stage | 2 | 4159 | +0.04 | 2.96 | 337.27 |
| Carry-lookahead | 1 | 3548 | 0.00 | 3.00 | 333.43 |

The baseline is the timing choice. Shared ADD/SUB is the area choice, reducing area by about 5.9% versus baseline while retaining positive timing slack. The other candidates did not improve this tradeoff.

## Run the verified regression

From the project root in WSL Ubuntu, run:

```bash
bash scripts/run_regression.sh
```

The script checks all five ALU variants. It runs directed/random and exhaustive 524,288-case all-opcode tests for the four one-cycle variants, plus directed/random tests for the two-cycle three-stage variant. It requires Icarus Verilog (iverilog and vvp). Generated simulation files are written under build/regression/, which Git ignores.
