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

    // Clock and active-high reset.
    logic clk;
    logic rst;
    assign clk = aclk;
    assign rst = !arst_n;

    // Check parameters.
    initial if (INPUT_WIDTH % 8 != 0)
      $fatal(1, $sformatf("AXI requires INPUT_WIDTH (%0d) to be byte aligned", INPUT_WIDTH));
    initial if (OUTPUT_WIDTH % 8 != 0)
      $fatal(1, $sformatf("AXI requires OUTPUT_WIDTH (%0d) to be byte aligned", OUTPUT_WIDTH));
    initial if (INPUT_WIDTH != 16 || OUTPUT_WIDTH != 16)
      $fatal(1, "Interface widths must both be 16 bits.");

    // FIFO interface signals.
    logic                     input_fifo_full;
    logic                     input_fifo_wr_en;
    logic [INPUT_WIDTH+2-1:0] input_fifo_wr_data;
    logic                     input_fifo_empty;
    logic                     input_fifo_rd_en;
    logic [INPUT_WIDTH+2-1:0] input_fifo_rd_data;

    // Track start-of-frame flag.
    logic in_sof_r;
    assign in_tready = !input_fifo_full;
    assign input_fifo_wr_en  = in_tvalid && in_tready;
    assign input_fifo_wr_data = {in_sof_r, in_tlast, in_tdata};

    // Determine sof status.
    always_ff @(posedge clk) begin
        if (rst)
            in_sof_r <= 1'b1;
        else if (input_fifo_wr_en)
            in_sof_r <= in_tlast; // edge between beats, not necessarily relevant here.
    end

    // Instantiate the FIFO.
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

  
    typedef enum logic [0:0] {
        PASS, // allowed packet
        FILTER // drop packet
    } filter_t;
    filter_t filter_r;
  
    

    typedef enum logic [1:0] {
        WAIT_FOR_SOF,   
        PROCESS_PACKET, 
        SEND_CHECKSUM   
    } state_t;
    state_t state_r, next_state;
    
    
    logic [7:0]  checksum_reg, next_checksum;
    logic [12:0] byte_count, next_byte_count; 
    logic [11:0] total_valid_bytes_reg, next_total_valid_bytes;
    logic        odd_flag, next_odd_flag;
    logic [15:0] header_data_reg, next_header_data;


    always_ff @(posedge clk) begin
        if (rst) begin
            state_r              <= WAIT_FOR_SOF;
            checksum_reg         <= 8'd0;
            byte_count           <= 13'd0;
            total_valid_bytes_reg<= 12'd0;
            odd_flag             <= 1'b0;
            header_data_reg      <= 16'd0;
            filter_r             <= FILTER;
        end else begin
            state_r              <= next_state;
            checksum_reg         <= next_checksum;
            byte_count           <= next_byte_count;
            total_valid_bytes_reg<= next_total_valid_bytes;
            odd_flag             <= next_odd_flag;
            header_data_reg      <= next_header_data;
            filter_r             <= (state_r == WAIT_FOR_SOF) ? ( ~(msg_type inside {4'h0,4'ha,4'h5,4'h3}) ) : filter_r;
        end
    end


    always_comb begin
        next_state         = state_r;
        input_fifo_rd_en   = 1'b0;
        out_tvalid         = 1'b0;
        out_tlast          = 1'b0;
        out_tdata          = '0;
        next_checksum      = checksum_reg;
        next_byte_count    = byte_count;
        next_total_valid_bytes = total_valid_bytes_reg;
        next_odd_flag      = odd_flag;
        next_header_data   = header_data_reg;



        if (filter_r == FILTER) begin

            if (!input_fifo_empty) begin
                input_fifo_rd_en = (out_tready || 1'b1);
                if (eof)
                    next_state = WAIT_FOR_SOF;
            end

        end else begin
            
            case (state_r)
                WAIT_FOR_SOF: begin
                    if (!input_fifo_empty && sof) begin
                        next_header_data = data;
                        
                        next_total_valid_bytes = 12'd2 + { data[11:8], data[7:0] };
                       
                        next_odd_flag = next_total_valid_bytes[0]; 
                       
                        next_checksum = 8'd0 ^ data[15:8] ^ data[7:0];
                        next_byte_count = 13'd2;
                      
                        if (out_tready) begin
                            input_fifo_rd_en = 1'b1;
                            out_tvalid = 1'b1;
                            out_tdata  = data;
                            
                            if (eof)
                                next_state = (next_odd_flag) ? WAIT_FOR_SOF : SEND_CHECKSUM;
                            else
                                next_state = PROCESS_PACKET;
                        end
                    end
                end

                PROCESS_PACKET: begin
                    if (!input_fifo_empty) begin
                        
                        if (!eof) begin
                          
                            if (out_tready) begin
                                input_fifo_rd_en = 1'b1;
                                out_tvalid = 1'b1;
                                out_tdata  = data;
                                
                                next_checksum = checksum_reg ^ data[15:8] ^ data[7:0];
                                next_byte_count = byte_count + 13'd2;
                            end
                            next_state = PROCESS_PACKET;
                        end else begin
                         
                            if (next_odd_flag) begin
                             
                                if (out_tready) begin
                                    input_fifo_rd_en = 1'b1;
                                   
                                    next_checksum = checksum_reg ^ data[15:8];
                                    
                                    out_tdata  = { data[15:8], (checksum_reg ^ data[15:8]) };
                                    out_tvalid = 1'b1;
                                    out_tlast  = 1'b1;
                                    next_state = WAIT_FOR_SOF;
                                end
                            end else begin
                                
                                if (out_tready) begin
                                    input_fifo_rd_en = 1'b1;
                                    out_tvalid = 1'b1;
                                    out_tdata  = data;
                                   
                                    next_checksum = checksum_reg ^ data[15:8] ^ data[7:0];
                                    next_byte_count = byte_count + 13'd2;
                                    
                                    next_state = SEND_CHECKSUM;
                                end
                            end
                        end
                    end
                end

                SEND_CHECKSUM: begin
                  
                    if (out_tready) begin
                        out_tvalid = 1'b1;
                        out_tdata  = {checksum_reg, 8'd0};
                        out_tlast  = 1'b1;
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
