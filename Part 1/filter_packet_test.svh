// Greg Stitt
// University of Florida

// This class tests the DUT with packet-level transactions.

`ifndef _FILTER_PACKET_TEST_SVH_
`define _FILTER_PACKET_TEST_SVH_

class filter_packet_test extends filter_base_test;
    `uvm_component_utils(filter_packet_test)

    function new(string name = "filter_packet_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
        filter_packet_sequence seq;
        phase.raise_objection(this);

        env.configure_transaction_level(1'b1);

        seq = filter_packet_sequence::type_id::create("seq");        
        seq.start(env.agent_in.sequencer);

        #1000;

        phase.drop_objection(this);
    endtask

endclass

`endif
