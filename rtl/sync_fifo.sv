// rtl/sync_fifo.sv
// Sync. FIFO with depth/witdth parameterisation
// NO overflow protection; external logic to check full/empty status
// TODO

module sync_fifo #(
    parameter int WIDTH = 8,
    parameter int DEPTH = 8
)(
    input logic             clk,
    input logic             rst_n,

    input logic             wr_en,
    input logic [WIDTH-1:0] wr_data,
    output logic            full,

    input logic                 rd_en,
    output logic [WIDTH-1:0]    rd_data,
    output logic                empty,
    
    output logic [$clog2(DEPTH):0]  count   // no. of entries; empty=0, full=8
);

    localparam int ADDR_W = $clog2(DEPTH);
    localparam logic [ADDR_W:0] DEPTH_VAL = (ADDR_W+1)'(DEPTH);

    logic [WIDTH-1:0]       mem [DEPTH];
    logic [ADDR_W:0]        wr_ptr, rd_ptr;

    // Write ptr
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
        end 
        else if (wr_en && !full) begin
            mem[wr_ptr[ADDR_W-1:0]] <= wr_data;
            wr_ptr <= wr_ptr + 1'b1;
        end 
    end

    // Read ptr
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= '0;
        end 
        else if (rd_en && !empty) begin
            rd_ptr <= rd_ptr + 1'b1;
        end 
    end

    assign rd_data = mem[rd_ptr[ADDR_W-1:0]];
    assign count = wr_ptr - rd_ptr;
    assign full = (count == DEPTH_VAL);
    assign empty = (count == '0);

endmodule : sync_fifo
