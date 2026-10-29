# Run this from a fresh Vivado GUI Tcl Console:
# source C:/vlsi/asic_8bit_alu_starter/scripts/run_alu_uvm_project.tcl
# Vivado's integrated project flow compiles/elaborates/simulates the UVM test.

set repo_root [file normalize [file join [file dirname [info script]] ..]]
set rtl_file [file join $repo_root rtl alu8_pipeline.sv]
set uvm_file [file join $repo_root tb alu_uvm alu_uvm_tb.sv]
set project_dir [file join $repo_root build uvm_vivado_project]

if {![file exists $rtl_file]} { error "ALU RTL not found: $rtl_file" }
if {![file exists $uvm_file]} { error "UVM testbench not found: $uvm_file" }

create_project -force alu_uvm_project $project_dir -part xczu7ev-ffvc1156-2-e
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

add_files -fileset sim_1 -norecurse $rtl_file
add_files -fileset sim_1 -norecurse $uvm_file
set_property top alu_uvm_top [get_filesets sim_1]
set_property xsim.elaborate.xelab.more_options {-L uvm} [get_filesets sim_1]
update_compile_order -fileset sim_1

puts "Launching UVM 1.2 test with Vivado integrated simulation..."
launch_simulation -simset sim_1 -mode behavioral
run all
