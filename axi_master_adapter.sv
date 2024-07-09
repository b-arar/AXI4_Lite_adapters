
`timescale 1ns/1ps

module AXI_master_adapter(
   AXI4_Lite.master AXI,
   simple_memory.slave mem
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


   assign AXI.ACLK_o = mem.clk_i;
   assign AXI.ARESETN_o = mem.resetn_i;

   always @(posedge mem.clk_i) begin
      if (mem.resetn_i == 1'b0) begin
         state <= IDLE;
         write_status <= 0;
         mem.ready_o <= 0;
         mem.rdata_o <= 0;
         AXI.ARADDR_o <= 0;
         AXI.ARVALID_o <= 0;
         AXI.RREADY_o <= 0;
         AXI.AWADDR_o <= 0;
         AXI.AWVALID_o <= 0;
         AXI.WDATA_o <= 0;
         AXI.WVALID_o <= 0;
         AXI.WSTRB_o <= 0;
         AXI.BREADY_o <= 0;
      end else begin 
         case(state)
            IDLE: begin
               if (mem.valid_i) begin
                  if (mem.wstrb_i == 4'b0000) begin
                     state <= READ_ADDR;
                  end else begin
                     state <= WRITE_ADDR_DATA;
                  end
               end else begin
                  state <= state;
               end
            end
            READ_ADDR: begin
               if (AXI.ARVALID_o == 1'b1) begin // If operation already started
                  if (AXI.ARREADY_i == 1'b1) begin // If response received
                     state <= READ_DATA; // switch to receiving read data
                     AXI.ARADDR_o <= 0;
                     AXI.ARVALID_o <= 0;
                  end else begin // continue to wait
                     state <= state;
                     AXI.ARADDR_o <= AXI.ARADDR_o;
                     AXI.ARVALID_o <= AXI.ARVALID_o;
                  end
               end else begin // start operation
                  state <= state;
                  AXI.ARADDR_o <= mem.addr_i;
                  AXI.ARVALID_o <= 1'b1;
               end
            end
            READ_DATA: begin
               if (AXI.RVALID_i == 1'b1) begin // If read response received
                  if (mem.ready_o == 1'b1) begin // If data delivery to memory interface initiated
                     state <= IDLE;
                     mem.rdata_o <= 32'b0;
                     mem.ready_o <= 0;
                     AXI.RREADY_o <= 0;
                  end else begin
                     state <= state;
                     mem.rdata_o <= AXI.RDATA_i;
                     mem.ready_o <= 1'b1;
                     AXI.RREADY_o <= 1'b1;
                  end
               end else begin // if not received yet
                  state <= state;
                  mem.ready_o <= 0;
                  mem.rdata_o <= 0;
                  AXI.RREADY_o <= 0;
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
                  AXI.AWADDR_o <= 0;
                  AXI.AWVALID_o <= 0;
                  AXI.WDATA_o <= 0;
                  AXI.WVALID_o <= 0;
                  AXI.WSTRB_o <= 0;
               end else begin // if either one not complete
                  if (AXI.AWVALID_o == 1'b1) begin // if address write initiated and not done yet
                     AXI.AWADDR_o <= AXI.AWADDR_o; // always preserve state of address except during setup
                     if (AXI.AWREADY_i == 1'b1) begin // if ready signal received this cycle
                        write_status[0] <= 1'b1; // information is saved
                        AXI.AWVALID_o <= 0; // must set to 0 according to protocol.
                     end else begin // if ready not received this cycle, preserve state
                        write_status[0] <= write_status[0];
                        AXI.AWVALID_o <= AXI.AWVALID_o;
                     end
                  end else begin
                     AXI.AWADDR_o <= mem.addr_i;
                     AXI.AWVALID_o <= 1'b1;
                     if (write_status[0] == 1'b0) begin
                        AXI.WVALID_o <= 1'b1;
                     end else begin
                        AXI.WVALID_o <= AXI.WVALID_o;
                     end
                  end

                  if (AXI.WVALID_o == 1'b1) begin // if data write initiated and not done yet
                     AXI.WDATA_o <= AXI.WDATA_o; // always preserve state except during setup
                     AXI.WSTRB_o <= AXI.WSTRB_o;
                     if (AXI.WREADY_i == 1'b1) begin // if ready signal received this cycle
                        write_status[1] <= 1'b1; // information is saved
                        AXI.WVALID_o <= 0; // must set to 0 according to protocol.
                     end else begin // if ready not received this cycle, preserve state
                        write_status[1] <= write_status[1];
                        AXI.WVALID_o <= AXI.WVALID_o;
                     end
                  end else begin
                     AXI.WDATA_o <= mem.wdata_i;
                     AXI.WSTRB_o <= mem.wstrb_i;
                     if (write_status[1] == 1'b0) begin
                        AXI.WVALID_o <= 1'b1;
                     end else begin
                        AXI.WVALID_o <= AXI.WVALID_o;
                     end
                  end
                  state <= state;
               end
            end
            WRITE_RESP: begin
               if (AXI.BVALID_i == 1'b1) begin // if response received
                  // add logic to handle miswrites here
                  if (AXI.BREADY_o == 1'b1) begin // if ready signal sent
                     AXI.BREADY_o <= 0;
                     mem.ready_o <= 0;
                     state <= IDLE;
                  end else begin
                     AXI.BREADY_o <= 1'b1;
                     mem.ready_o <= 1'b1;
                     state <= state;
                  end
               end else begin // wait for response
                  state <= state;
                  mem.ready_o <= mem.ready_o;
                  AXI.BREADY_o <= AXI.BREADY_o;
               end
            end
            default: begin // If unasigned state, reset everything
               state <= IDLE;
               write_status <= 0;
               mem.ready_o <= 0;
               mem.rdata_o <= 0;
               AXI.ARADDR_o <= 0;
               AXI.ARVALID_o <= 0;
               AXI.RREADY_o <= 0;
               AXI.AWADDR_o <= 0;
               AXI.AWVALID_o <= 0;
               AXI.WDATA_o <= 0;
               AXI.WVALID_o <= 0;
               AXI.WSTRB_o <= 0;
               AXI.BREADY_o <= 0;
            end
         endcase
      end
   end


endmodule