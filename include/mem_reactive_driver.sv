
`timescale 1ns/1ps

class MemReactiveDriver;
    virtual SimpleMemory smem;
    function new(virtual SimpleMemory smem);
        this.smem = smem;
    endfunction //new()

    task automatic drive(output MemoryTransaction mt);
        bit [31:0] expanded_wstrb;
        wait (smem.scb.valid == 1);
        mt = new;
        mt.randomize() with {addr == smem.scb.addr && wstrb == smem.scb.wstrb;};
        if (smem.scb.wstrb == 4'b0000) begin
            smem.scb.rdata <= mt.data;
        end else begin
            expanded_wstrb = {{8{smem.scb.wstrb[3]}}, {8{smem.scb.wstrb[2]}},{8{smem.scb.wstrb[1]}}, {8{smem.scb.wstrb[0]}}};
            mt.data = (mt.data & ~expanded_wstrb) | (smem.scb.wdata & expanded_wstrb);
        end
        smem.scb.ready <= 1'b1;
    endtask

    task automatic reset();
        smem.scb.ready <= 0;
        smem.scb.rdata <= 0;
    endtask //automatic
endclass //MemReactiveAgent