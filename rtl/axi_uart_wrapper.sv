// rtl/axi_uart_wrapper.sv
// AXI4-Lite slave wrapper for UART Core
// Implements a register file, AXI handshake FSM, IRQ logic.
// TODO: refactor/edit register mapping 
//      reg map (byte addr, 4-byte aligned):
//          0x00 THR, RBR   - Tx w/Rx r
//          0x04 IER        - intr en; 0=Rx ready, 1=Tx empty
//          0x08 LSR        - line status RO
//          0x0C LCR        - line ctrl (stub; TODO)
//          0x10 BAUD_DIV   - baud divisor; [15:0]


module axi_uart_wrapper #(
    parameter int ADDR_W        = 32,
    parameter int DATA_W        = 32,
    parameter int BAUD_DIV_W    = 16
)(
    input logic     clk,
    input logic     rst_n,

    // AXI slave port
    // write addr channel
    input logic [ADDR_W-1:0]    s_awaddr,
    input logic [2:0]           s_awprot,
    input logic                 s_awvalid,
    output logic                s_awready,

    // write data channel
    input logic [DATA_W-1:0]    s_wdata,
    input logic [DATA_W/8-1:0]  s_wstrb,      // 32-bit; byte en.
    input logic                 s_wvalid,
    output logic                s_wready,
    
    // write resp channel
    output logic [1:0]          s_bresp,
    output logic                s_bvalid,
    input logic                 s_bready,
    
    // read addr channel
    input logic [ADDR_W-1:0]    s_araddr,
    input logic [2:0]           s_arprot,
    input logic                 s_arvalid,
    output logic                s_arready,

    // read addr channel
    output logic [DATA_W-1:0]   s_rdata,
    output logic [1:0]          s_rresp,
    output logic                s_rvalid,
    input logic                 s_rready,

    // UART Core handshake
    output logic                    wr_en,
    output logic [7:0]              wr_data,
    output logic                    rd_en,
    input logic [7:0]               rd_data,
    output logic [BAUD_DIV_W-1:0]   baud_div,

    input logic                     tx_full,
    input logic                     tx_empty,
    input logic                     rx_full,
    input logic                     rx_empty,
    input logic                     rx_valid,

    // IRQ
    output logic    irq
);

    // AXI Resp codes
    localparam logic [1:0] OKAY     = 2'b00;
    localparam logic [1:0] SLVERR   = 2'b10;

    // Reg addr decode -- bits [4:2] for select reg
    localparam logic [2:0] REG_THR_RBR  = 3'h0;
    localparam logic [2:0] REG_IER      = 3'h1;
    localparam logic [2:0] REG_LSR      = 3'h2;
    localparam logic [2:0] REG_LCR      = 3'h3;
    localparam logic [2:0] REG_BAUD     = 3'h4;

    // internal registers
    logic [1:0]             ier;        // IER[1:0]
    logic [7:0]             lcr;        // LCR stub
    logic [BAUD_DIV_W-1:0]  baud_reg;

    // WRITE FSM
    typedef enum logic [2:0] {
        WR_IDLE,
        WR_AW_WAIT,     // have W; waits for AW
        WR_W_WAIT,      // have AW; waits for W
        WR_DO_WRITE,    // both channels done; perform write
        WR_BRESP        // assert BVALID; waits for BREADY
    } wr_state_t;
    wr_state_t      wr_state;

    logic [ADDR_W-1:0]  wr_addr_latch;      // latched wr addr
    logic [DATA_W-1:0]  wr_data_latch;      // latched wr data
    logic [1:0]         wr_resp_latch;      // BRESP to return
    logic               thr_back_pres;      // stall W if Tx FIFO full
    
    // THR wr back pressure; to hold WREADY low when Tx full!
    assign thr_back_pres = (wr_addr_latch[4:2] == REG_THR_RBR) && tx_full;

    always_ff @(posedge clk or negedge rst_n) begin 
        if (!rst_n) begin
            wr_state        <= WR_IDLE;
            s_awready       <= 1'b0;
            s_wready        <= 1'b0;
            s_bvalid        <= 1'b0;
            s_bresp         <= OKAY;
            wr_addr_latch   <= '0;
            wr_data_latch   <= '0;
            wr_resp_latch   <= OKAY;
            wr_en           <= 1'b0;
        end
        else begin
            // set defaults
            s_awready   <= 1'b0;
            s_wready    <= 1'b0;
            wr_en       <= 1'b0;

            case (wr_state)
                WR_IDLE: begin
                    s_bvalid <= 1'b0;
                    if (s_awvalid && s_wvalid) begin
                        // dual channel valid; fast path
                        s_awready       <= 1'b1;
                        wr_addr_latch   <= s_awaddr;
                        // stall W on THR if full!
                        if (!((s_awaddr[4:2] == REG_THR_RBR) && tx_full)) begin
                            s_awready       <= 1'b1;
                            wr_data_latch   <= s_wdata;
                            wr_state        <= WR_DO_WRITE;
                        end
                        // otherwise staying IDLE; WREADY staying low, AW accepted...
                    end
                    else if (s_awvalid) begin
                        // AW before W; latch ADDR; wait for DATA
                        s_awready       <= 1'b1;
                        wr_addr_latch   <= s_awaddr;
                        wr_state        <= WR_W_WAIT;
                    end
                    else if (s_wvalid) begin
                        // W before AW; latch DATA; wait for ADDR
                        wr_data_latch   <= s_wdata;
                        wr_state        <= WR_AW_WAIT;
                    end
                end

                WR_AW_WAIT: begin
                    // have DATA; waits for ADDR
                    if (s_awvalid) begin
                        s_awready       <= 1'b1;
                        wr_addr_latch   <= s_awaddr;
                        wr_state        <= WR_DO_WRITE;
                    end
                end

                WR_W_WAIT: begin
                    // have ADDR; waits for DATA
                    // stall W on THR if full!
                    if (s_wvalid && !(thr_back_pres)) begin
                        s_awready       <= 1'b1;
                        wr_data_latch   <= s_wdata;
                        wr_state        <= WR_DO_WRITE;
                    end
                end

                WR_DO_WRITE: begin
                    // perform reg wr; follow up with BRESP state
                    wr_resp_latch <= OKAY;
                    case (wr_addr_latch[4:2])
                        REG_THR_RBR: begin
                            wr_en   <= 1'b1;
                            wr_data <= wr_data_latch[7:0];
                        end
                        REG_IER: ier            <= wr_data_latch[1:0];
                        REG_LSR: wr_resp_latch  <= SLVERR;      // RO=error
                        REG_LCR: lcr            <= wr_data_latch[7:0];
                        REG_BAUD: baud_reg      <= wr_data_latch[BAUD_DIV_W-1:0];
                        default: wr_resp_latch  <= SLVERR;      // unmmapped
                    endcase
                    s_bvalid    <= 1'b1;
                    s_bresp     <= wr_resp_latch;
                    wr_state    <= WR_BRESP;
                end

                WR_BRESP: begin
                    if (s_bready) begin
                        s_bvalid <= 1'b0;
                        wr_state <= WR_IDLE;
                    end
                end

                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    // READ FSM
    typedef enum logic [1:0] {
        RD_IDLE,
        RD_RESPOND
    } rd_state_t;
    rd_state_t      rd_state;

    logic [ADDR_W-1:0] rd_addr_latch;

    // LSR assembled from core status signals
    logic [DATA_W-1:0] lsr_val;
    assign lsr_val = {
        {(DATA_W-7){1'b0}},     // [:7] reserved
        tx_empty,               // [6] TEMT - Tx'r empty
        tx_empty,               // [5] THRE - Tx holding reg empty
        1'b0,                   // [4] BI - break intr. stub
        1'b0,                   // [3] FE - framing error stub
        1'b0,                   // [2] PE - parity error stub
        rx_full,                // [1] OE - overrun error
        rx_valid                // [0] RXDR - data ready
    };

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_state        <= RD_IDLE;
            s_arready       <= 1'b0;
            s_rvalid        <= 1'b0;
            s_rdata         <= '0;
            s_rresp         <= OKAY;
            rd_en           <= 1'b0;
            rd_addr_latch   <= '0;
        end
        else begin
            s_arready   <= 1'b0;
            rd_en       <= 1'b0;

            case (rd_state)
                RD_IDLE: begin
                    s_rvalid <= 1'b0;
                    if (s_arvalid) begin
                        s_arready       <= 1'b1;
                        rd_addr_latch   <= s_araddr;
                        rd_state        <= RD_RESPOND;
                        // decode reg for response
                        s_rresp         <= OKAY;
                        case (s_araddr[4:2])
                            REG_THR_RBR: begin
                                s_rdata <= {{(DATA_W-8){1'b0}}, rd_data};
                                rd_en   <= 1'b1;    // pop Rx FIFO
                            end
                            REG_IER: s_rdata <= {{(DATA_W-2){1'b0}}, ier};
                            REG_LSR: s_rdata <= lsr_val;
                            REG_LCR: s_rdata <= {{(DATA_W-8){1'b0}}, lcr};
                            REG_BAUD: s_rdata <= {{(DATA_W-BAUD_DIV_W){1'b0}}, baud_reg};
                            default: begin 
                                s_rdata <= '0;
                                s_rresp <= SLVERR;
                            end
                        endcase
                        s_rvalid <= 1'b1;
                    end
                end

                RD_RESPOND: begin
                    if (s_rready) begin
                        s_rvalid <= 1'b0;
                        rd_state <= RD_IDLE;
                    end
                end

                default: rd_state <= RD_IDLE;
            endcase
        end
    end

    // register o/p's
    assign baud_div = baud_reg;

    // IRQ
    // IER[0] enables Rx ready intr.
    // IER[1] enables Tx empty intr.
    assign irq = (ier[0] & rx_valid) | (ier[1] & tx_empty);

endmodule : axi_uart_wrapper
