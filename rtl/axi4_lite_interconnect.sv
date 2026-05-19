// rtl/axi4_lite_interconnect.sv
// AXI4-Lite 1M-to-nS Interconnect
// Routes AXI txn's
//
// addr map TODO:
//      UART    : 0x0000_0000 - 0x0000_FFFF addr[17:16] = 2'b00
//      UART    : 0x0001_0000 - 0x0001_FFFF addr[17:16] = 2'b01
//      UART    : 0x0002_0000 - 0x0002_FFFF addr[17:16] = 2'b10
//      ERROR   : all others => SLVERR
//
// write path:  WR_IDLE > WR_AW_TO_SLV > WR_W_AND_B > WR_IDLE
//              WR_IDLE > WR_ERR_W > WR_ERR_B > WR_IDLE
// write path:  RD_IDLE > RD_AR_TO_SLV > RD_R_FROM_SLV > RD_IDLE
//              RD_IDLE > RD_ERR_R > RD_IDLE

module axi4_lite_interconnect #(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32
)(
    input logic             clk,
    input logic             rst_n,

    // --- MASTER PORT ---
    // AW
    input logic [ADDR_W-1:0]    m_awaddr,
    input logic [2:0]           m_awprot,
    input logic                 m_awvalid,
    output logic                m_awready,

    // W
    input logic [DATA_W-1:0]    m_wdata,
    input logic [DATA_W/8-1:0]  m_wstrb,
    input logic                 m_wvalid,
    output logic                m_wready,

    // B
    output logic [1:0]          m_bresp,
    output logic                m_bvalid,
    input logic                 m_bready,

    // AR
    input logic [ADDR_W-1:0]    m_araddr,
    input logic [2:0]           m_arprot,
    input logic                 m_arvalid,
    output logic                m_arready,

    // R
    output logic [DATA_W-1:0]   m_rdata,
    output logic [1:0]          m_rresp,
    output logic                m_rvalid,
    input logic                 m_rready,

    // --- SLV PORT 0 - UART ---
    // AW
    output logic [ADDR_W-1:0]   s0_awaddr,
    output logic [2:0]          s0_awprot,
    output logic                s0_awvalid,
    input logic                 s0_awready,

    // W
    output logic [DATA_W-1:0]   s0_wdata,
    output logic [DATA_W/8-1:0] s0_wstrb,
    output logic                s0_wvalid,
    input logic                 s0_wready,

    // B
    input logic [1:0]           s0_bresp,
    input logic                 s0_bvalid,
    output logic                s0_bready,

    // AR
    output logic [ADDR_W-1:0]   s0_araddr,
    output logic [2:0]          s0_arprot,
    output logic                s0_arvalid,
    input logic                 s0_arready,

    // R
    input logic [DATA_W-1:0]    s0_rdata,
    input logic [1:0]           s0_rresp,
    input logic                 s0_rvalid,
    output logic                s0_rready,

    // --- SLV PORT 1 - GPIO ---
    // AW
    output logic [ADDR_W-1:0]   s1_awaddr,
    output logic [2:0]          s1_awprot,
    output logic                s1_awvalid,
    input logic                 s1_awready,

    // W
    output logic [DATA_W-1:0]   s1_wdata,
    output logic [DATA_W/8-1:0] s1_wstrb,
    output logic                s1_wvalid,
    input logic                 s1_wready,

    // B
    input logic [1:0]           s1_bresp,
    input logic                 s1_bvalid,
    output logic                s1_bready,

    // AR
    output logic [ADDR_W-1:0]   s1_araddr,
    output logic [2:0]          s1_arprot,
    output logic                s1_arvalid,
    input logic                 s1_arready,

    // R
    input logic [DATA_W-1:0]    s1_rdata,
    input logic [1:0]           s1_rresp,
    input logic                 s1_rvalid,
    output logic                s1_rready,
    
    // --- SLV PORT 2 - DDS ---
    // AW
    output logic [ADDR_W-1:0]   s2_awaddr,
    output logic [2:0]          s2_awprot,
    output logic                s2_awvalid,
    input logic                 s2_awready,

    // W
    output logic [DATA_W-1:0]   s2_wdata,
    output logic [DATA_W/8-1:0] s2_wstrb,
    output logic                s2_wvalid,
    input logic                 s2_wready,

    // B
    input logic [1:0]           s2_bresp,
    input logic                 s2_bvalid,
    output logic                s2_bready,

    // AR
    output logic [ADDR_W-1:0]   s2_araddr,
    output logic [2:0]          s2_arprot,
    output logic                s2_arvalid,
    input logic                 s2_arready,

    // R
    input logic [DATA_W-1:0]    s2_rdata,
    input logic [1:0]           s2_rresp,
    input logic                 s2_rvalid,
    output logic                s2_rready
);
    
    // Constants
    localparam logic [1:0] SEL_UART     = 2'd0;
    localparam logic [1:0] SEL_GPIO     = 2'd1;
    localparam logic [1:0] SEL_DDS      = 2'd2;
    localparam logic [1:0] SEL_ERR      = 2'd3;

    localparam logic [1:0] OKAY         = 2'b00;
    localparam logic [1:0] SLVERR       = 2'b10;

    // Address Decoder
    logic [1:0] wr_addr_dec, rd_addr_dec;

    always_comb begin
        case (m_awaddr[17:16])
            2'b00:      wr_addr_dec = SEL_UART;
            2'b01:      wr_addr_dec = SEL_GPIO;
            2'b10:      wr_addr_dec = SEL_DDS;
            default:    wr_addr_dec = SEL_ERR;
        endcase
    end

    always_comb begin
        case (m_araddr[17:16])
            2'b00:      rd_addr_dec = SEL_UART;
            2'b01:      rd_addr_dec = SEL_GPIO;
            2'b10:      rd_addr_dec = SEL_DDS;
            default:    rd_addr_dec = SEL_ERR;
        endcase
    end

    // ------------
    
    // WRITE PATH
    typedef enum logic [2:0] {
        WR_IDLE,
        WR_AW_TO_SLV,       // forward buffered AW to selected slave
        WR_W_AND_B,         // route W to slave; B from slave
        WR_ERR_W,           // unmapped: consume W channel
        WR_ERR_B            // unmapped: return SLVERR on B
    } wr_state_t;

    wr_state_t          wr_state;
    logic [1:0]         wr_sel;
    logic [ADDR_W-1:0]  aw_addr_buf;
    logic [2:0]         aw_prot_buf;

    // Write state FSM 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_state    <= WR_IDLE;
            wr_sel      <= SEL_ERR;
            aw_addr_buf <= '0;
            aw_prot_buf <= '0;
        end
        else begin
            case (wr_state)
                WR_IDLE: begin
                    if (m_awvalid) begin
                        aw_addr_buf <= m_awaddr;
                        aw_prot_buf <= m_awprot;
                        wr_sel      <= wr_addr_dec;
                        wr_state    <= (wr_addr_dec == SEL_ERR) 
                                        ? WR_ERR_W : WR_AW_TO_SLV;
                    end
                end

                WR_AW_TO_SLV: begin
                    // waits for selected SLV to accept AW
                    case (wr_sel)
                        SEL_UART:   if (s0_awready) wr_state <= WR_W_AND_B;
                        SEL_GPIO:   if (s1_awready) wr_state <= WR_W_AND_B;
                        SEL_DDS:    if (s2_awready) wr_state <= WR_W_AND_B;
                        default:    wr_state <= WR_ERR_W;
                    endcase
                end

                WR_W_AND_B: begin
                    // hold until B handshake completes
                    // m_bvalid is comb from SLV; check directly
                    case (wr_sel)
                        SEL_UART:   if (s0_bvalid && m_bready) wr_state <= WR_IDLE;
                        SEL_GPIO:   if (s1_bvalid && m_bready) wr_state <= WR_IDLE;
                        SEL_DDS:    if (s2_bvalid && m_bready) wr_state <= WR_IDLE;
                        default:    wr_state <= WR_IDLE;
                    endcase
                end

                WR_ERR_W: begin
                    // accept W and discard
                    if (m_wvalid) wr_state <= WR_ERR_B;
                end

                WR_ERR_B: begin
                    // SLVERR response; wait for MASTER to accept
                    if (m_bready) wr_state <= WR_IDLE;
                end

                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    // Write combinational o/p FSM
    always_comb begin
        // default => inactive
        m_awready   = 1'b0;
        m_wready    = 1'b0;
        m_bvalid    = 1'b0;
        m_bresp     = OKAY;
        s0_awvalid = 1'b0;  s1_awvalid = 1'b0;  s2_awvalid = 1'b0;
        s0_wvalid = 1'b0;   s1_wvalid = 1'b0;   s2_wvalid = 1'b0;
        s0_bready = 1'b0;   s1_bready = 1'b0;   s2_bready = 1'b0;
       
        case (wr_state)
            WR_IDLE: begin
                // ready to accept AW @ IDLE
                m_awready = 1'b1;
            end

            WR_AW_TO_SLV: begin
                // present buffered AW to selected SLV
                case (wr_sel)
                    SEL_UART:   s0_awvalid = 1'b1;
                    SEL_GPIO:   s1_awvalid = 1'b1;
                    SEL_DDS:    s2_awvalid = 1'b1;
                    default:    ;   // SEL_ERR; no SLV
                endcase
            end

            WR_W_AND_B: begin
                // route W MASTER to SLV, B SLV to MASTER
                case (wr_sel)
                    SEL_UART: begin
                        s0_wvalid   = m_wvalid;
                        m_wready    = s0_wready;
                        m_bvalid    = s0_bvalid;
                        m_bresp     = s0_bresp;
                        s0_bready   = m_bready;
                    end
                    SEL_GPIO: begin
                        s1_wvalid   = m_wvalid;
                        m_wready    = s1_wready;
                        m_bvalid    = s1_bvalid;
                        m_bresp     = s1_bresp;
                        s1_bready   = m_bready;
                    end
                    SEL_DDS: begin
                        s2_wvalid   = m_wvalid;
                        m_wready    = s2_wready;
                        m_bvalid    = s2_bvalid;
                        m_bresp     = s2_bresp;
                        s2_bready   = m_bready;
                    end
                    default:    ;   // unreachable
                endcase
            end

            WR_ERR_W: begin
                m_wready = 1'b1;    // accept & discard
            end

            WR_ERR_B: begin
                m_bvalid    = 1'b1;
                m_bresp     = SLVERR;
            end

            default:    ;
        endcase
    end

    // ------------
    
    // READ PATH
    typedef enum logic [2:0] {
        RD_IDLE,
        RD_AR_TO_SLV,       // forward buffered AR to selected slave
        RD_R_FROM_SLV,      // route R to slave from master
        RD_ERR_R            // unmapped: return SLVERR on R
    } rd_state_t;

    rd_state_t          rd_state;
    logic [1:0]         rd_sel;
    logic [ADDR_W-1:0]  ar_addr_buf;
    logic [2:0]         ar_prot_buf;

    // Read state FSM 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_state    <= RD_IDLE;
            rd_sel      <= SEL_ERR;
            ar_addr_buf <= '0;
            ar_prot_buf <= '0;
        end
        else begin
            case (rd_state)
                RD_IDLE: begin
                    if (m_arvalid) begin
                        ar_addr_buf <= m_araddr;
                        ar_prot_buf <= m_arprot;
                        rd_sel      <= rd_addr_dec;
                        rd_state    <= (rd_addr_dec == SEL_ERR) 
                                        ? RD_ERR_R : RD_AR_TO_SLV;
                    end
                end

                RD_AR_TO_SLV: begin
                    // waits for selected SLV to accept AR
                    case (rd_sel)
                        SEL_UART:   if (s0_arready) rd_state <= RD_R_FROM_SLV;
                        SEL_GPIO:   if (s1_arready) rd_state <= RD_R_FROM_SLV;
                        SEL_DDS:    if (s2_arready) rd_state <= RD_R_FROM_SLV;
                        default:    rd_state <= RD_ERR_R;
                    endcase
                end

                RD_R_FROM_SLV: begin
                    // hold until R handshake completes
                    // m_rvalid is comb from SLV; check directly
                    case (rd_sel)
                        SEL_UART:   if (s0_rvalid && m_rready) rd_state <= RD_IDLE;
                        SEL_GPIO:   if (s1_rvalid && m_rready) rd_state <= RD_IDLE;
                        SEL_DDS:    if (s2_rvalid && m_rready) rd_state <= RD_IDLE;
                        default:    rd_state <= RD_IDLE;
                    endcase
                end

                RD_ERR_R: begin
                    // SLVERR response; wait for MASTER to accept
                    if (m_rready) rd_state <= RD_IDLE;
                end

                default: rd_state <= RD_IDLE;
            endcase
        end
    end

    // Read combinational o/p FSM
    always_comb begin
        // default => inactive
        m_arready   = 1'b0;
        m_rvalid    = 1'b0;
        m_rdata     = '0;
        m_rresp     = OKAY;
        s0_arvalid = 1'b0;  s1_arvalid = 1'b0;  s2_arvalid = 1'b0;
        s0_rready = 1'b0;   s1_rready = 1'b0;   s2_rready = 1'b0;

        case (rd_state)
            RD_IDLE: begin
                // ready to accept AR @ IDLE
                m_arready = 1'b1;
            end

            RD_AR_TO_SLV: begin
                // present buffered AR to selected SLV
                case (rd_sel)
                    SEL_UART:   s0_arvalid = 1'b1;
                    SEL_GPIO:   s1_arvalid = 1'b1;
                    SEL_DDS:    s2_arvalid = 1'b1;
                    default:    ;   // SEL_ERR; no SLV
                endcase
            end

            RD_R_FROM_SLV: begin
                // TODO comment about flow below
                case (wr_sel)
                    SEL_UART: begin
                        m_rvalid    = s0_rvalid;
                        m_rdata     = s0_rdata;
                        m_rresp     = s0_rresp;
                        s0_rready   = m_rready;
                    end
                    SEL_GPIO: begin
                        m_rvalid    = s1_rvalid;
                        m_rdata     = s1_rdata;
                        m_rresp     = s1_rresp;
                        s1_rready   = m_rready;
                    end
                    SEL_DDS: begin
                        m_rvalid    = s2_rvalid;
                        m_rdata     = s2_rdata;
                        m_rresp     = s2_rresp;
                        s2_rready   = m_rready;
                    end
                    default:    ;   // unreachable
                endcase
            end

            RD_ERR_R: begin
                m_rvalid    = 1'b1;
                m_rdata     = '0;
                m_rresp     = SLVERR;
            end

            default:    ;
        endcase
    end

    // ------------
    
    // Static addr/data forwarding to all slaves
    // Valid signal gates which slave actually transacts
    //
    // write addr -- buffered, broadcast to all, selected has awvalid=1
    assign s0_awaddr = aw_addr_buf; assign s0_awprot = aw_prot_buf;
    assign s1_awaddr = aw_addr_buf; assign s1_awprot = aw_prot_buf;
    assign s2_awaddr = aw_addr_buf; assign s2_awprot = aw_prot_buf;

    // write data -- broadcast, gated by wvalid MUX above
    assign s0_wdata = m_wdata; assign s0_wstrb = m_wstrb;
    assign s1_wdata = m_wdata; assign s1_wstrb = m_wstrb;
    assign s2_wdata = m_wdata; assign s2_wstrb = m_wstrb;

    // read addr -- buffered, broadcast
    assign s0_araddr = ar_addr_buf; assign s0_arprot = ar_prot_buf;
    assign s1_araddr = ar_addr_buf; assign s1_arprot = ar_prot_buf;
    assign s2_araddr = ar_addr_buf; assign s2_arprot = ar_prot_buf;

endmodule : axi4_lite_interconnect



