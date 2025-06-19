// Greg Stitt
// University of Florida

module filter #(
    parameter int INPUT_WIDTH  = 16,
    parameter int OUTPUT_WIDTH = 16
) (
    input  logic                   aclk,
    input  logic                   arst_n,
    // AXI4 stream interface for the input.
    input  logic                   in_tvalid,
    output logic                   in_tready,
    input  logic [INPUT_WIDTH-1:0] in_tdata,
    input  logic                   in_tlast,
    // AXI4 stream interface for the output.
    output logic                    out_tvalid,
    input  logic                    out_tready,
    output logic [OUTPUT_WIDTH-1:0] out_tdata,
    output logic                    out_tlast
);


    logic clk;
    logic rst;
    assign clk = aclk;
    assign rst = !arst_n;


    initial if (INPUT_WIDTH % 8 != 0)
      $fatal(1, $sformatf("AXI requires INPUT_WIDTH (%0d) to be byte aligned", INPUT_WIDTH));
    initial if (OUTPUT_WIDTH % 8 != 0)
      $fatal(1, $sformatf("AXI requires OUTPUT_WIDTH (%0d) to be byte aligned", OUTPUT_WIDTH));
    initial if (INPUT_WIDTH != 16 || OUTPUT_WIDTH != 16)
      $fatal(1, "Interface widths must both be 16 bits.");
-
    logic                     input_fifo_full;
    logic                     input_fifo_wr_en;
    logic [INPUT_WIDTH+2-1:0] input_fifo_wr_data;
    logic                     input_fifo_empty;
    logic                     input_fifo_rd_en;
    logic [INPUT_WIDTH+2-1:0] input_fifo_rd_data;

    // The FIFO beat contains: [sof flag][eof flag][16-bit data]
    logic in_sof_r;
    assign in_tready = !input_fifo_full;
    assign input_fifo_wr_en  = in_tvalid && in_tready;
    assign input_fifo_wr_data = {in_sof_r, in_tlast, in_tdata};

    always_ff @(posedge clk) begin
        if (rst)
            in_sof_r <= 1'b1;
        else if (input_fifo_wr_en)
            in_sof_r <= in_tlast; // Use current in_tlast to update sof for next beat.
    end

    fifo #(
        .WIDTH(INPUT_WIDTH + 2),
        .DEPTH(256)
    ) input_fifo (
        .clk     (clk),
        .rst     (rst),
        .full    (input_fifo_full),
        .wr_en   (input_fifo_wr_en),
        .wr_data (input_fifo_wr_data),
        .empty   (input_fifo_empty),
        .rd_en   (input_fifo_rd_en),
        .rd_data (input_fifo_rd_data)
    );


    logic sof, eof;
    logic [INPUT_WIDTH-1:0] data;
    assign {sof, eof, data} = input_fifo_rd_data;

 
    logic [3:0] msg_type;
    assign msg_type = data[15:12];

    // Allowed types: 4'h0, 4'ha, 4'h5, 4'h3.
    typedef enum logic { PASS, FILTER } filter_t;
    filter_t filter_r;

  
    typedef enum logic [1:0] {
        WAIT_FOR_SOF,    // Wait for header beat.
        PROCESS_PACKET,  // Process payload beats.
        SEND_CHECKSUM    // Inject extra checksum beat (for even overall packet).
    } state_t;
    state_t state_r, next_state;

 
    // checksum_reg: running XOR checksum (per byte).
    // byte_count: count of valid bytes processed.
    // total_valid_bytes_reg: header (2) + payload length (from header).
    // odd_flag: 1 if overall byte count is odd.
    // header_data_reg: holds header word.
    // final_checksum_reg: latched final checksum (used in SEND_CHECKSUM).
    logic [7:0]  checksum_reg, next_checksum;
    logic [12:0] byte_count, next_byte_count;
    logic [11:0] total_valid_bytes_reg, next_total_valid_bytes;
    logic        odd_flag, next_odd_flag;
    logic [15:0] header_data_reg, next_header_data;
    logic [7:0]  final_checksum_reg, next_final_checksum;


    always_ff @(posedge clk) begin
        if (rst) begin
            state_r               <= WAIT_FOR_SOF;
            checksum_reg          <= 8'd0;
            byte_count            <= 13'd0;
            total_valid_bytes_reg <= 12'd0;
            odd_flag              <= 1'b0;
            header_data_reg       <= 16'd0;
            filter_r              <= FILTER;
            final_checksum_reg    <= 8'd0;
        end else begin
            state_r               <= next_state;
            checksum_reg          <= next_checksum;
            byte_count            <= next_byte_count;
            total_valid_bytes_reg <= next_total_valid_bytes;
            odd_flag              <= next_odd_flag;
            header_data_reg       <= next_header_data;
            if (state_r == WAIT_FOR_SOF)
                filter_r <= ~(msg_type inside {4'h0, 4'ha, 4'h5, 4'h3});
            final_checksum_reg    <= next_final_checksum;
        end
    end

    always_comb begin : comb_block
        // Declare all local variables at the top.
        logic [11:0] payload_length;
        logic [7:0]  computed_checksum;
        
        // Now assign them.
        payload_length = { data[11:8], data[7:0] };
        computed_checksum = 8'd0;  // default initialization

        // Default assignments.
        next_state = state_r;
        input_fifo_rd_en = 1'b0;
        out_tvalid = 1'b0;
        out_tlast  = 1'b0;
        out_tdata  = '0;
        next_checksum = checksum_reg;
        next_byte_count = byte_count;
        next_total_valid_bytes = total_valid_bytes_reg;
        next_odd_flag = odd_flag;
        next_header_data = header_data_reg;
        next_final_checksum = final_checksum_reg;

        // For filtered packets, simply drain the FIFO.
        if (filter_r == FILTER) begin
            if (!input_fifo_empty) begin
                input_fifo_rd_en = 1'b1;
                if (eof)
                    next_state = WAIT_FOR_SOF;
            end
        end else begin
           
            case (state_r)
    
                WAIT_FOR_SOF: begin
                    if (!input_fifo_empty && sof) begin
                        next_header_data = data;
                        next_total_valid_bytes = 12'd2 + payload_length;
                       
                        next_odd_flag = payload_length[0];
                        next_checksum = 8'd0 ^ data[15:8] ^ data[7:0];
                        next_byte_count = 13'd2;
                        if (out_tready) begin
                            input_fifo_rd_en = 1'b1;
                            out_tvalid = 1'b1;
                            out_tdata  = data;
                            if (eof) begin
                                // Header-only packet.
                                if (next_odd_flag)
                                    next_state = WAIT_FOR_SOF;  
                                else
                                    next_state = SEND_CHECKSUM;  
                            end else
                                next_state = PROCESS_PACKET;
                        end
                    end
                end


                PROCESS_PACKET: begin
                    if (!input_fifo_empty) begin
                        if (!eof) begin
                            // Non-final beat: full 2 bytes valid.
                            if (out_tready) begin
                                input_fifo_rd_en = 1'b1;
                                out_tvalid = 1'b1;
                                out_tdata  = data;
                                next_checksum = checksum_reg ^ data[15:8] ^ data[7:0];
                                next_byte_count = byte_count + 13'd2;
                            end
                            next_state = PROCESS_PACKET;
                        end else begin
                            // Final payload beat.
                            if (odd_flag) begin
                                // Odd overall packet: only upper 8 bits are valid.
                                if (out_tready) begin
                                    input_fifo_rd_en = 1'b1;
                                    out_tdata = { data[15:8], (checksum_reg ^ data[15:8]) };
                                    out_tvalid = 1'b1;
                                    out_tlast  = 1'b1;
                                    next_state = WAIT_FOR_SOF;
                                end
                            end else begin
                                // Even overall packet: final beat is full; need extra checksum beat.
                                if (out_tready) begin
                                    input_fifo_rd_en = 1'b1;
                                    out_tvalid = 1'b1;
                                    out_tdata  = data;
                                    // Compute final checksum for this beat.
                                    computed_checksum = checksum_reg ^ data[15:8] ^ data[7:0];
                                  //  next_checksum = computed_checksum;
                                    next_byte_count = byte_count + 13'd2;
                                    // Instead of waiting for the sequential update, assign next_final_checksum.
                                    next_final_checksum = computed_checksum;
                                    next_state = SEND_CHECKSUM;
                                end
                            end
                        end
                    end
                end

              
                SEND_CHECKSUM: begin
                    if (out_tready) begin
                        out_tvalid = 1'b1;
                     
                        out_tdata = { next_final_checksum, 8'd0};
                        out_tlast = 1'b1;
                        next_state = WAIT_FOR_SOF;
                    end
                end

                default: begin
                    next_state = WAIT_FOR_SOF;
                end
            endcase
        end
    end

endmodule