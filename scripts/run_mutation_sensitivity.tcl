# Run from a fresh Vivado GUI Tcl Console:
# source C:/vlsi/asic_8bit_alu_starter/scripts/run_mutation_sensitivity.tcl
# Expected result: UVM SCOREBOARD error for SUB 09-04 carry, then a TEST fatal.
# The baseline RTL is never edited. This uses a separate project under build/.

set repo_root [file normalize [file join [file dirname [info script]] ..]]
set rtl_file [file join $repo_root experiments mutation_sub_carry alu8_pipeline.sv]
set uvm_file [file join $repo_root tb alu_uvm alu_uvm_tb.sv]
set project_dir [file join $repo_root build uvm_mutation_project]

if {![file exists $rtl_file]} { error "Mutant RTL not found: $rtl_file" }
if {![file exists $uvm_file]} { error "UVM testbench not found: $uvm_file" }

create_project -force alu_mutation_project $project_dir -part xczu7ev-ffvc1156-2-e
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
add_files -fileset sim_1 -norecurse $rtl_file
add_files -fileset sim_1 -norecurse $uvm_file
set_property top alu_uvm_top [get_filesets sim_1]
update_compile_order -fileset sim_1

puts "Running UVM against the deliberate SUB carry mutant."
puts "Expected: SCOREBOARD mismatch on op=1 a=09 b=04; the UVM test must not print PASS."
launch_simulation -simset sim_1 -mode behavioral
run all
