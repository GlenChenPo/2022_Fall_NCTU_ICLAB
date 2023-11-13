`ifdef RTL
	`timescale 1ns/1ps
	`define CYCLE_TIME_clk1 10
	`define CYCLE_TIME_clk2 15
`endif
`ifdef GATE
	`timescale 1ns/1ps
	`define CYCLE_TIME_clk1 10
	`define CYCLE_TIME_clk2 15
`endif


module PATTERN #(parameter DSIZE = 8,
			   parameter ASIZE = 4)(
	//Output Port
	rst_n,
	clk1,
    clk2,
	in_valid,
	in_account,
	in_A,
	in_T,

    //Input Port
	ready,
    out_valid,
	out_account
); 
//================================================================
//   INPUT AND OUTPUT DECLARATION                         
//================================================================
output reg				rst_n, clk1, clk2, in_valid;
output reg [DSIZE-1:0] 	in_account,in_A,in_T;

input 				ready, out_valid;
input [DSIZE-1:0] 	out_account;

//================================================================
// parameters & integer
//================================================================

integer 	gap;
integer 	i,j,k;
integer 	cycles; 
integer 	seed = 30;
parameter	PAT_NUM = 500;
integer 	pat_cnt;

reg [DSIZE-1:0]		account_data[0:3999];
reg [DSIZE-1:0]		A_data[0:3999];
reg [DSIZE-1:0]		T_data[0:3999];
reg	[DSIZE*2-1:0]	cost[0:3999];
reg [DSIZE-1:0]		exp_acc[0:3995];

reg [11:0]			in_cnt;
reg [11:0]			out_cnt;
reg					waiting;
reg [8:0]			wait_total_cnt;		// up to 500
reg [7:0]			wait_current;		// up to 150
reg [7:0]			wait_current_cnt;
reg					start_latency_cnt;

//================================================================
// clock
//================================================================

always	#(`CYCLE_TIME_clk1/2.0) clk1 = ~clk1;
initial	clk1 = 0;

always	#(`CYCLE_TIME_clk2/2.0) clk2 = ~clk2;
initial	clk2 = 0;

//================================================================
// initial
//================================================================

initial begin
	rst_n		= 'd1;
	in_valid	= 'd0;
	in_account	= 'dx;
	in_A		= 'dx;
	in_T		= 'dx;
	
	reset_task;
	data_gen_task;
	
	fork 
		input_task;
		check_ans_task;
	join
	
	end_task;
	
	#(100)
	$finish;
end 

//================================================================
// task
//================================================================

task reset_task; begin

	force clk1 = 0;
	force clk2 = 0;
	rst_n      = 1;

	#(100) rst_n = 0;
	#(100) rst_n = 1;
	if ( out_valid !== 0 || ready !== 0 || out_account !== 0 ) begin
		$display ("***********************************");
		$display ("**        RESET FAILED           **");
		$display ("***********************************");
		#(100);
		$finish ;
	end
	release clk1; release clk2;

end endtask

task data_gen_task; begin
	
	for ( i=0; i<4000; i=i+1 ) begin
		account_data[i]		= $random(seed);
		A_data[i]			= $random(seed);
		T_data[i]			= $random(seed);
		cost[i]				= A_data[i]*T_data[i];
	end
	
	for ( i=0; i<3996; i=i+1 ) begin
		if ( cost[i+4] <= cost[i+3] && cost[i+4] <= cost[i+2] && cost[i+4] <= cost[i+1] && cost[i+4] <= cost[i] )
			exp_acc[i]		= account_data[i+4];
		else if ( cost[i+3] <= cost[i+2] && cost[i+3] <= cost[i+1] && cost[i+3] <= cost[i] )
			exp_acc[i]		= account_data[i+3];
		else if ( cost[i+2] <= cost[i+1] && cost[i+2] <= cost[i] )
			exp_acc[i]		= account_data[i+2];
		else if ( cost[i+1] <= cost[i] )
			exp_acc[i]		= account_data[i+1];
		else
			exp_acc[i]		= account_data[i];
	end

end endtask

task input_task; begin
	
	wait_total_cnt 	= 0;
	in_cnt		   	= 0;
	
	while ( in_cnt != 4000 ) begin
		waiting 			= 0;
		wait_current_cnt	= 0;
		if ( ready == 0 )
			begin
				in_valid	= 'd0;
				in_account	= 'dx;
				in_A		= 'dx;
				in_T		= 'dx;
			end
		else
			begin
				if ( waiting == 0 )
					begin
					//	if ( wait_total_cnt > 350 )
					//		wait_current	= $urandom_range(0,500 - wait_total_cnt);
					//	else
					//		wait_current	= $urandom_range(0,150);
						wait_current= 0;
						waiting 	= 1;
					end
				 
				while ( wait_current_cnt != wait_current ) begin
					in_valid	= 'd0;
					in_account	= 'dx;
					in_A		= 'dx;
					in_T		= 'dx;				
					wait_current_cnt	= wait_current_cnt + 1;
					@(negedge clk1);
				end

				in_valid	= 'd1;
				in_account	= account_data[in_cnt];
				in_A		= A_data[in_cnt];
				in_T		= T_data[in_cnt];
				in_cnt		= in_cnt + 1;
				wait_total_cnt	= wait_total_cnt + wait_current_cnt;
				if ( in_cnt == 0 )
					start_latency_cnt	= 1;
			end
		@(negedge clk1);
	end
end endtask

task check_ans_task; begin
	
	out_cnt		= 0;
	cycles		= 0;
	start_latency_cnt	= 0;

	while ( out_cnt != 3996 ) begin
	
		@(negedge clk2);
	
		if ( start_latency_cnt == 1 ) begin
			cycles	= cycles + 1;
			if ( cycles == 100000 ) begin
				$display ("***********************************");
				$display ("**    Latency is over 100,000    **");
				$display ("***********************************");
				#(100);
				$finish ;
			end				
		end	
		
		if ( out_valid == 1 ) begin
			if ( out_account !== exp_acc[out_cnt] ) begin
				$display ("***********************************");
				$display ("**        Mismatched Output      **");
				$display ("** Data No.: %d                  **",out_cnt);
				$display ("** Expected: %d					**",exp_acc[out_cnt]);
				$display ("** Output  : %d					**",out_account);
				$display ("***********************************");
				#(100);
				$finish ;
			end
			out_cnt	= out_cnt + 1;
		end
	end

end endtask

task end_task; begin
	
	$display ("***********************************");
	$display ("              Pass				  ");
	$display ("***********************************");
	
end endtask

endmodule 