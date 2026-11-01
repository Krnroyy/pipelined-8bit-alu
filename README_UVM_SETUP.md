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

### Reset, idle, and opcode/flag cross-coverage extension

The UVM test checks reset recovery with a request in flight, verifies outputs clear during reset, counts idle cycles, and measures opcode × zero/carry/overflow cross coverage. On Vivado 2026.1 with UVM 1.2, it checked 121 responses, observed 40 idle cycles and 2 reset pulses, flushed 1 in-flight request, and reached 100% cross coverage. The run completed with 0 warnings, errors, or fatals.

## Mutation sensitivity result

A deliberate SUB carry mutation changed the ALU to report unsigned borrow instead of the documented no-borrow flag. The UVM scoreboard detected the directed `SUB 09 - 04` case (`got carry=0`, `expected carry=1`) and reported 14 scoreboard errors followed by one test fatal. This intentional failure confirms the checker is sensitive to an arithmetic flag defect; it is not a failure of the clean design.

After the mutation run, the baseline RTL was run again and passed: 121 responses checked, no pending requests, 40 idle cycles, 2 reset pulses, 1 in-flight request flushed by reset, and 100% opcode/flag cross coverage. The clean run ended with 0 UVM warnings, errors, or fatals.

The faulty RTL is isolated under `experiments/mutation_sub_carry/` and is not used by the normal regression or synthesis flow.
