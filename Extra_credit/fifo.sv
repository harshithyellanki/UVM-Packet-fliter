// Greg Stitt
// University of Florida

module fifo #(
    parameter int WIDTH,
    parameter int DEPTH
) (
    input  logic             clk,
    input  logic             rst,
    output logic             full,
    input  logic             wr_en,
    input  logic [WIDTH-1:0] wr_data,
    output logic             empty,
    input  logic             rd_en,
    output logic [WIDTH-1:0] rd_data
);
    localparam int READ_LATENCY = 0;

    logic [WIDTH-1:0] ram[DEPTH];
    logic [$clog2(DEPTH)-1:0] wr_addr_r, rd_addr_r, rd_addr;

    localparam int COUNT_WIDTH = $clog2(DEPTH) + 1;
    logic [COUNT_WIDTH-1:0] count_r, next_count, count_update;
    logic valid_wr, valid_rd;

    logic bypass_valid, wr_en_delayed_r;
    logic [$bits(wr_data)-1:0] bypass_r;
    logic [$bits(rd_data)-1:0] rd_data_ram;

    assign rd_addr = !valid_rd ? rd_addr_r : rd_addr_r + 1'b1;

    // Infer a simple dual-port (SDP) RAM
    always @(posedge clk) begin
        if (valid_wr) ram[wr_addr_r] <= wr_data;
        rd_data_ram <= ram[rd_addr];
    end

    assign rd_data = bypass_valid ? bypass_r : rd_data_ram;
    assign bypass_valid = wr_en_delayed_r && count_r == COUNT_WIDTH'(1);

    always @(posedge clk) begin
        bypass_r        <= wr_data;
        wr_en_delayed_r <= wr_en;
        count_r         <= next_count;
        if (valid_wr) wr_addr_r <= wr_addr_r + 1'b1;
        if (valid_rd) rd_addr_r <= rd_addr_r + 1'b1;

        if (rst) begin
            rd_addr_r       <= '0;
            wr_addr_r       <= '0;
            count_r         <= '0;
            wr_en_delayed_r <= '0;
        end
    end

    always_comb begin
        case ({
            valid_wr, valid_rd
        })
            2'b10:   count_update = COUNT_WIDTH'(1);
            2'b01:   count_update = '1;
            default: count_update = '0;
        endcase
        next_count = count_r + count_update;
    end

    assign valid_wr = wr_en && !full;
    assign valid_rd = rd_en && !empty;
    assign full = count_r == DEPTH;
    assign empty = count_r == 0;

endmodule
