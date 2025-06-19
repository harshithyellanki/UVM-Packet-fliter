// Greg Stitt
// University of Florida

`ifndef _FILTER_SCOREBOARD_SVH_
`define _FILTER_SCOREBOARD_SVH_

`include "uvm_macros.svh"
import uvm_pkg::*;

class filter_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(filter_scoreboard)

    uvm_analysis_export #(axi4_stream_seq_item #(filter_tb_pkg::INPUT_WIDTH)) in_ae;
    uvm_analysis_export #(axi4_stream_seq_item #(filter_tb_pkg::OUTPUT_WIDTH)) out_ae;

    uvm_tlm_analysis_fifo #(axi4_stream_seq_item #(filter_tb_pkg::INPUT_WIDTH)) in_fifo;
    uvm_tlm_analysis_fifo #(axi4_stream_seq_item #(filter_tb_pkg::OUTPUT_WIDTH)) out_fifo;

    int passed, failed;
    bit is_packet_level;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        passed = 0;
        failed = 0;
        is_packet_level = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Create the analysis exports.
        in_ae = new("in_ae", this);
        out_ae = new("out_ae", this);

        // Create the analysis FIFOs.
        in_fifo = new("in_fifo", this);
        out_fifo = new("out_fifo", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        in_ae.connect(in_fifo.analysis_export);
        out_ae.connect(out_fifo.analysis_export);
    endfunction

    function automatic bit compare_actual_and_expected(const ref axi4_stream_seq_item#(filter_tb_pkg::INPUT_WIDTH) in_item, const ref axi4_stream_seq_item#(filter_tb_pkg::OUTPUT_WIDTH) out_item);
        if (in_item.tdata.size() != out_item.tdata.size()) return 1'b0;
        foreach(in_item.tdata[i]) begin
            if (in_item.tdata[i] !== out_item.tdata[i]) return 1'b0;
        end
        return 1'b1;
    endfunction

    virtual task run_phase(uvm_phase phase);        
        axi4_stream_seq_item #(filter_tb_pkg::INPUT_WIDTH) in_item;
        axi4_stream_seq_item #(filter_tb_pkg::OUTPUT_WIDTH) out_item;
        Packet #(filter_tb_pkg::INPUT_WIDTH) expected;

        in_item  = new();
        out_item = new();
        expected = new();

        forever begin
            // Keep receiving input packets until we get one that shouldn't be filtered.
            while (1) begin
                // Get the next input packet.
                in_fifo.get(in_item);
                // Convert it from AXI to the Packet class.
                expected.init_from_array(in_item.tdata);
                // If the type of message is valid, break out of the loop.
                if (expected.type_ inside {4'h0, 4'ha, 4'h5, 4'h3}) break;
            end
            
            // Make sure that the scoreboard is configured to match the items.
            assert (in_item.is_packet_level == is_packet_level);
            assert (is_packet_level)
            else $fatal(1, "Only packet-level transactions are supported.");

            // Wait for the next output.
            out_fifo.get(out_item);

            // Compare the actual and expected for differences.
            if (compare_actual_and_expected(in_item, out_item)) begin
                `uvm_info("SCOREBOARD", "Test passed.", UVM_LOW)
                passed++;
            end else begin
                `uvm_error("SCOREBOARD", "Test failed: actual and expected packets differ.")
                failed++;
            end       
        end
    endtask

endclass

`endif
