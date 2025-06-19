// Used to specify the parameter configuration for the DUT.

package filter_tb_pkg;

    localparam int INPUT_WIDTH = 16;
    localparam int OUTPUT_WIDTH = 16;

    import axi4_stream_pkg::*;

    `include "packet.svh"
    `include "filter_sequence.svh"
    `include "filter_coverage.svh"
    `include "filter_scoreboard.svh"
    `include "filter_env.svh"
    `include "filter_base_test.svh"
    `include "filter_packet_test.svh"

endpackage
