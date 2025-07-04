// Greg Stitt
// University of Florida

`include "uvm_macros.svh"
import uvm_pkg::*;
import axi4_stream_pkg::*;
import filter_tb_pkg::*;

`timescale 1 ns / 100 ps

// TODO: Change any of the parameters as necessary to achieve 100% coverage.

module filter_tb #(
    parameter int NUM_PACKETS = 1000,

    // Enable/disable random toggling of the downstream ready signal.
    parameter bit TOGGLE_READY = 1'b1,

    // This gives us the capability to change the amount of cycles between
    // inputs in the AXI drivers. This is very useful for exposing bugs.
    parameter int MIN_DRIVER_DELAY = 15,
    parameter int MAX_DRIVER_DELAY = 15
);
    bit clk = 1'b0;
    bit rst;
    bit rst_n = 1'b0;
    always #5 clk <= ~clk;
    assign rst_n = ~rst;

    axi4_stream_if #(filter_tb_pkg::INPUT_WIDTH) in_intf (
        clk,
        rst_n
    );
    axi4_stream_if #(filter_tb_pkg::OUTPUT_WIDTH) out_intf (
        clk,
        rst_n
    );

    filter #(
        .INPUT_WIDTH (filter_tb_pkg::INPUT_WIDTH),
        .OUTPUT_WIDTH(filter_tb_pkg::OUTPUT_WIDTH)
    ) DUT (
        .aclk      (clk),
        .arst_n    (rst_n),
        .in_tvalid (in_intf.tvalid),
        .in_tready (in_intf.tready),
        .in_tdata  (in_intf.tdata),
        .in_tlast  (in_intf.tlast),
        .out_tvalid(out_intf.tvalid),
        .out_tready(out_intf.tready),
        .out_tdata (out_intf.tdata),
        .out_tlast (out_intf.tlast)
    );


    // initial begin
    //     if (!TOGGLE_READY) in_intf.tready <= 1'b1;
    //     else begin
    //         forever begin
    //            in_intf.tready <= $urandom;
    //             @(posedge clk);
    //         end
    //     end
    // end

    // Optionally toggle the ready signal randomly.
    initial begin
        if (!TOGGLE_READY) out_intf.tready <= 1'b1;
        else begin
            forever begin
                out_intf.tready <= $urandom;
                @(posedge clk);
            end
        end
    end

    // Reset the DUT.
    initial begin
        rst <= 1'b1;
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst <= 1'b0;
        @(posedge clk);
    end

    initial begin
        $timeformat(-9, 0, " ns");

        // Store the virtual interfaces.
        uvm_config_db#(virtual axi4_stream_if #(filter_tb_pkg::INPUT_WIDTH))::set(uvm_root::get(), "*", "in_vif", in_intf);
        uvm_config_db#(virtual axi4_stream_if #(filter_tb_pkg::OUTPUT_WIDTH))::set(uvm_root::get(), "*", "out_vif", out_intf);

        // Store the number of packets.
        uvm_config_db#(int)::set(uvm_root::get(), "*", "num_packets", NUM_PACKETS);

        // Store configuration info for the drivers.
        uvm_config_db#(int)::set(uvm_root::get(), "*", "min_driver_delay", MIN_DRIVER_DELAY);
        uvm_config_db#(int)::set(uvm_root::get(), "*", "max_driver_delay", MAX_DRIVER_DELAY);
    end

    initial begin
        run_test();
    end

    // Verify that the output doesn't change if the DUT is waiting on the ready flag. 
    // NOTE: AXI is a little weird and prohibits transmitters from waiting on tready
    // to assert tvalid. Normally, a transmitter treats a ready signal as an enable,
    // but that practice is not AXI-compliant.
    assert property (@(posedge clk) disable iff (rst) !out_intf.tready && out_intf.tvalid |=> $stable(out_intf.tdata))
    else `uvm_error("ASSERT", "Output changed with tready disabled.");

    assert property (@(posedge clk) disable iff (rst) !out_intf.tready && out_intf.tvalid |=> $stable(out_intf.tvalid))
    else `uvm_error("ASSERT", "Valid changed with tready disabled.");

endmodule
