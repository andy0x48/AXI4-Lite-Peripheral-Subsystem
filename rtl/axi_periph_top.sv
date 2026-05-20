// axi_periph_top.sv
// Top-level -- AXI4-Lite Peripheral Subsystem
// Instantiates Xbar, UART, GPIO, DDS periphs. 
// TODO: s1 doc inst interconnect and UART
// TODO: s3 to replace tie-offs with GPIO and DDS axi wrappers


module axi_periph_top #(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32
)(
    input logic clk,
    input logic rst_n,

    // AXI slave port -- HPS or TB master
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

    // UART
    output logic                uart_tx,
    input logic                 uart_rx,

    // GPIO
    output logic [7:0]          gpio_out,
    input logic [7:0]           gpio_in,
    output logic                gpio_irq,

    // DDS
    output logic [11:0]         dds_out,
    output logic                dds_valid
);

    // --- TOP SIGNAL DEFS --- 
    // TODO: arch s1; interconect to UART signal defs
    // SLV0: Interconnect-UART
    logic [ADDR_W-1:0]      s0_awaddr;
    logic [2:0]             s0_awprot;
    logic                   s0_awvalid, s0_awready;
    logic [DATA_W-1:0]      s0_wdata;
    logic [DATA_W/8-1:0]    s0_wstrb;          
    logic                   s0_wvalid, s0_wready;
    logic [1:0]             s0_bresp;
    logic                   s0_bvalid, s0_bready;
    logic [ADDR_W-1:0]      s0_araddr;
    logic [2:0]             s0_arprot;
    logic                   s0_arvalid, s0_arready;
    logic [DATA_W-1:0]      s0_rdata;
    logic [1:0]             s0_rresp;
    logic                   s0_rvalid, s0_rready;

    // UART_TOP: UART-Wrap-to-Core
    logic           uart_wr_en, uart_rd_en;
    logic [7:0]     uart_wr_data, uart_rd_data;
    logic [15:0]    uart_baud_div;
    logic           uart_tx_full, uart_tx_empty;
    logic           uart_rx_full, uart_rx_empty, uart_rx_valid;
    logic           uart_irq;

    // --- COMPONENT INSTANTIATIONS ---
    // TODO: axi4_lite_interconnect inst. 
    axi4_lite_interconnect #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) u_interconnect (
        .clk(clk), .rst_n(rst_n),

        // Master port
        .m_awaddr(s_awaddr), .m_awprot(s_awprot),
        .m_awvalid(s_awvalid), .m_awready(s_awready),
        .m_wdata(s_wdata), .m_wstrb(s_wstrb),
        .m_wvalid(s_wvalid), .m_wready(s_wready),
        .m_bresp(s_bresp), .m_bvalid(s_bvalid), .m_bready(s_bready),
        .m_araddr(s_araddr), .m_arprot(s_arprot),
        .m_arvalid(s_arvalid), .m_arready(s_arready),
        .m_rdata(s_rdata), .m_rresp(s_rresp),
        .m_rvalid(s_rvalid), .m_rready(s_rready),

        // SLV0 port (UART)
        .s0_awaddr(s0_awaddr), .s0_awprot(s0_awprot),
        .s0_awvalid(s0_awvalid), .s0_awready(s0_awready),
        .s0_wdata(s0_wdata), .s0_wstrb(s0_wstrb),
        .s0_wvalid(s0_wvalid), .s0_wready(s0_wready),
        .s0_bresp(s0_bresp), .s0_bvalid(s0_bvalid), .s0_bready(s0_bready),
        .s0_araddr(s0_araddr), .s0_arprot(s0_arprot),
        .s0_arvalid(s0_arvalid), .s0_arready(s0_arready),
        .s0_rdata(s0_rdata), .s0_rresp(s0_rresp),
        .s0_rvalid(s0_rvalid), .s0_rready(s0_rready),

        // SLV1 port (GPIO) TODO: s3
        .s1_awaddr(), .s1_awprot(), .s1_awvalid(), .s1_awready(1'b0),
        .s1_wdata(),  .s1_wstrb(),  .s1_wvalid(),  .s1_wready(1'b0),
        .s1_bresp(2'b00), .s1_bvalid(1'b0), .s1_bready(),
        .s1_araddr(), .s1_arprot(), .s1_arvalid(), .s1_arready(1'b0),
        .s1_rdata('0), .s1_rresp(2'b00), .s1_rvalid(1'b0), .s1_rready(),

        // SLV2 port (DDS) TODO: s3
        .s2_awaddr(), .s2_awprot(), .s2_awvalid(), .s2_awready(1'b0),
        .s2_wdata(),  .s2_wstrb(),  .s2_wvalid(),  .s2_wready(1'b0),
        .s2_bresp(2'b00), .s2_bvalid(1'b0), .s2_bready(),
        .s2_araddr(), .s2_arprot(), .s2_arvalid(), .s2_arready(1'b0),
        .s2_rdata('0), .s2_rresp(2'b00), .s2_rvalid(1'b0), .s2_rready()
    );

    // TODO: axi_uart_wrapper inst.
    axi_uart_wrapper #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) u_uart_wrap (
        .clk(clk), .rst_n(rst_n),

        .s_awaddr(s0_awaddr), .s_awprot(s0_awprot),
        .s_awvalid(s0_awvalid), .s_awready(s0_awready),
        .s_wdata(s0_wdata), .s_wstrb(s0_wstrb),
        .s_wvalid(s0_wvalid), .s_wready(s0_wready),
        .s_bresp(s0_bresp), .s_bvalid(s0_bvalid), .s_bready(s0_bready),
        .s_araddr(s0_araddr), .s_arprot(s0_arprot),
        .s_arvalid(s0_arvalid), .s_arready(s0_arready),
        .s_rdata(s0_rdata), .s_rresp(s0_rresp),
        .s_rvalid(s0_rvalid), .s_rready(s0_rready),

        .wr_en(uart_wr_en), .wr_data(uart_wr_data),
        .rd_en(uart_rd_en), .rd_data(uart_rd_data),
        .baud_div(uart_baud_div),
        .tx_full(uart_tx_full), .tx_empty(uart_tx_empty),
        .rx_full(uart_rx_full), .rx_empty(uart_rx_empty),
        .rx_valid(uart_rx_valid),
        .irq(uart_irq)
    );

    // TODO: uart_core inst.
    uart_core #(.BAUD_DIV_W(16)) u_uart_core (
        .clk(clk), .rst_n(rst_n),

        .wr_en(uart_wr_en), .wr_data(uart_wr_data),
        .rd_en(uart_rd_en), .rd_data(uart_rd_data),
        .baud_div(uart_baud_div),
        .tx_full(uart_tx_full), .tx_empty(uart_tx_empty),
        .rx_full(uart_rx_full), .rx_empty(uart_rx_empty),
        .rx_valid(uart_rx_valid),
        .tx(uart_tx), .rx(uart_rx)
    );

    // TODO: axi_gpio inst.
    // TODO: axi_dds inst.
    

    // FIXME: stubs for future components
    assign gpio_out = 8'h00;
    assign gpio_irq = 1'b0;
    logic unused_ok;
    assign unused_ok = &{gpio_in};

    assign dds_out = 12'h000;
    assign dds_valid = 1'b0;

endmodule: axi_periph_top

