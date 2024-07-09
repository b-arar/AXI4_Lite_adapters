`timescale 1ns/1ps

module AXI_slave_adapter #(
    parameter   START_ADDR = 0,
    parameter   END_ADDR = 32'hFFFF_FFFF // non-inclusive
)(
   simple_memory.master mem,
   AXI4_Lite.slave AXI
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

   assign mem.clk_o = AXI.ACLK_i;
   assign mem.resetn_o = AXI.ARESETN_i;

   always @(posedge AXI.ACLK_i) begin
      if (AXI.ARESETN_i == 1'b0) begin
         state <= IDLE;
         write_status <= 0;

         mem.valid_o <= 0;
         mem.wstrb_o <= 0;
         mem.addr_o <= 0;
         mem.wdata_o <= 0;

         AXI.ARREADY_o <= 0;

         AXI.RDATA_o <= 0;
         AXI.RVALID_o <= 0;
         AXI.RRESP_o <= 0;

         AXI.AWREADY_o <= 0;

         AXI.WREADY_o <= 0;

         AXI.BVALID_o <= 0;
      end else begin 
         case(state)
            IDLE: begin
               if (AXI.ARVALID_i == 1'b1) begin // if read initiated
                  if (AXI.ARADDR_i >= START_ADDR && AXI.ARADDR_i < END_ADDR) begin // if within mapped space
                     state <= READ_ADDR;
                  end else begin
                     state <= state;
                  end
               end else if (AXI.AWVALID_i == 1'b1) begin // if write initiated
                  if (AXI.AWADDR_i >= START_ADDR && AXI.AWADDR_i < END_ADDR) begin // if within mapped space
                     state <= WRITE_ADDR_DATA;
                  end else begin
                     state <= state;
                  end
               end else begin // if neither initiated
                  state <= state;
               end
            end
            READ_ADDR: begin // read address transaction
               if (AXI.ARREADY_o == 1'b1) begin // if address transaction complete
                  AXI.ARREADY_o <= 0;
                  state <= READ_DATA;
                  mem.addr_o <= AXI.ARADDR_i;
                  mem.valid_o <= 1'b1;
               end else begin
                  AXI.ARREADY_o <= 1'b1;
                  state <= state;
                  mem.addr_o <= mem.addr_o;
                  mem.valid_o <= mem.valid_o;
               end
            end
            READ_DATA: begin // send read data
               if (AXI.RVALID_o == 1'b1) begin // if AXI transaction begun
                  if (AXI.RREADY_i == 1'b1) begin // if AXI transaction complete
                     state <= IDLE;
                     AXI.RDATA_o <= 0;
                     AXI.RVALID_o <= 0;
                     mem.addr_o <= mem.addr_o;
                     mem.valid_o <= mem.valid_o;
                  end else begin
                     state <= state;
                     AXI.RDATA_o <= AXI.RDATA_o;
                     AXI.RVALID_o <= AXI.RVALID_o;
                     mem.addr_o <= mem.addr_o;
                     mem.valid_o <= mem.valid_o;
                  end
               
               end else begin
                  if (mem.ready_i == 1'b1) begin // if memory read op complete
                     state <= state;
                     AXI.RDATA_o <= mem.rdata_i;
                     AXI.RVALID_o <= 1'b1;
                     mem.addr_o <= 0;
                     mem.valid_o <= 0;
                  end else begin
                     state <= state;
                     AXI.RDATA_o <= AXI.RDATA_o;
                     AXI.RVALID_o <= AXI.RVALID_o;
                     mem.addr_o <= mem.addr_o;
                     mem.valid_o <= mem.valid_o;
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
                  mem.valid_o <= 1;
                  mem.addr_o <= mem.addr_o;
                  mem.wstrb_o <= mem.wstrb_o;
                  mem.wdata_o <= mem.wdata_o;
                  AXI.AWREADY_o <= 0;
                  AXI.WREADY_o <= 0;
               end else begin
                  state <= state;
                  mem.valid_o <= 0;
                  if (AXI.AWREADY_o == 1'b1) begin
                     write_status[0] <= 1'b1;
                     mem.addr_o <= AXI.AWADDR_i;
                     AXI.AWREADY_o <= 0;
                  end else begin
                     if (write_status[0] == 1'b1) begin
                        write_status[0] <= write_status[0];
                        mem.addr_o <= mem.addr_o;
                        AXI.AWREADY_o <= AXI.AWREADY_o;
                     end else begin
                        write_status[0] <= write_status[0];
                        mem.addr_o <= mem.addr_o;
                        AXI.AWREADY_o <= 1'b1;
                     end
                  end

                  if (AXI.WREADY_o == 1'b1) begin
                     write_status[1] <= 1'b1;
                     mem.wdata_o <= AXI.WDATA_i;
                     mem.wstrb_o <= AXI.WSTRB_i;
                     AXI.WREADY_o <= 0;
                  end else begin
                     if (write_status[1] == 1'b1) begin
                        write_status[1] <= write_status[1];
                        mem.wdata_o <= mem.wdata_o;
                        mem.wstrb_o <= mem.wstrb_o;
                        AXI.WREADY_o <= AXI.WREADY_o;
                     end else begin
                        write_status[1] <= write_status[1];
                        mem.wdata_o <= mem.wdata_o;
                        mem.wstrb_o <= mem.wstrb_o;
                        AXI.WREADY_o <= 1'b1;
                     end
                  end
               
               end

               
            end
            WRITE_RESP: begin
               if (AXI.BVALID_o == 1'b1) begin // if AXI transaction begun
                  if (AXI.BREADY_i == 1'b1) begin
                     state <= IDLE;
                     AXI.BRESP_o <= 0;
                     AXI.BVALID_o <= 0;
                     mem.valid_o <= mem.valid_o;
                     mem.addr_o <= mem.addr_o;
                     mem.wstrb_o <= mem.wstrb_o;
                     mem.wdata_o <= mem.wdata_o;
                  end else begin
                     state <= state;
                     AXI.BVALID_o <= AXI.BVALID_o;
                     AXI.BRESP_o <= AXI.BRESP_o;
                     mem.valid_o <= mem.valid_o;
                     mem.addr_o <= mem.addr_o;
                     mem.wstrb_o <= mem.wstrb_o;
                     mem.wdata_o <= mem.wdata_o;
                  end
               end else begin
                  state <= state;
                  if (mem.ready_i == 1'b1) begin
                     AXI.BVALID_o <= 1'b1;
                     AXI.BRESP_o <= 2'b00;
                     mem.valid_o <= 0;
                     mem.addr_o <= 0;
                     mem.wstrb_o <= 0;
                     mem.wdata_o <= 0;
                  end else begin
                     AXI.BVALID_o <= AXI.BVALID_o;
                     AXI.BRESP_o <= AXI.BRESP_o;
                     mem.valid_o <= mem.valid_o;
                     mem.addr_o <= mem.addr_o;
                     mem.wstrb_o <= mem.wstrb_o;
                     mem.wdata_o <= mem.wdata_o;
                  end
               end
            end
            default: begin // If unasigned state, reset everything
               state <= IDLE;
               write_status <= 0;

               mem.valid_o <= 0;
               mem.wstrb_o <= 0;
               mem.addr_o <= 0;
               mem.wdata_o <= 0;

               AXI.ARREADY_o <= 0;

               AXI.RDATA_o <= 0;
               AXI.RVALID_o <= 0;
               AXI.RRESP_o <= 0;

               AXI.AWREADY_o <= 0;

               AXI.WREADY_o <= 0;

               AXI.BVALID_o <= 0;
            end
         endcase
      end
   end


endmodule