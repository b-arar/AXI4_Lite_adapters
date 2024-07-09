
`timescale 1ns/1ps

module AXI_master_v(
   input             clk_i,
   input             resetn_i,

   // Adapter interface pins
   input                   valid_i,
   output   reg            ready_o,       
   input          [ 3:0]   wstrb_i,
   input          [31:0]   addr_i,
   input          [31:0]   wdata_i,
   output   reg   [31:0]   rdata_o,          

   // AXI4-Lite pins
   // -- Read address signals
   output   reg   [31:0]   AXI_ARADDR_o,        
   output   reg            AXI_ARVALID_o,          
   input                   AXI_ARREADY_i,

   // -- Read data signals
   input          [31:0]   AXI_RDATA_i,
   input                   AXI_RVALID_i,
   output   reg            AXI_RREADY_o,        
   input          [ 1:0]   AXI_RRESP_i,

   // -- Write address signals
   output   reg   [31:0]   AXI_AWADDR_o,        
   output   reg            AXI_AWVALID_o,       
   input                   AXI_AWREADY_i,

   // -- Write data signals
   output   reg   [31:0]   AXI_WDATA_o,      
   output   reg            AXI_WVALID_o,        
   input                   AXI_WREADY_i,
   output   reg   [ 3:0]   AXI_WSTRB_o,

   // -- Write response signals
   output   reg            AXI_BREADY_o,        
   input          [ 1:0]   AXI_BRESP_i,
   input                   AXI_BVALID_i
);

/*
THIS MODULE MAINTAINS A STATE MACHINE:

S1 - Idle
S2 - Send read address
S3 - Receive read data
S4 - Send write address and data
S5 - 


*/

   reg [2:0] state;
   reg [1:0] write_status; // {data, address}

   localparam IDLE               = 3'b000;
   localparam READ_ADDR          = 3'b001;
   localparam READ_DATA          = 3'b010;
   localparam WRITE_ADDR_DATA    = 3'b011;
   localparam WRITE_RESP         = 3'b100;



   always @(posedge clk_i) begin
      if (resetn_i == 1'b0) begin
         state <= IDLE;
         write_status <= 0;
         ready_o <= 0;
         rdata_o <= 0;
         AXI_ARADDR_o <= 0;
         AXI_ARVALID_o <= 0;
         AXI_RREADY_o <= 0;
         AXI_AWADDR_o <= 0;
         AXI_AWVALID_o <= 0;
         AXI_WDATA_o <= 0;
         AXI_WVALID_o <= 0;
         AXI_WSTRB_o <= 0;
         AXI_BREADY_o <= 0;
      end else begin 
         case(state)
            IDLE: begin
               if (valid_i) begin
                  if (wstrb_i == 4'b0000) begin
                     state <= READ_ADDR;
                  end else begin
                     state <= WRITE_ADDR_DATA;
                  end
               end else begin
                  state <= state;
               end
            end
            READ_ADDR: begin
               if (AXI_ARVALID_o == 1'b1) begin // If operation already started
                  if (AXI_ARREADY_i == 1'b1) begin // If response received
                     state <= READ_DATA; // switch to receiving read data
                     AXI_ARADDR_o <= 0;
                     AXI_ARVALID_o <= 0;
                  end else begin // continue to wait
                     state <= state;
                     AXI_ARADDR_o <= AXI_ARADDR_o;
                     AXI_ARVALID_o <= AXI_ARVALID_o;
                  end
               end else begin // start operation
                  state <= state;
                  AXI_ARADDR_o <= addr_i;
                  AXI_ARVALID_o <= 1'b1;
               end
            end
            READ_DATA: begin
               if (AXI_RVALID_i == 1'b1) begin // If read response received
                  if (ready_o == 1'b1) begin // If data delivery to memory interface initiated
                     state <= IDLE;
                     rdata_o <= 32'b0;
                     ready_o <= 0;
                     AXI_RREADY_o <= 0;
                  end else begin
                     state <= state;
                     rdata_o <= AXI_RDATA_i;
                     ready_o <= 1'b1;
                     AXI_RREADY_o <= 1'b1;
                  end
               end else begin // if not received yet
                  state <= state;
                  ready_o <= 0;
                  rdata_o <= 0;
                  AXI_RREADY_o <= 0;
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
                  write_status <= 2'b00;
                  AXI_AWADDR_o <= 0;
                  AXI_AWVALID_o <= 0;
                  AXI_WDATA_o <= 0;
                  AXI_WVALID_o <= 0;
                  AXI_WSTRB_o <= 0;
               end else begin // if either one not complete
                  if (AXI_AWVALID_o == 1'b1) begin // if address write initiated and not done yet
                     AXI_AWADDR_o <= AXI_AWADDR_o; // always preserve state of address except during setup
                     if (AXI_AWREADY_i == 1'b1) begin // if ready signal received this cycle
                        write_status[0] <= 1'b1; // information is saved
                        AXI_AWVALID_o <= 0; // must set to 0 according to protocol.
                     end else begin // if ready not received this cycle, preserve state
                        write_status[0] <= write_status[0];
                        AXI_AWVALID_o <= AXI_AWVALID_o;
                     end
                  end else begin
                     AXI_AWADDR_o <= addr_i;
                     AXI_AWVALID_o <= 1'b1;
                     if (write_status[0] == 1'b0) begin
                        AXI_WVALID_o <= 1'b1;
                     end else begin
                        AXI_WVALID_o <= AXI_WVALID_o;
                     end
                  end

                  if (AXI_WVALID_o == 1'b1) begin // if data write initiated and not done yet
                     AXI_WDATA_o <= AXI_WDATA_o; // always preserve state except during setup
                     AXI_WSTRB_o <= AXI_WSTRB_o;
                     if (AXI_WREADY_i == 1'b1) begin // if ready signal received this cycle
                        write_status[1] <= 1'b1; // information is saved
                        AXI_WVALID_o <= 0; // must set to 0 according to protocol.
                     end else begin // if ready not received this cycle, preserve state
                        write_status[1] <= write_status[1];
                        AXI_WVALID_o <= AXI_WVALID_o;
                     end
                  end else begin
                     AXI_WDATA_o <= wdata_i;
                     AXI_WSTRB_o <= wstrb_i;
                     if (write_status[1] == 1'b0) begin
                        AXI_WVALID_o <= 1'b1;
                     end else begin
                        AXI_WVALID_o <= AXI_WVALID_o;
                     end
                  end
                  state <= state;
               end
            end
            WRITE_RESP: begin
               if (AXI_BVALID_i == 1'b1) begin // if response received
                  // add logic to handle miswrites here
                  if (AXI_BREADY_o == 1'b1) begin // if ready signal sent
                     AXI_BREADY_o <= 0;
                     ready_o <= 0;
                     state <= IDLE;
                  end else begin
                     AXI_BREADY_o <= 1'b1;
                     ready_o <= 1'b1;
                     state <= state;
                  end
               end else begin // wait for response
                  state <= state;
                  ready_o <= ready_o;
                  AXI_BREADY_o <= AXI_BREADY_o;
               end
            end
            default: begin // If unasigned state, reset everything
               state <= IDLE;
               write_status <= 0;
               ready_o <= 0;
               rdata_o <= 0;
               AXI_ARADDR_o <= 0;
               AXI_ARVALID_o <= 0;
               AXI_RREADY_o <= 0;
               AXI_AWADDR_o <= 0;
               AXI_AWVALID_o <= 0;
               AXI_WDATA_o <= 0;
               AXI_WVALID_o <= 0;
               AXI_WSTRB_o <= 0;
               AXI_BREADY_o <= 0;
            end
         endcase
      end
   end


endmodule