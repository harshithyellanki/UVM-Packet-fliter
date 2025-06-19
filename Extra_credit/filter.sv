module filter #(
    parameter int INPUT_WIDTH  = 128,
    parameter int OUTPUT_WIDTH = 128
)(
    input  logic                    aclk,
    input  logic                    arst_n,
    // AXI4-Stream input interface
    input  logic                    in_tvalid,
    output logic                    in_tready,
    input  logic [INPUT_WIDTH-1:0]  in_tdata,
    input  logic                    in_tlast,
    // AXI4-Stream output interface
    output logic                    out_tvalid,
    input  logic                    out_tready,
    output logic [OUTPUT_WIDTH-1:0] out_tdata,
    output logic                    out_tlast
);
 
  // Number of bytes per beat.
  localparam INPUT_BYTES  = INPUT_WIDTH  / 8;
  localparam OUTPUT_BYTES = OUTPUT_WIDTH / 8;
 
  // Internal reset: active high.
  logic rst;
  assign rst = !arst_n;
 
  // Filtering decision signal.
  logic filter;
 
  // Generate two implementations: one for 8-bit (narrow) interfaces and one for wider interfaces.
  generate
  // -------------------------------
  // 8-Bit Interface (INPUT_BYTES==1)
  // -------------------------------
  if (INPUT_BYTES == 1) begin : gen_8bit
 
      // Define FSM states: header spans two cycles.
      typedef enum logic [1:0] { 
          IDLE,  // Waiting for start of packet.
          HDR1,  // First header byte captured.
          HDR2,  // Second header byte captured; header beat ready.
          PASS   // Passing payload beats.
      } state_t;
      state_t state;
 
      // Registers to capture header bytes.
      logic [7:0] hdr_byte0, hdr_byte1;
 
      // Output registers drive the physical interface.
      // out_valid indicates when a beat is on the output.
      logic [OUTPUT_WIDTH-1:0] out_buffer;
      logic                    out_valid;
      logic                    out_last_reg;
      // Pending registers hold data if a new beat arrives while the current one is being held.
      logic [OUTPUT_WIDTH-1:0] pending_buffer;
      logic                    pending_valid;
      logic                    pending_last_reg;
 
      // Continuous assignment: when out_valid is false, drive zeros.
      assign out_tdata  = out_valid ? out_buffer : {OUTPUT_WIDTH{1'b0}};
      assign out_tvalid = out_valid;
      assign out_tlast  = out_valid ? out_last_reg : 1'b0;
 
      // in_tready is asserted during header capture or when in PASS and output is free.
      assign in_tready = (state == IDLE) || (state == HDR1) ||
                         ((state == HDR2) && (!pending_valid)) ||
                         ((state == PASS) && (!out_valid));
 
      always_ff @(posedge aclk or posedge rst) begin
         if (rst) begin
            state            <= IDLE;
            out_valid        <= 0;
            pending_valid    <= 0;
            out_last_reg     <= 0;
            pending_last_reg <= 0;
            out_buffer       <= '0;
            pending_buffer   <= '0;
            filter           <= 0;
         end else begin
            // ------------------------------------------------
            // Output Handshake: Once the beat is accepted,
            // clear out_valid and transfer pending beat if any.
            // ------------------------------------------------
            if (out_tvalid && out_tready) begin
                out_valid <= 0;
                if (pending_valid) begin
                    out_buffer   <= pending_buffer;
                    out_valid    <= 1;
                    out_last_reg <= pending_last_reg;
                    pending_valid <= 0;
                end
            end
 
            // ------------------------------------------------
            // Input Processing via FSM
            // ------------------------------------------------
            if (in_tvalid && in_tready) begin
               case (state)
                 IDLE: begin
                     // Capture first header byte.
                     hdr_byte0 <= in_tdata;
                     state <= HDR1;
                 end
 
                 HDR1: begin
                     // Capture second header byte.
                     hdr_byte1 <= in_tdata;
                     // Filtering decision based on the upper nibble of the first header byte.
                     filter <= (hdr_byte0[7:4] == 4'h0) ||
                               (hdr_byte0[7:4] == 4'hA) ||
                               (hdr_byte0[7:4] == 4'h5) ||
                               (hdr_byte0[7:4] == 4'h3);
                     state <= in_tlast ? IDLE : HDR2;
                 end
 
                 HDR2: begin
                     // The header beat is complete.
                     // Reverse filtering: pass packet only if filter is TRUE.
                     if (filter) begin
                        if (!out_valid) begin
                           out_buffer   <= {hdr_byte0, hdr_byte1};
                           out_valid    <= 1;
                           out_last_reg <= in_tlast;
                        end else begin
                           pending_buffer   <= {hdr_byte0, hdr_byte1};
                           pending_valid    <= 1;
                           pending_last_reg <= in_tlast;
                        end
                     end
                     state <= in_tlast ? IDLE : PASS;
                 end
 
                 PASS: begin
                     // During PASS, stream payload beats.
                     if (filter) begin
                        if (!out_valid) begin
                           out_buffer   <= in_tdata;
                           out_valid    <= 1;
                           out_last_reg <= in_tlast;
                        end else begin
                           pending_buffer   <= in_tdata;
                           pending_valid    <= 1;
                           pending_last_reg <= in_tlast;
                        end
                     end
                     if (in_tlast)
                        state <= IDLE;
                 end
 
                 default: state <= IDLE;
               endcase
            end
         end
      end
 
  end else begin : gen_wide
      // --------------------------------------------
      // Wide Interfaces (INPUT_BYTES > 1, typically =16-bit)
      // --------------------------------------------
      // Use a simpler twostate FSM.
      typedef enum logic {IDLE, PASS} state_t;
      state_t state;
 
      logic [OUTPUT_WIDTH-1:0] out_buffer;
      logic                    out_valid;
      logic                    out_last_reg;
 
      logic [OUTPUT_WIDTH-1:0] pending_buffer;
      logic                    pending_valid;
      logic                    pending_last_reg;
 
      assign out_tdata  = out_buffer;
      assign out_tvalid = out_valid;
      assign out_tlast  = out_valid ? out_last_reg : 1'b0;
 
      // Extract header from the upper 16 bits.
      logic [15:0] header_bytes;
      always_comb begin
          header_bytes = in_tdata[INPUT_WIDTH-1 -: 16];
          filter = (header_bytes[15-:4] == 4'h0) ||
                   (header_bytes[15-:4] == 4'hA) ||
                   (header_bytes[15-:4] == 4'h5) ||
                   (header_bytes[15-:4] == 4'h3);
      end
 
      // in_tready is asserted when idle or in PASS with output free.
      assign in_tready = (state == IDLE) || ((state == PASS) && (!out_valid));
 
      always_ff @(posedge aclk or posedge rst) begin
         if (rst) begin
             state            <= IDLE;
             out_valid        <= 0;
             pending_valid    <= 0;
             out_last_reg     <= 0;
             pending_last_reg <= 0;
             out_buffer       <= '0;
             pending_buffer   <= '0;
         end else begin
            if (out_tvalid && out_tready) begin
              out_valid <= 0;
              if (pending_valid) begin
                out_buffer   <= pending_buffer;
                out_valid    <= 1;
                out_last_reg <= pending_last_reg;
                pending_valid <= 0;
              end
            end
 
            if (in_tvalid && in_tready) begin
              if (state == IDLE) begin
                 if (filter) begin  // Reverse filtering: pass packet only if filter is TRUE.
                    if (!out_valid) begin
                       out_buffer   <= in_tdata[OUTPUT_WIDTH-1:0];
                       out_valid    <= 1;
                       out_last_reg <= in_tlast;
                    end else begin
                       pending_buffer   <= in_tdata[OUTPUT_WIDTH-1:0];
                       pending_valid    <= 1;
                       pending_last_reg <= in_tlast;
                    end
                 end
                 state <= in_tlast ? IDLE : PASS;
              end else begin // PASS state
                 if (filter) begin  // Reverse filtering: only drive output if condition is met.
                    if (!out_valid) begin
                       out_buffer   <= in_tdata[OUTPUT_WIDTH-1:0];
                       out_valid    <= 1;
                       out_last_reg <= in_tlast;
                    end else begin
                       pending_buffer   <= in_tdata[OUTPUT_WIDTH-1:0];
                       pending_valid    <= 1;
                       pending_last_reg <= in_tlast;
                    end
                 end
                 if (in_tlast)
                    state <= IDLE;
              end
            end
         end
      end
 
  end // gen_wide
  endgenerate
 
endmodule

