#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
iverilog -g2012 -s tb_alu8_pipeline -o build/alu8_sim \
  rtl/alu8_pipeline.sv tb/tb_alu8_pipeline.sv
vvp build/alu8_sim
