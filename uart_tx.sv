module uart_tx#(
	parameter DATA_WIDTH   = 8        ,
	parameter PARITY_CHECK = "NONE"   ,
	parameter CLK_FREQ     = 50000000 ,
	parameter STOP_BITS = 1,
	parameter BAUD_RATE    = 9600
)(
     input   logic                    clk    ,
     input   logic                    rst    ,

     input   logic                    i_vld  ,
     input   logic [DATA_WIDTH-1 : 0] i_data ,

    output    logic                   o_rdy  ,
    output    logic                   tx
) ;
/*****************************************************************************
*                             check parameter                               *
*****************************************************************************/

initial begin
	assert(PARITY_CHECK == "NONE" || PARITY_CHECK == "ODD" || PARITY_CHECK == "EVEN") else
	$fatal(1,"Input error in parity check method");

	assert(CLK_PER_BIT >= 16) else
	$fatal(1,"the CLK_FREQ must be 16 times larger than BAUD_RATE");

	assert(DATA_WIDTH >= 2)	else
	$fatal(1,"The bit width of the data must be reasonable.");

	assert(DATA_WIDTH <= 8)	else
	$warning("The bit width of the data seems too long.");

	assert(STOP_BITS >= 1)	else
	$fatal(1,"Too few Stop Bits");

	assert(STOP_BITS <= 2) else
	$fatal(1, "Too many stop Bits");
end

localparam CLK_PER_BIT	 = CLK_FREQ/BAUD_RATE;
localparam CLK_PER_BIT_W = $clog2(CLK_PER_BIT);

/*****************************************************************************
*                                 variable                                  *
*****************************************************************************/
// data for output
logic    [DATA_WIDTH+STOP_BITS : 0]      non_pc_data  ;
logic    [DATA_WIDTH+STOP_BITS+1 : 0]    odd_pc_data  ;
logic    [DATA_WIDTH+STOP_BITS+1 : 0]    even_pc_data ;

// counters
logic    [CLK_PER_BIT_W-1 : 0]   						 signal_bit_cnter;
logic    [$clog2(DATA_WIDTH+STOP_BITS+1)-1     : 0]    non_pc_data_cnter ;
logic    [$clog2(DATA_WIDTH+STOP_BITS+2)-1     : 0]    pc_data_cnter     ;

//fsm
logic    tx_fsm ; // fsm == 0 represent idle, fsm == 1 represent sending

/*****************************************************************************
*                                  TX_FSM                                   *
*****************************************************************************/

assign o_rdy = ~tx_fsm;
always_ff @(posedge clk) begin
	if (rst)
		tx_fsm <= 0 ;
	else if (o_rdy&&i_vld)
		tx_fsm <= 1 ;
	else if (tx_fsm == 1)
		case(PARITY_CHECK)
			"NONE"  : tx_fsm <= !((non_pc_data_cnter == DATA_WIDTH+STOP_BITS) && (signal_bit_cnter == 0));
			default : tx_fsm <= !((pc_data_cnter     == DATA_WIDTH+STOP_BITS+1) && (signal_bit_cnter == 0));
		endcase
end

/*****************************************************************************
*                            buffer the i_data                              *
*****************************************************************************/

always_ff @(posedge clk)
	if (rst) begin
		non_pc_data  <= '1 ;
		odd_pc_data  <= '1 ;
		even_pc_data <= '1 ;
	end else if (o_rdy&&i_vld) begin
		non_pc_data  <= { {(STOP_BITS){1'b1}}             ,i_data ,1'b0 } ;
		odd_pc_data  <= { {(STOP_BITS){1'b1}}, !(^i_data) ,i_data ,1'b0 } ;
		even_pc_data <= { {(STOP_BITS){1'b1}}, ^i_data    ,i_data ,1'b0 } ;
	end else if (signal_bit_cnter == 0) begin
		odd_pc_data  <= {{(STOP_BITS){1'b1}}, odd_pc_data[DATA_WIDTH+2  : 1] } ;
		even_pc_data <= {{(STOP_BITS){1'b1}}, even_pc_data[DATA_WIDTH+2 : 1] } ;
		non_pc_data  <= {{(STOP_BITS){1'b1}}, non_pc_data[DATA_WIDTH+1  : 1] } ;
	end


/*****************************************************************************
*                          counter start and stop                           *
*****************************************************************************/
always_ff @(posedge clk) begin
	if (rst)
		signal_bit_cnter <= (CLK_PER_BIT_W)'(CLK_PER_BIT-1);
	else if (tx_fsm)
		signal_bit_cnter <= signal_bit_cnter == 0 ? (CLK_PER_BIT_W)'(CLK_PER_BIT): (CLK_PER_BIT_W)'(signal_bit_cnter - (CLK_PER_BIT_W)'(1'd1));
	else if (!tx_fsm)
		signal_bit_cnter <= (CLK_PER_BIT_W)'(CLK_PER_BIT-1);

	if (rst) begin
		non_pc_data_cnter <= 0;
		pc_data_cnter <= 0;
	end else if (tx_fsm) begin
		non_pc_data_cnter <= signal_bit_cnter == 0 ? non_pc_data_cnter + 1 : non_pc_data_cnter;
		pc_data_cnter <= signal_bit_cnter == 0 ? pc_data_cnter + 1 : pc_data_cnter;
	end else if (!tx_fsm) begin
		non_pc_data_cnter <= 0;
		pc_data_cnter <= 0;
	end
end

/*****************************************************************************
*                           shift data and output                           *
*****************************************************************************/
always_ff @(posedge clk) begin
	case (PARITY_CHECK)
		"NONE" : tx <= i_vld && o_rdy ? '0 : non_pc_data[0]  ;
		"ODD"  : tx <= i_vld && o_rdy ? '0 : odd_pc_data[0]  ;
		"EVEN" : tx <= i_vld && o_rdy ? '0 : even_pc_data[0] ;
	endcase
end

endmodule
