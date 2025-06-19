// Greg Stitt
// University of Florida

// This file demonstrates various coverage techniques.

`ifndef _FILTER_COVERAGE_SVH_
`define _FILTER_COVERAGE_SVH_

`include "uvm_macros.svh"
import uvm_pkg::*;


// Coverage for the DUT inputs.
class filter_input_coverage extends uvm_component;
    `uvm_component_utils(filter_input_coverage)

    typedef axi4_stream_seq_item#(filter_tb_pkg::INPUT_WIDTH, axi4_stream_pkg::DEFAULT_ID_WIDTH, axi4_stream_pkg::DEFAULT_DEST_WIDTH, axi4_stream_pkg::DEFAULT_USER_WIDTH) axi_item;
    uvm_analysis_export #(axi_item) in_ae;
    uvm_tlm_analysis_fifo #(axi_item) in_fifo;

    virtual axi4_stream_if #(filter_tb_pkg::INPUT_WIDTH) vif;
    Packet #(filter_tb_pkg::INPUT_WIDTH) packet;

    covergroup packet_coverage;
        types_cp: coverpoint packet.type_ {bins all[] = {[0 : $]};}
        lengths_cp: coverpoint packet.length {option.auto_bin_max = 16;}
        even_odd_cp: coverpoint packet.length % 2 {bins even = {0}; bins odd = {1};}
    endgroup

    covergroup interface_coverage;
        valid_cp: coverpoint vif.tvalid {bins one = {1}; bins zero = {0};}
        not_ready_cp: coverpoint !vif.tready {bins one = {1}; option.at_least = 100;}
        backpressure_cp: coverpoint !vif.tready && vif.tvalid {bins one = {1}; option.at_least = 100;}
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);

        // Instantiate the cover groups.
        packet_coverage = new();
        interface_coverage = new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Create the exports and FIFOs
        in_ae   = new("in_ae", this);
        in_fifo = new("in0_fifo", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Connect exports to FIFOs
        in_ae.connect(in_fifo.analysis_export);
    endfunction

    task check_interface;
        forever begin
            @(posedge vif.aclk);
            interface_coverage.sample();
        end
    endtask

    task check_packet;
        axi_item in_item = new();

        forever begin
            in_fifo.get(in_item);
            packet = new();
            packet.init_from_array(in_item.tdata);
            packet_coverage.sample();
        end
    endtask

    task run_phase(uvm_phase phase);
        fork
            check_packet();
            check_interface();
        join
    endtask
endclass


// Coverage class for output values
class filter_output_coverage extends uvm_component;
    `uvm_component_utils(filter_output_coverage)

    typedef axi4_stream_seq_item#(filter_tb_pkg::OUTPUT_WIDTH, axi4_stream_pkg::DEFAULT_ID_WIDTH, axi4_stream_pkg::DEFAULT_DEST_WIDTH, axi4_stream_pkg::DEFAULT_USER_WIDTH) axi_item;
    uvm_analysis_export #(axi_item) out_ae;
    uvm_tlm_analysis_fifo #(axi_item) out_fifo;

    virtual axi4_stream_if #(filter_tb_pkg::OUTPUT_WIDTH) vif;

    covergroup interface_coverage;
        valid_cp: coverpoint vif.tvalid {bins one = {1}; bins zero = {0};}
        not_ready_cp: coverpoint !vif.tready {bins one = {1}; option.at_least = 100;}
        backpressure_cp: coverpoint !vif.tready && vif.tvalid {bins one = {1}; option.at_least = 100;}
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        interface_coverage = new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Create the export and FIFO
        out_ae   = new("out_ae", this);
        out_fifo = new("out_fifo", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Connect export to FIFO
        out_ae.connect(out_fifo.analysis_export);
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(posedge vif.aclk);
            interface_coverage.sample();
        end
    endtask
endclass

`endif
