// Greg Stitt
// University of Florida

// This file provides a base class for other tests.

`ifndef _FILTER_BASE_TEST_SVH_
`define _FILTER_BASE_TEST_SVH_

`include "uvm_macros.svh"
import uvm_pkg::*;

class filter_base_test extends uvm_test;
    `uvm_component_utils(filter_base_test)

    filter_env env;

    function new(string name = "filter_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = filter_env::type_id::create("env", this);
    endfunction

    virtual function void end_of_elaboration();
        // Prints the UVM topology.
        print();
    endfunction

    function void report_phase(uvm_phase phase);
        uvm_report_server svr;
        super.report_phase(phase);

        // The report server provides statistics about the simulation.
        svr = uvm_report_server::get_server();

        if (env.scoreboard.passed == 0) begin
            `uvm_error(get_type_name(), "TEST FAILED (no tests run).")            
        end else if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) > 0) begin
            // If there were any instances of uvm_fatal or uvm_error, then we will
            // consider that to be a failed test.
            `uvm_info(get_type_name(), "---------------------------", UVM_NONE)
            `uvm_info(get_type_name(), "---     TEST FAILED     ---", UVM_NONE)
            `uvm_info(get_type_name(), "---------------------------", UVM_NONE)
        end else begin
            `uvm_info(get_type_name(), "---------------------------", UVM_NONE)
            `uvm_info(get_type_name(), "---     TEST PASSED     ---", UVM_NONE)
            `uvm_info(get_type_name(), "---------------------------", UVM_NONE)
        end

        // Add coverage summary
        $display("=== Coverage Summary ===\n");
        $display("Input Packet Coverage: %.2f%%", env.input_coverage.packet_coverage.get_coverage());
        $display("  Type Coverage: %.2f%%", env.input_coverage.packet_coverage.types_cp.get_coverage());
        $display("  Length Bin Coverage: %.2f%%", env.input_coverage.packet_coverage.lengths_cp.get_coverage());
        $display("  Length Even/Odd Coverage: %.2f%%", env.input_coverage.packet_coverage.even_odd_cp.get_coverage());

        $display("Input Interface Coverage: %.2f%%", env.input_coverage.interface_coverage.get_coverage());
        $display("  Valid Coverage: %.2f%%", env.input_coverage.interface_coverage.valid_cp.get_coverage());
        $display("  Ready Coverage: %.2f%%", env.input_coverage.interface_coverage.not_ready_cp.get_coverage());
        $display("  Backpressure Coverage: %.2f%%", env.input_coverage.interface_coverage.backpressure_cp.get_coverage());

        $display("Output Interface Coverage: %.2f%%", env.output_coverage.interface_coverage.get_coverage());
        $display("  Valid Coverage: %.2f%%", env.output_coverage.interface_coverage.valid_cp.get_coverage());
        $display("  Ready Coverage: %.2f%%", env.output_coverage.interface_coverage.not_ready_cp.get_coverage());
        $display("  Backpressure Coverage: %.2f%%", env.output_coverage.interface_coverage.backpressure_cp.get_coverage());
        
    endfunction

endclass


`endif
