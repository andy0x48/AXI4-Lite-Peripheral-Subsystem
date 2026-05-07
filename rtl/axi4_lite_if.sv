// axi4_lite_if.sv
// AXI4-Lite Interface; ARM IHI0022E compliant
// Parameterised for address and data width
// Modports:    master (TB Driver)
//              slave  (DUT)
//              monitor (passive)
//

interface axi4_lite_if #(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32
)(
    input logic clk,
    input logic rst_n
);

    // write addr channel
    logic [ADDR_W-1:0]  awaddr;
    logic [2:0]         awprot;
    logic               awvalid;
    logic               awready;

    // write data channel
    logic [DATA_W-1:0]      wdata;
    logic [DATA_W/8-1:0]    wstrb;      // 32-bit; byte en.
    logic                   wvalid;
    logic                   wready;
    
    // write resp channel
    logic [1:0]     bresp;
    logic           bvalid;
    logic           bready;
    
    // read addr channel
    logic [ADDR_W-1:0]  araddr;
    logic [2:0]         arprot;
    logic               arvalid;
    logic               arready;

    // read addr channel
    logic [DATA_W-1:0]  rdata;
    logic [1:0]         rresp;
    logic               rvalid;
    logic               rready;

    // MASTER modport
    modport master (
        input clk, rst_n,
        output awaddr, awprot, awvalid,
        input awready,
        output wdata, wstrb, wvalid,
        input wready,
        input bresp, bvalid,
        output bready,
        output araddr, arprot, arvalid,
        input arready,
        input rdata, rresp, rvalid,
        output rready
    );

    // SLAVE modport
    modport slave (
        input clk, rst_n,
        input awaddr, awprot, awvalid,
        output awready,
        input wdata, wstrb, wvalid,
        output wready,
        output bresp, bvalid,
        input bready,
        input araddr, arprot, arvalid,
        output arready,
        output rdata, rresp, rvalid,
        input rready
    );

    // UVM-monitor modport
    modport monitor (
        input clk, rst_n,
        input awaddr, awprot, awvalid, awready,
        input wdata, wstrb, wvalid, wready,
        input bresp, bvalid, bready,
        input araddr, arprot, arvalid, arready,
        input rdata, rresp, rvalid, rready
    );

endinterface : axi4_lite_if

