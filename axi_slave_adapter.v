`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/24/2023 02:25:33 PM
// Design Name: 
// Module Name: custom_axi
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module AXI_slave_v #(
    parameter   START_ADDR = 32'h4000_0000,
    parameter   END_ADDR = 32'h4000_4000 // non-inclusive
)(
   input        reset_i,

   // Adapter interface pins
   output reg              valid_o,
   input                   ready_i,
   output reg     [ 3:0]   wstrb_o,
   output reg     [31:0]   addr_o,
   output reg     [31:0]   wdata_o,
   input          [31:0]   rdata_i,
   output                  clk_o,
   
   // AXI4-Lite pins
   input                   S_AXI_ACLK,
   // -- Read address signals
   input          [31:0]   S_AXI_ARADDR,        
   input                   S_AXI_ARVALID,          
   output reg              S_AXI_ARREADY,

   // -- Read data signals
   output reg     [31:0]   S_AXI_RDATA,
   output reg              S_AXI_RVALID,
   input                   S_AXI_RREADY,        
   output reg     [ 1:0]   S_AXI_RRESP,

   // -- Write address signals
   input          [31:0]   S_AXI_AWADDR,        
   input                   S_AXI_AWVALID,       
   output reg              S_AXI_AWREADY,

   // -- Write data signals
   input          [31:0]   S_AXI_WDATA,      
   input                   S_AXI_WVALID,        
   output reg              S_AXI_WREADY,
   input          [ 3:0]   S_AXI_WSTRB,

   // -- Write response signals
   input                   S_AXI_BREADY,        
   output reg     [ 1:0]   S_AXI_BRESP,
   output reg              S_AXI_BVALID
);

/*
THIS MODULE MAINTAINS A STATE MACHINE:

S1 - Idle
S2 - Receive read address
S3 - Send read data
S4 - Receive write address and data
S5 - Send write response


*/

   reg [2:0] state;
   reg [1:0] write_status; // {data, address}

   localparam IDLE               = 3'b000;
   localparam READ_ADDR          = 3'b001;
   localparam READ_DATA          = 3'b010;
   localparam WRITE_ADDR_DATA    = 3'b011;
   localparam WRITE_RESP         = 3'b100;

   assign clk_o = S_AXI_ACLK;

   always @(posedge S_AXI_ACLK) begin
      if (reset_i == 1'b0) begin
         state <= IDLE;
         write_status <= 0;

         valid_o <= 0;
         wstrb_o <= 0;
         addr_o <= 0;
         wdata_o <= 0;

         S_AXI_ARREADY <= 0;

         S_AXI_RDATA <= 0;
         S_AXI_RVALID <= 0;
         S_AXI_RRESP <= 0;

         S_AXI_AWREADY <= 0;

         S_AXI_WREADY <= 0;

         S_AXI_BVALID <= 0;
      end else begin 
         case(state)
            IDLE: begin
               if (S_AXI_ARVALID == 1'b1) begin // if read initiated
                  if (S_AXI_ARADDR >= START_ADDR && S_AXI_ARADDR < END_ADDR) begin // if within mapped space
                     state <= READ_ADDR;
                  end else begin
                     state <= state;
                  end
               end else if (S_AXI_AWVALID == 1'b1) begin // if write initiated
                  if (S_AXI_AWADDR >= START_ADDR && S_AXI_AWADDR < END_ADDR) begin // if within mapped space
                     state <= WRITE_ADDR_DATA;
                  end else begin
                     state <= state;
                  end
               end else begin // if neither initiated
                  state <= state;
               end
            end
            READ_ADDR: begin // read address transaction
               if (S_AXI_ARREADY == 1'b1) begin // if address transaction complete
                  S_AXI_ARREADY <= 0;
                  state <= READ_DATA;
                  addr_o <= S_AXI_ARADDR;
                  valid_o <= 1'b1;
               end else begin
                  S_AXI_ARREADY <= 1'b1;
                  state <= state;
                  addr_o <= addr_o;
                  valid_o <= valid_o;
               end
            end
            READ_DATA: begin // send read data
               if (S_AXI_RVALID == 1'b1) begin // if AXI transaction begun
                  if (S_AXI_RREADY == 1'b1) begin // if AXI transaction complete
                     state <= IDLE;
                     S_AXI_RDATA <= 0;
                     S_AXI_RVALID <= 0;
                     addr_o <= addr_o;
                     valid_o <= valid_o;
                  end else begin
                     state <= state;
                     S_AXI_RDATA <= S_AXI_RDATA;
                     S_AXI_RVALID <= S_AXI_RVALID;
                     addr_o <= addr_o;
                     valid_o <= valid_o;
                  end
               
               end else begin
                  if (ready_i == 1'b1) begin // if memory read op complete
                     state <= state;
                     S_AXI_RDATA <= rdata_i;
                     S_AXI_RVALID <= 1'b1;
                     addr_o <= 0;
                     valid_o <= 0;
                  end else begin
                     state <= state;
                     S_AXI_RDATA <= S_AXI_RDATA;
                     S_AXI_RVALID <= S_AXI_RVALID;
                     addr_o <= addr_o;
                     valid_o <= valid_o;
                  end
               end
            end
            WRITE_ADDR_DATA: begin
               // The two buses must run in parallel and independently of each other, but
               // since we won't move to WRITE_RESP state until both operations are resolved,
               // they share this state.

               if (
                  (write_status[0] == 1'b1) &&
                  (write_status[1] == 1'b1)
               ) begin // if both ops complete, either both this cycle or one of them at a previous cycle
                  state <= WRITE_RESP;
                  write_status <= 0;
                  valid_o <= 1;
                  addr_o <= addr_o;
                  wstrb_o <= wstrb_o;
                  wdata_o <= wdata_o;
                  S_AXI_AWREADY <= 0;
                  S_AXI_WREADY <= 0;
               end else begin
                  state <= state;
                  valid_o <= 0;
                  if (S_AXI_AWREADY == 1'b1) begin
                     write_status[0] <= 1'b1;
                     addr_o <= S_AXI_AWADDR;
                     S_AXI_AWREADY <= 0;
                  end else begin
                     if (write_status[0] == 1'b1) begin
                        write_status[0] <= write_status[0];
                        addr_o <= addr_o;
                        S_AXI_AWREADY <= S_AXI_AWREADY;
                     end else begin
                        write_status[0] <= write_status[0];
                        addr_o <= addr_o;
                        S_AXI_AWREADY <= 1'b1;
                     end
                  end

                  if (S_AXI_WREADY == 1'b1) begin
                     write_status[1] <= 1'b1;
                     wdata_o <= S_AXI_WDATA;
                     wstrb_o <= S_AXI_WSTRB;
                     S_AXI_WREADY <= 0;
                  end else begin
                     if (write_status[1] == 1'b1) begin
                        write_status[1] <= write_status[1];
                        wdata_o <= wdata_o;
                        wstrb_o <= wstrb_o;
                        S_AXI_WREADY <= S_AXI_WREADY;
                     end else begin
                        write_status[1] <= write_status[1];
                        wdata_o <= wdata_o;
                        wstrb_o <= wstrb_o;
                        S_AXI_WREADY <= 1'b1;
                     end
                  end
               
               end

               
            end
            WRITE_RESP: begin
               if (S_AXI_BVALID == 1'b1) begin // if AXI transaction begun
                  if (S_AXI_BREADY == 1'b1) begin
                     state <= IDLE;
                     S_AXI_BRESP <= 0;
                     S_AXI_BVALID <= 0;
                     valid_o <= valid_o;
                     addr_o <= addr_o;
                     wstrb_o <= wstrb_o;
                     wdata_o <= wdata_o;
                  end else begin
                     state <= state;
                     S_AXI_BVALID <= S_AXI_BVALID;
                     S_AXI_BRESP <= S_AXI_BRESP;
                     valid_o <= valid_o;
                     addr_o <= addr_o;
                     wstrb_o <= wstrb_o;
                     wdata_o <= wdata_o;
                  end
               end else begin
                  state <= state;
                  if (ready_i == 1'b1) begin
                     S_AXI_BVALID <= 1'b1;
                     S_AXI_BRESP <= 2'b00;
                     valid_o <= 0;
                     addr_o <= 0;
                     wstrb_o <= 0;
                     wdata_o <= 0;
                  end else begin
                     S_AXI_BVALID <= S_AXI_BVALID;
                     S_AXI_BRESP <= S_AXI_BRESP;
                     valid_o <= valid_o;
                     addr_o <= addr_o;
                     wstrb_o <= wstrb_o;
                     wdata_o <= wdata_o;
                  end
               end
            end
            default: begin // If unasigned state, reset everything
               state <= IDLE;
               write_status <= 0;

               valid_o <= 0;
               wstrb_o <= 0;
               addr_o <= 0;
               wdata_o <= 0;

               S_AXI_ARREADY <= 0;

               S_AXI_RDATA <= 0;
               S_AXI_RVALID <= 0;
               S_AXI_RRESP <= 0;

               S_AXI_AWREADY <= 0;

               S_AXI_WREADY <= 0;

               S_AXI_BVALID <= 0;
            end
         endcase
      end
   end


endmodule