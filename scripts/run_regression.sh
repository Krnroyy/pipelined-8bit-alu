#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build/regression

run_variant() {
    local name="$1"
    local rtl="$2"

    echo "=== $name: directed and random regression ==="
    iverilog -g2012 -s tb_alu8_pipeline \
        -o "build/regression/${name}_directed.vvp" \
        "$rtl" tb/tb_alu8_pipeline.sv
    vvp "build/regression/${name}_directed.vvp"

    echo "=== $name: exhaustive ADD/SUB regression ==="
    iverilog -g2012 -s tb_alu8_addsub_exhaustive \
        -o "build/regression/${name}_exhaustive.vvp" \
        "$rtl" experiments/shared_add_sub/tb_alu8_addsub_exhaustive.sv
    vvp "build/regression/${name}_exhaustive.vvp"
}

run_variant baseline rtl/alu8_pipeline.sv
run_variant shared_add_sub experiments/shared_add_sub/alu8_pipeline.sv

echo "PASS: baseline and shared ADD/SUB regressions completed"