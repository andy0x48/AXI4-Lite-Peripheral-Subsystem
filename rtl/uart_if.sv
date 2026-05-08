// uart_if.sv
// UART signal interface -- TB/DUT
// Incl. serial i/o, baud clk, FIFO status, intrrupt
// TODO

interface uart_if (
    input logic clk,
    input logic rst_n
);

    // serial i/o
    logic tx;       // DUT out
    logic rx;       // DUT in

    // baud clk
    logic baud_clk;

    // Tx FIFO status
    logic tx_full;
    logic tx_empty;

    // Rx FIFO status
    logic rx_full;
    logic rx_empty;
    logic rx_valid;

    // interrupt
    logic irq;      // assert on Rx data || Tx empty

    // DUT Modport <- AXI_uart_wrapper
    modport dut (
        input clk, rst_n,
        input rx,
        output tx,
        output baud_clk,
        output tx_full, tx_empty,
        output rx_full, rx_empty, rx_valid,
        output irq 
    );

    // TB Modport
    modport tb (
        input clk, rst_n,
        output rx,          // sim Rx line
        input tx,           // monitor Tx line
        input baud_clk,
        input tx_full, tx_empty,
        input rx_full, rx_empty, rx_valid,
        input irq 
    );

    // Monitor Modport
    modport monitor (
        input clk, rst_n,
        input rx,                 
        input tx,                 
        input baud_clk,
        input tx_full, tx_empty,
        input rx_full, rx_empty, rx_valid,
        input irq 
    );

endinterface : uart_if
