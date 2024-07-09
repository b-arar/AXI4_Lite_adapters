
`timescale 1ns/1ps

interface SimpleMemory (
	input	logic			clk_i,
	input	logic			resetn_i
);
	logic			valid;
	logic			ready;
	logic	[3:0]	wstrb;
	logic	[31:0]	addr;
	logic	[31:0]	wdata;
	logic	[31:0]	rdata;

	clocking mcb @(posedge clk_i);
		default input #1step output #1ns;
		input	resetn_i;
		output	valid;
		input	ready;
		output	wstrb;
		output	addr;
		output	wdata;
		input	rdata;
	endclocking : mcb


	clocking scb @(posedge clk_i);
		default input #1step output #1ns;
		input	resetn_i;
		input	valid;
		output	ready;
		input	wstrb;
		input	addr;
		input	wdata;
		output	rdata;
	endclocking : scb

	modport master_sp (clocking mcb);

	modport slave_sp (clocking scb);

	modport master (
		input	clk_i,
		input	resetn_i,
		output	.valid_o(valid),
		input	.ready_i(ready),
		output	.wstrb_o(wstrb),
		output	.addr_o(addr),
		output	.wdata_o(wdata),
		input	.rdata_i(rdata)
	);

	modport slave (
		input	clk_i,
		input	resetn_i,
		input	.valid_i(valid),
		output	.ready_o(ready),
		input	.wstrb_i(wstrb),
		input	.addr_i(addr),
		input	.wdata_i(wdata),
		output	.rdata_o(rdata)
	);
endinterface : SimpleMemory
