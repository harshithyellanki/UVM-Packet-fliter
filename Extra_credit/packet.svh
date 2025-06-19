// Greg Stitt
// University of Florida

`ifndef _PACKET_SVH_
`define _PACKET_SVH_

class Packet #(
    parameter int WIDTH = 16
);
    rand logic [3:0] type_;
    rand logic [11:0] length;
    rand logic [7:0] payload[];
    rand logic [7:0] data[];

    function new();
    endfunction

    static function automatic void convert_to_bytes(ref logic [7:0] out_array[], const ref logic [WIDTH-1:0] in_array[]);
        out_array = {>>{in_array}};
    endfunction

    static function automatic void convert_from_bytes(ref logic [WIDTH-1:0] out_array[], const ref logic [7:0] in_array[]);
        out_array = {>>{in_array}};
    endfunction

    function automatic void init_from_array(const ref logic [WIDTH-1:0] in_array[]);

        logic [7:0] byte_array[] = {>>{in_array}};

        assert (this.randomize() with {
            type_ == byte_array[0][7:4];
            length == {byte_array[0][3:0], byte_array[1]};
            payload.size() == length;
            data.size() == length + 2;
            data[0] == {type_, length[11:8]};
            data[1] == {length[7:0]};
            foreach (data[i]) {                
                i > 2 -> data[i] == byte_array[i];
            }
            foreach (payload[i]) {
                payload[i] == byte_array[i+2];
            }
        })
        else $fatal(1, "Randomization failed.");
    endfunction

    function automatic void init_from_bytes(const ref logic [7:0] byte_array[]);
        type_ = byte_array[0][7:4];
        length   = {byte_array[0][3:0], byte_array[1]};

        assert (this.randomize() with {
            type_ == byte_array[0][7:4];
            length == {byte_array[0][3:0], byte_array[1]};
            data.size() == length + 2;
            data[0] == {type_, length[11:8]};
            data[1] == {length[7:0]};
            foreach (data[i]) {
                payload[i] == byte_array[i+2];
                i > 2 -> data[i] == byte_array[i];
            }
        })
        else $fatal(1, "Randomization failed.");
    endfunction

endclass

`endif
