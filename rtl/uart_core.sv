// rtl/uart_core.sv
// UART core with Tx/Rx sync. FIFOs, baud gen., and UART frame FSMs
// TODO

module uart_core #(
    parameter BAUD_DIV_W = 16
)(
    input logic         clk,
    input logic         rst_n,

    // internal reg interface <-> wrapper
    input logic         wr_en,          // push byte -> Tx FIFO
    input logic [7:0]   wr_data,
    input logic         rd_en,          // pop byte <- Rx FIFO
    output logic [7:0]  rd_data,
    input logic [BAUD_DIV_W-1:0]  baud_div,     // divisor for sampling/gen

    // buf. status
    output logic        tx_full,
    output logic        tx_empty,
    output logic        rx_full,
    output logic        rx_empty,
    output logic        rx_valid,

    // serial
    output logic        tx,
    input logic         rx
);

    // Rx i/p synchronisers
    logic rx_sync1, rx_sync2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end
        else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end

    // Tx FIFO inst.
    logic [7:0]     txf_rd_data;
    logic           txf_rd_en;
    logic           txf_empty;
    logic           txf_full;
    // logic [$clog2(8):0] tx_count; // TODO not used

    sync_fifo #(.WIDTH(8), .DEPTH(8)) tx_fifo (
        .clk(clk), .rst_n(rst_n),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .full(txf_full),
        .rd_en(txf_rd_en),
        .rd_data(txf_rd_data),
        .empty(txf_empty),
        .count()
    );

    // Rx FIFO inst.
    logic [7:0]     rxf_wr_data;
    logic           rxf_wr_en;
    logic           rxf_empty;
    logic           rxf_full;
    // logic [$clog2(8):0] rx_count; // TODO not used

    sync_fifo #(.WIDTH(8), .DEPTH(8)) rx_fifo (
        .clk(clk), .rst_n(rst_n),
        .wr_en(rxf_wr_en),
        .wr_data(rxf_wr_data),
        .full(rxf_full),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .empty(rxf_empty),
        .count()
    );

    assign tx_full = txf_full;
    assign tx_empty = txf_empty;
    assign rx_full = rxf_full;
    assign rx_empty = rxf_empty;
    assign rx_valid = !rxf_empty;

    // Baud gen.
    logic baud_tick, baud_tick_16x;
    logic [BAUD_DIV_W-1:0]  baud_cnt;
    logic [3:0]             oversample_cnt;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt <= '0;
            baud_tick <= 1'b0;
            baud_tick_16x <= 1'b0;
            oversample_cnt <= '0;
        end
        else begin
            if (baud_cnt == baud_div) begin
                baud_cnt <= '0;
                baud_tick_16x <= 1'b1;
                if (oversample_cnt == 4'd15) begin
                    oversample_cnt <= '0;
                    baud_tick <= 1'b1;
                end 
                else begin 
                    oversample_cnt <= oversample_cnt + 1'b1;
                    baud_tick <= 1'b0;
                end
            end 
            else begin
                baud_cnt <= baud_cnt + 1'b1;
                baud_tick_16x <= 1'b0;
                baud_tick <= 1'b0;
            end 
        end
    end

    // Tx FSM == baud is single tick
    typedef enum logic [1:0] {
        TX_IDLE, 
        TX_START,
        TX_DATA,
        TX_STOP
    } tx_state_t;
    tx_state_t      tx_state, tx_next;
    logic [2:0]     tx_bit_cnt;
    logic [7:0]     tx_shift;
    logic           tx_done;        // high @ 1 baud tick when stop bit finished

    always_comb begin
        tx_next = tx_state;
        case (tx_state)
            TX_IDLE:    if (!txf_empty) tx_next = TX_START;
            TX_START:   if (baud_tick) tx_next = TX_DATA;
            TX_DATA:    if (baud_tick && tx_bit_cnt == 3'd7) tx_next = TX_STOP;
            TX_STOP:    if (baud_tick) tx_next = TX_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state    <= TX_IDLE;
            tx          <= 1'b1;
            tx_bit_cnt  <= '0;
            tx_shift    <= '0;
            tx_done     <= 1'b0;
            txf_rd_en   <= 1'b0;
        end 
        else begin
            tx_state <= tx_next;
            tx_done <= 1'b0;
            txf_rd_en <= 1'b0;

            case (tx_state)
                TX_IDLE: begin
                    tx <= 1'b1;
                    if (tx_next == TX_START) begin
                        txf_rd_en <= 1'b1;      // pop byte on next cycle; load @ start
                        tx <= 1'b0;
                    end
                end
                TX_START: begin
                    tx <= 1'b0;
                    if (baud_tick) begin
                        tx_shift <= txf_rd_data;    // load shift reg; FIFO data
                        tx_bit_cnt <= '0;
                        tx <= txf_rd_data[0];
                    end
                end
                TX_DATA: begin
                    if (baud_tick) begin
                        tx <= tx_shift[0];
                        tx_shift <= { 1'b0, tx_shift[7:1] };  // right-shift
                        if (tx_bit_cnt == 3'd7) begin
                            // last bit; move to stop
                        end
                        else begin
                            tx_bit_cnt <= tx_bit_cnt + 1'b1;
                        end
                    end
                end
                TX_STOP: begin
                    if (baud_tick) begin
                        tx <= 1'b1;
                        tx_done <= 1'b1;
                    end
                end
            endcase
        end
    end

    // Rx FSM == baud is 16x oversampling tick
    typedef enum logic [1:0] {
        RX_IDLE, 
        RX_DATA,
        RX_STOP
    } rx_state_t;
    rx_state_t      rx_state, rx_next;
    logic [3:0]     sample_cnt;     // keeping track of data bit; 0-15
    logic [2:0]     rx_bit_cnt;
    logic [7:0]     rx_shift;
    
    always_comb begin
        rx_next = rx_state;
        case (rx_state)
            RX_IDLE:    if (!rx_sync2) rx_next = RX_DATA;     // Assumes start bit detected @ 0
            RX_DATA:    if (sample_cnt == 4'd15 && baud_tick_16x && rx_bit_cnt == 3'd7) rx_next = RX_STOP;
            RX_STOP:    if (sample_cnt == 4'd15 && baud_tick_16x) rx_next = RX_IDLE;
            default:    rx_next = RX_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state    <= RX_IDLE;
            sample_cnt  <= '0;
            rx_bit_cnt  <= '0;
            rx_shift    <= '0;
            rxf_wr_en   <= 1'b0;
            rxf_wr_data <= '0;
        end 
        else begin
            rx_state <= rx_next;
            rxf_wr_en <= 1'b0;

            case (rx_state)
                RX_IDLE: begin
                    if (rx_next == RX_DATA) begin
                        // sample bit detection here; sample middle of data bit
                        sample_cnt <= 4'd8;
                        rx_bit_cnt <= '0;
                    end
                    else begin
                        sample_cnt <= '0;
                    end
                end
                RX_DATA: begin
                    if (baud_tick_16x) begin
                        if (sample_cnt == 4'd8) begin
                            rx_shift <= { rx_sync2, rx_shift[7:1] };      // LSB first
                        end
                        if (sample_cnt == 4'd15) begin
                            sample_cnt <= '0;
                            if (rx_bit_cnt != 3'd7) begin
                                rx_bit_cnt <= rx_bit_cnt + 1'b1;
                            end
                        end
                        else begin
                            sample_cnt <= sample_cnt + 1'b1;
                        end
                    end
                end
                RX_STOP: begin
                    if (baud_tick_16x) begin
                        if (sample_cnt == 4'd8) begin
                            if (rx_sync2 == 1'b1) begin
                                rxf_wr_en <= 1'b1;
                                rxf_wr_data <= rx_shift;    // assembled byte
                            end
                        // else frame error!
                        end
                        if (sample_cnt == 4'd15) begin
                            sample_cnt <= '0;
                        end
                        else begin
                            sample_cnt <= sample_cnt + 1'b1;
                        end
                    end
                    
                end
                default: rx_state <= RX_IDLE;
            endcase
        end
    end

endmodule : uart_core
