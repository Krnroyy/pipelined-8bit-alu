#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build/regression

run_single_cycle_variant() {
    local name="$1"
    local rtl="$2"

    echo "=== $name: directed and random regression ==="
    iverilog -g2012 -s tb_alu8_pipeline \
        -o "build/regression/${name}_directed.vvp" \
        "$rtl" tb/tb_alu8_pipeline.sv
    vvp "build/regression/${name}_directed.vvp"

    echo "=== $name: exhaustive all-opcode regression ==="
    iverilog -g2012 -s tb_alu8_exhaustive \
        -o "build/regression/${name}_exhaustive.vvp" \
        "$rtl" experiments/tb_alu8_exhaustive.sv
    vvp "build/regression/${name}_exhaustive.vvp"
}

run_single_cycle_variant baseline rtl/alu8_pipeline.sv
run_single_cycle_variant shared_add_sub experiments/shared_add_sub/alu8_pipeline.sv
run_single_cycle_variant zero_direct experiments/shared_add_sub_zero_direct/alu8_pipeline.sv
run_single_cycle_variant carry_lookahead experiments/carry_lookahead/alu8_pipeline.sv

echo "=== three_stage: directed and random regression ==="
iverilog -g2012 -s tb_alu8_pipeline_3stage \
    -o build/regression/three_stage_directed.vvp \
    experiments/three_stage/alu8_pipeline.sv \
    experiments/three_stage/tb_alu8_pipeline_3stage.sv
vvp build/regression/three_stage_directed.vvp

echo "=== formal equivalence: baseline vs shared ADD/SUB ==="
yosys -Q -s scripts/check_shared_add_sub_equivalence.ys
echo "PASS: regression completed for all five ALU variants"