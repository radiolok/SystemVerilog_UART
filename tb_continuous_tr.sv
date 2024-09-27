`timescale 1ns / 1ps

module tb_continuous_rw(    );


initial begin $dumpfile("tb_continuous_rw.vcd"); 
$dumpvars(0,tb_continuous_rw); end
/*****************************************************************************
*                                 variable                                  *
*****************************************************************************/
localparam DATA_WIDTH   = 7       ;
localparam PARITY_CHECK = "EVEN"  ;
localparam BAUD_RATE_TX    = 625 ;
localparam BAUD_RATE_RX    = 625 ;
localparam CLK_PERIOD      = 100;
localparam CLK_PERIOD_DEV  = 6;//+-3%
// top signal
bit				  clk     ;
bit               rst     ;
logic clk_tx;
logic clk_rx;
logic [10:0] clk_tx_cnt;
logic [10:0] clk_rx_cnt;
logic [10:0] clk_rx_dev;
always #5 clk = ~clk;

//tx signal
logic                        tx      ;
logic                        tx_rdy  ;
logic                        tx_vld  ;
bit    [DATA_WIDTH-1 : 0]    tx_data ;

//rx signal
wire                          rx_vld     ;
wire    [DATA_WIDTH-1 : 0]    rx_data    ;
wire                          rx_pc_pass ;
logic [DATA_WIDTH-1:0] tx_data_w1;

/*****************************************************************************
*                                  testing                                  *
*****************************************************************************/
bit    [DATA_WIDTH   : 0]    temp ;
bit    [DATA_WIDTH-1 : 0]    q[$] ;
always @ (posedge clk_tx) begin
	tx_vld <= rst ? '0 : 1;
    if (rst)
        clk_rx_dev <= CLK_PERIOD_DEV/2;
    temp = $urandom();
    if (tx_rdy&&tx_vld) begin
        q.push_back(temp[DATA_WIDTH-1:0]);
        tx_data <= temp[DATA_WIDTH-1:0];
        tx_data_w1 <= tx_data;
    end 
        
    if(rx_vld) begin
        clk_rx_dev <= $urandom() % CLK_PERIOD_DEV;
        assert(tx_data_w1 == rx_data)
        else $fatal(1, "wrong: %x - %x ", tx_data_w1, rx_data);
    end
end

assign clk_tx = (clk_tx_cnt < CLK_PERIOD/2) ? 1 : 0;
assign clk_rx = (clk_rx_cnt < (CLK_PERIOD/2-CLK_PERIOD_DEV/2 + clk_rx_dev)) ? 1 : 0;

always @(posedge clk) begin
    clk_tx_cnt <= (rst)? '0 : (clk_tx_cnt< CLK_PERIOD ) ? clk_tx_cnt + 1 : '0;
    clk_rx_cnt <= (rst)? '0 : (clk_rx_cnt < CLK_PERIOD-CLK_PERIOD_DEV +clk_rx_dev ) ? clk_rx_cnt + 1 : '0;
end


/*****************************************************************************
*                                 instance                                  *
*****************************************************************************/

uart_tx#(
    .DATA_WIDTH   ( DATA_WIDTH   ) ,
    .PARITY_CHECK ( PARITY_CHECK ) ,
    .CLK_FREQ     ( 100000    ) ,
    .STOP_BITS    (2),
    .BAUD_RATE    ( BAUD_RATE_TX    )
)transmitter(
    .clk    ( clk_tx       ),
    .rst    ( rst       ),
    
    .i_vld  ( tx_vld    ),
    .i_data ( tx_data   ),
    
    .o_rdy  ( tx_rdy    ),
    .tx     ( tx        )
);

uart_rx#(
    .DATA_WIDTH   ( DATA_WIDTH   ) ,
    .PARITY_CHECK ( PARITY_CHECK ) ,
    .CLK_FREQ     (100000    ) ,
    .BAUD_RATE    ( BAUD_RATE_RX    )
)receiver(
    .clk     ( clk_rx        ),
    .rst     ( rst        ),
    
    .rx      ( tx         ),
    .i_rdy   ( 1'b1       ),
    
    .o_vld   ( rx_vld     ),
    .pc_pass ( rx_pc_pass ),
    .o_data  ( rx_data    )
) ;
initial begin
	q.push_back(0);
    rst = 1;
    #20000
    rst = 0;
end

endmodule

