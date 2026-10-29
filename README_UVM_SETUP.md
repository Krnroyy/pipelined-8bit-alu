# ALU UVM 1.2 starter

## Contents

- `tb/alu_uvm/alu_uvm_tb.sv`: one-file UVM 1.2 testbench and top wrapper.
- `scripts/run_alu_uvm_project.tcl`: creates a Vivado simulation project and launches the UVM test through Vivado's integrated simulator flow.
- `scripts/run_alu_uvm.ps1`: standalone command-line launcher; it may be blocked by Windows Device Guard policy.

## Install

Extract this archive into the root of `C:\vlsi\asic_8bit_alu_starter`, preserving folders. The files are additive; they do not replace the ALU RTL or existing tests.

## Run through Vivado GUI

Open Vivado 2026.1 with no project open. In the Tcl Console, run:

```tcl
source C:/vlsi/asic_8bit_alu_starter/scripts/run_alu_uvm_project.tcl
```

The integrated Vivado flow uses its precompiled UVM 1.2 library. If Device Guard blocks `xvlog.exe`, `xelab.exe`, or `xsim.exe` even when launched by Vivado, stop and ask IT/support to authorize the Vivado simulator tools. Do not try to bypass the policy.

The test includes directed cases for all eight opcodes, randomized requests with occasional invalid cycles, a latency assertion, a reference-model scoreboard for result and flags, and opcode/flag coverage. Simulation outputs go under `build/uvm/`.

After running, inspect the log for the UVM PASS message, `UVM_ERROR : 0`, and `UVM_FATAL : 0`; share any compile/runtime output if it fails. The Tcl script creates generated project files under `build/uvm_vivado_project/` and leaves RTL and testbench files unchanged.
