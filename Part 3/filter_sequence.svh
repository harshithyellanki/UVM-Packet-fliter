// Greg Stitt
// University of Florida

`ifndef _FILTER_SEQUENCE_SVH_
`define _FILTER_SEQUENCE_SVH_

`include "uvm_macros.svh"
import uvm_pkg::*;


virtual class filter_base_sequence extends uvm_sequence #(axi4_stream_seq_item #(filter_tb_pkg::INPUT_WIDTH));
    `uvm_object_utils(filter_base_sequence)

    int num_packets;

    function new(string name = "filter_sequence");
        super.new(name);
        if (!uvm_config_db#(int)::get(this, "", "num_packets", num_packets))
            `uvm_fatal("NO_NUM_PACKETS", "num_packets not specified.");
    endfunction
endclass


class filter_packet_sequence extends filter_base_sequence;
    `uvm_object_utils(filter_packet_sequence)

    function new(string name = "filter_packet_sequence");
        super.new(name);
    endfunction

    function automatic void convert_packet_to_axi(ref axi4_stream_seq_item#(filter_tb_pkg::INPUT_WIDTH) req,
                                                   const ref Packet packet);
        logic [filter_tb_pkg::INPUT_WIDTH-1:0] input_array[];
        Packet#(filter_tb_pkg::INPUT_WIDTH)::convert_from_bytes(input_array, packet.data);
        req.is_packet_level = 1'b1;
        assert(req.randomize() with {
            tdata.size() == input_array.size();
            foreach(tdata[i]) {
                tdata[i] == input_array[i];
                tstrb[i] == '1;
                tkeep[i] == '1;
            }
        })
        else $fatal(1, "Randomization failed.");
        // tlast is set automatically by the driver.
        req.tlast = 1'bX;
    endfunction

    virtual task body();
        Packet packet;
        axi4_stream_seq_item#(filter_tb_pkg::INPUT_WIDTH) req;
        for (int i = 0; i < num_packets; i++) begin
            packet = new();

            // Standard randomization call
            assert(packet.randomize() with {
		//type_ == 4'h0;              
		type_ inside { 4'h0, 4'hA, 4'h5, 4'h3 };
                length inside { [1:1024] };
		//length == 2;
                payload.size() == length;
                data.size() == length + 2;
                data[0] == { type_, length[11:8] };
                data[1] == { length[7:0] };
            })
            else $fatal(1, "Randomization failed.");

            $display("Randomized packet: type=%0d, length=%0d", packet.type_, packet.length);
            req = axi4_stream_seq_item#(filter_tb_pkg::INPUT_WIDTH)::type_id::create($sformatf("req%0d", i));
            wait_for_grant();
            convert_packet_to_axi(req, packet);
            send_request(req);
            wait_for_item_done();
        end
    endtask
endclass


class filter_debug_sequence extends filter_base_sequence;
    `uvm_object_utils(filter_debug_sequence)
    
    function new(string name = "filter_debug_sequence");
        super.new(name);
    endfunction

    function automatic void convert_packet_to_axi(ref axi4_stream_seq_item#(filter_tb_pkg::INPUT_WIDTH) req,
    const ref Packet packet);
logic [filter_tb_pkg::INPUT_WIDTH-1:0] input_array[];
Packet#(filter_tb_pkg::INPUT_WIDTH)::convert_from_bytes(input_array, packet.data);
req.is_packet_level = 1'b1;
assert(req.randomize() with {
tdata.size() == input_array.size();
foreach(tdata[i]) {
tdata[i] == input_array[i];
tstrb[i] == '1;
tkeep[i] == '1;
}
})
else $fatal(1, "Randomization failed.");
// tlast is set automatically by the driver.
req.tlast = 1'bX;
endfunction

    virtual task body();
        Packet packet;
        axi4_stream_seq_item#(filter_tb_pkg::INPUT_WIDTH) req;
        for (int i = 0; i < num_packets; i++) begin
            packet = new();
            // In the debug sequence, force the packet length to the loop index,
            // and set all payload bytes (non-header) to 8'h55.
            assert(packet.randomize() with {
                type_ == 4'b00;//inside { 4'h0, 4'hA, 4'h5, 4'h3 };
                length == i; // Force packet length to the current iteration count
                payload.size() == length;
                data.size() == length + 2; // Two header bytes plus payload
                data[0] == { type_, length[11:8] };
                data[1] == { length[7:0] };
                foreach(data[j]) if (j > 1)
                    data[j] == 8'h55; // Force payload bytes to 0x55
            })
            else $fatal(1, "Randomization failed.");

            $display("Debug packet: type=%0d, length=%0d", packet.type_, packet.length);
            req = axi4_stream_seq_item#(filter_tb_pkg::INPUT_WIDTH)::type_id::create($sformatf("req%0d", i));
            wait_for_grant();
            convert_packet_to_axi(req, packet);
            send_request(req);
            wait_for_item_done();
        end
    endtask
endclass

`endif
