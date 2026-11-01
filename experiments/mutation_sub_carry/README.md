# UVM mutation sensitivity check

`alu8_pipeline.sv` is deliberately wrong: SUB reports the borrow bit as
`out_carry`, while the interface defines carry as “no unsigned borrow.” The
directed UVM request `SUB 09 - 04` must therefore trigger a scoreboard
mismatch (`got carry=0`, `expected carry=1`).

Run the separate Vivado project from a fresh GUI Tcl Console:

```tcl
source C:/vlsi/asic_8bit_alu_starter/scripts/run_mutation_sensitivity.tcl
```

This is a successful sensitivity check when the log shows the expected
`SCOREBOARD` mismatch and does not show the UVM `[PASS]` message. The mutant is
isolated under `experiments/`; it does not alter `rtl/alu8_pipeline.sv`. To
restore the clean green run, close the mutation project and source
`scripts/run_alu_uvm_project.tcl` from a fresh Vivado GUI Tcl Console.
