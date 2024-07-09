
`timescale 1ns/1ps

class MemActiveDriver;
    virtual SimpleMemory smem;
    function new(virtual SimpleMemory smem);
        this.smem = smem;
    endfunction //new()

    task automatic drive(input MemoryTransaction mt);
        smem.mcb.addr <= mt.addr;
        smem.mcb.wstrb <= mt.wstrb;
        smem.mcb.wdata <= mt.data;
        smem.mcb.valid <= 1'b1;
        wait (smem.mcb.ready == 1'b1) mt.data = smem.mcb.rdata;
        smem.mcb.valid <= 1'b0;
        @(smem.mcb);
    endtask

    task automatic reset();
        smem.mcb.valid <= 0;
        smem.mcb.wstrb <= 0;
        smem.mcb.addr <= 0;
        smem.mcb.wdata <= 0;
    endtask //automatic
endclass //MemDriver