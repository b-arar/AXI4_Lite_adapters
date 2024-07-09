
`timescale 1ns/1ps

interface AXI4_Lite (
	input	logic			ACLK_i,
	input	logic			ARESETN_i
);
	logic	[31:0]	ARADDR;
	logic			ARVALID;
	logic			ARREADY;
	logic	[31:0]	RDATA;
	logic			RVALID;
	logic			RREADY;
	logic	[1:0]	RRESP;
	logic	[31:0]	AWADDR;
	logic			AWVALID;
	logic			AWREADY;
	logic	[31:0]	WDATA;
	logic			WVALID;
	logic			WREADY;
	logic	[3:0]	WSTRB;
	logic			BREADY;
	logic	[1:0]	BRESP;
	logic			BVALID;

	clocking mcb @(posedge ACLK_i);
		default input #1step output #1ns;
		input	ARESETN_i;
		output	ARADDR;
		output	ARVALID;
		input	ARREADY;
		input	RDATA;
		input	RVALID;
		output	RREADY;
		input	RRESP;
		output	AWADDR;
		output	AWVALID;
		input	AWREADY;
		output	WDATA;
		output	WVALID;
		input	WREADY;
		output	WSTRB;
		output	BREADY;
		input	BRESP;
		input	BVALID;
	endclocking : mcb


	clocking scb @(posedge ACLK_i);
		default input #1step output #1ns;
		input	ARESETN_i;
		input	ARADDR;
		input	ARVALID;
		output	ARREADY;
		output	RDATA;
		output	RVALID;
		input	RREADY;
		output	RRESP;
		input	AWADDR;
		input	AWVALID;
		output	AWREADY;
		input	WDATA;
		input	WVALID;
		output	WREADY;
		input	WSTRB;
		input	BREADY;
		output	BRESP;
		output	BVALID;
	endclocking : scb

	modport master_sp (clocking mcb);

	modport slave_sp (clocking scb);

	modport master (
		input	ACLK_i,
		input	ARESETN_i,
		output	.ARADDR_o(ARADDR),
		output	.ARVALID_o(ARVALID),
		input	.ARREADY_i(ARREADY),
		input	.RDATA_i(RDATA),
		input	.RVALID_i(RVALID),
		output	.RREADY_o(RREADY),
		input	.RRESP_i(RRESP),
		output	.AWADDR_o(AWADDR),
		output	.AWVALID_o(AWVALID),
		input	.AWREADY_i(AWREADY),
		output	.WDATA_o(WDATA),
		output	.WVALID_o(WVALID),
		input	.WREADY_i(WREADY),
		output	.WSTRB_o(WSTRB),
		output	.BREADY_o(BREADY),
		input	.BRESP_i(BRESP),
		input	.BVALID_i(BVALID)
	);

	modport slave (
		input	ACLK_i,
		input	ARESETN_i,
		input	.ARADDR_i(ARADDR),
		input	.ARVALID_i(ARVALID),
		output	.ARREADY_o(ARREADY),
		output	.RDATA_o(RDATA),
		output	.RVALID_o(RVALID),
		input	.RREADY_i(RREADY),
		output	.RRESP_o(RRESP),
		input	.AWADDR_i(AWADDR),
		input	.AWVALID_i(AWVALID),
		output	.AWREADY_o(AWREADY),
		input	.WDATA_i(WDATA),
		input	.WVALID_i(WVALID),
		output	.WREADY_o(WREADY),
		input	.WSTRB_i(WSTRB),
		input	.BREADY_i(BREADY),
		output	.BRESP_o(BRESP),
		output	.BVALID_o(BVALID)
	);
endinterface : AXI4_Lite
