// Greg Stitt
// University of Florida

module filter #(
    parameter int INPUT_WIDTH  = 16,
    parameter int OUTPUT_WIDTH = 16
) (
    input logic aclk,
    input logic arst_n,

    // AXI4 stream interface for the input.
    input  logic                   in_tvalid,
    output logic                   in_tready,
    input  logic [INPUT_WIDTH-1:0] in_tdata,
    input  logic                   in_tlast,

    // AXI4 stream interface for the output
    output logic                    out_tvalid,
    input  logic                    out_tready,
    output logic [OUTPUT_WIDTH-1:0] out_tdata,
    output logic                    out_tlast
);
    logic clk;
    logic rst;
    assign clk = aclk;
    assign rst = !arst_n;

    initial if (INPUT_WIDTH % 8 != 0) $fatal(1, $sformatf("AXI requires INPUT_WIDTH (%0d) to be byte aligned", INPUT_WIDTH));
    initial if (OUTPUT_WIDTH % 8 != 0) $fatal(1, $sformatf("AXI requires OUTPUT_WIDTH (%0d) to be byte aligned", OUTPUT_WIDTH));
    initial if (INPUT_WIDTH != 16 || OUTPUT_WIDTH != 16) $fatal(1, "Interface widths must both be 16 bits.");

    logic                     input_fifo_full;
    logic                     input_fifo_wr_en;
    logic [INPUT_WIDTH+2-1:0] input_fifo_wr_data;
    logic                     input_fifo_empty;
    logic                     input_fifo_rd_en;
    logic [INPUT_WIDTH+2-1:0] input_fifo_rd_data;

    logic in_sof_r;

    assign in_tready = !input_fifo_full;
    assign input_fifo_wr_en = in_tvalid && in_tready;
    assign input_fifo_wr_data = {in_sof_r, in_tlast, in_tdata};

    // Determine the sof status of the input.
    always_ff @(posedge clk) begin
        if (input_fifo_wr_en) in_sof_r <= in_tlast;
        if (rst) in_sof_r <= 1'b1;
    end

    fifo #(
        .WIDTH(INPUT_WIDTH + 2),
        .DEPTH(256)
    ) input_fifo (
        .clk    (clk),
        .rst    (rst),
        .full   (input_fifo_full),
        .wr_en  (input_fifo_wr_en),
        .wr_data(input_fifo_wr_data),
        .empty  (input_fifo_empty),
        .rd_en  (input_fifo_rd_en),
        .rd_data(input_fifo_rd_data)
    );

    logic sof, eof;
    logic [INPUT_WIDTH-1:0] data;
    assign {sof, eof, data} = input_fifo_rd_data;

    logic [3:0] msg_type;
    assign msg_type = data[$high(data)-:$bits(msg_type)];

    typedef enum logic [1:0] {
        WAIT_FOR_SOF,
        WAIT_FOR_EOF
    } state_t;

    state_t state_r, next_state;
    logic filter_r, next_filter;

    always_ff @(posedge clk) begin
        state_r  <= next_state;
        filter_r <= next_filter;

        if (rst) begin
            state_r <= WAIT_FOR_SOF;
        end
    end

    always_comb begin
        next_state       = state_r;
        next_filter      = filter_r;

        input_fifo_rd_en = 1'b0;

        out_tvalid       = 1'b0;
        out_tlast        = 1'b0;

        case (state_r)
            WAIT_FOR_SOF: begin
                next_filter = !(msg_type inside {4'h0, 4'ha, 4'h5, 4'h3});

                if (!input_fifo_empty && sof) next_state = WAIT_FOR_EOF;
            end

            WAIT_FOR_EOF: begin
                input_fifo_rd_en = (out_tready || filter_r) && !input_fifo_empty;
                out_tvalid       = !filter_r && !input_fifo_empty;
                out_tlast        = eof;

                if (eof && input_fifo_rd_en) next_state = WAIT_FOR_SOF;
            end

            default: begin
            end
        endcase
    end

    assign out_tdata = data;

endmodule
