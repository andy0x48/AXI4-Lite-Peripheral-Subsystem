// axi_periph_top.sv
// Top-level -- AXI4-Lite Peripheral Subsystem
// Instantiates Xbar, UART, GPIO, DDS periphs. 
// TODO


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

    // TODO axi4_lite_xbar
    // TODO axi_uart_ctrl
    // TODO axi_gpio
    // TODO axi_dds
    
    // FIXME tying periphs as low until instantiated
    assign s_awready    = 1'b0;
    assign s_wready     = 1'b0;
    assign s_bresp      = 2'b00;
    assign s_bvalid     = 1'b0;
    assign s_arready    = 1'b0;
    assign s_rdata      = '0;
    assign s_rresp      = 2'b00;
    assign s_rvalid     = 1'b0;

    assign uart_tx = 1'b1;      // default idle high
    assign gpio_out = 8'h00;
    assign gpio_irq = 1'b0;
    assign dds_out = 12'h000;
    assign dds_valid = 1'b0;

endmodule: axi_periph_top

