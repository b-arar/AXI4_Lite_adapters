
`timescale 1ns/1ps

class MemoryTransaction;
    rand int addr;
    rand int data;
    rand bit [3:0] wstrb;

    /*const addr_const {
        address >= 4000_0000;
    }*/


    function print();
        $display("address = %h\tdata = %h\twstrb = %b", addr, data, wstrb);
    endfunction

    function bit isEqual(input MemoryTransaction mt);
        bit [31:0] expanded_wstrb;
        if (addr == mt.addr && wstrb == mt.wstrb) begin
            expanded_wstrb = {{8{wstrb[3]}}, {8{wstrb[2]}},{8{wstrb[1]}}, {8{wstrb[0]}}};
            if (data && expanded_wstrb == mt.data & expanded_wstrb) begin
                isEqual = 1'b1;
            end else begin
                isEqual = 1'b0;
            end
        end else begin
            isEqual = 1'b0;
        end
    endfunction
endclass