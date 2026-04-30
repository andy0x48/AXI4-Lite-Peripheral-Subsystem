// tb_axi4_lite_if.sv
// TB WRAPPER; adds clking block over base IF

`ifndef TB_AXI4_LITE_IF_SV
`define TB_AXI4_LITE_IF_SV

interface tb_axi4_lite_if #(
    parameter int ADDR_W = 32
    parameter int DATA_W = 32
)(
    input logic clk,
    input logic rst_n
);

    // BASE IF instance
    axi4_lite_if #(ADDR_W, DATA_W) axi (.clk(clk), .rst_n(rst_n));

    // Clking block
    clocking cb @(posedge clk);
        default input #1step output #1;
        output axi.awaddr, axi.awprot, axi.awvalid;
        input axi.awready;
        output axi.wdata, axi.wstrb, axi.wvalid;
        input axi.wready;
        input axi.bresp, axi.bvalid;
        output axi.bready;
        output axi.araddr, axi.arprot, axi.arvalid;
        input axi.arready;
        input axi.rdata, axi.rresp, axi.rvalid;
        output axi.rready;
    endclocking

    // SVA here #TODO

endinterface : tb_axi4_lite_if

`endif

