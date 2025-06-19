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

    // Compare the two packets.
    // Returns 1 if they match in length and in every data element.
    function automatic bit compare_packets(
        const ref Packet#(filter_tb_pkg::INPUT_WIDTH) expected, 
        const ref Packet#(filter_tb_pkg::INPUT_WIDTH) actual);
        if (expected.data.size() != actual.data.size())
            return 1'b0;
        foreach(expected.data[i]) begin
            if (expected.data[i] !== actual.data[i])
                return 1'b0;
        end
        return 1'b1;
    endfunction

    // Helper function to format the packet data as a hex string.
    function automatic string packet_to_hex(ref Packet#(filter_tb_pkg::INPUT_WIDTH) pkt);
        string s = "";
        foreach (pkt.data[i]) begin
            s = { s, $sformatf("%02X ", pkt.data[i]) };
        end
        return s;
    endfunction

    virtual task run_phase(uvm_phase phase);        
        axi4_stream_seq_item #(filter_tb_pkg::INPUT_WIDTH) in_item;
        axi4_stream_seq_item #(filter_tb_pkg::OUTPUT_WIDTH) out_item;
        Packet #(filter_tb_pkg::INPUT_WIDTH) expected;
        Packet #(filter_tb_pkg::INPUT_WIDTH) actual;

        in_item  = new();
        out_item = new();
        expected = new();
        actual = new();

        forever begin
            // Keep receiving input packets until we get one that shouldn't be filtered.
            while (1) begin
                in_fifo.get(in_item);
                expected.init_from_array(in_item.tdata, 1'b0);                
                if (expected.type_ inside {4'h0, 4'ha, 4'h5, 4'h3})
                    break;
            end

            // Verify that expected packet's checksum is valid.
            assert(expected.verify_checksum()) else $fatal(1, "Expected packet failed checksum check.");
            
            // Ensure the transaction type (packet-level) is as expected.
            assert(in_item.is_packet_level == is_packet_level);
            out_fifo.get(out_item);            
            actual.init_from_array(out_item.tdata, 1'b1);

            assert(is_packet_level) else $fatal(1, "Only packet-level transactions are supported.");

            // Compare packets.
            if (compare_packets(expected, actual)) begin
                `uvm_info("SCOREBOARD", $sformatf("Test passed."), UVM_LOW)
                passed++;
            end else begin
                `uvm_error("SCOREBOARD", "Test failed: actual and expected packets differ.")
                // Print detailed info for debugging.
                `uvm_info("SCOREBOARD", $sformatf("Expected Packet (length = %0d): %s",
                            expected.data.size(), packet_to_hex(expected)), UVM_NONE)
                `uvm_info("SCOREBOARD", $sformatf("Actual Packet   (length = %0d): %s",
                            actual.data.size(), packet_to_hex(actual)), UVM_NONE)
                failed++;
            end
        end
    endtask

endclass

`endif
