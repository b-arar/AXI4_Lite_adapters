import axi_lite_sim::*;

`timescale 1ns/1ps

module axi_testbench;
    logic clk = 1'b1;
    logic resetn;

    always #5 clk = ~clk;
    /*
    
    global clocking clking1 @(posedge clk);
        //input #1step;
    endclocking : clking1
    
    initial begin
        clk = 1'b1;
        resetn = 1'b0;
        #30
        resetn = 1'b1;
        @(posedge clk) i_mem_in.master.wdata_o = 32'hDEADBEEF;
        i_mem_in.master.valid_o = 1'b1;
        @(posedge clk) 
        i_mem_in.master.valid_o = 1'b0;
        repeat(100) @(posedge clk);
        $dumpvars;
        $finish;
    end
    // interface declarations
    simple_memory i_mem_in();
    AXI4_Lite i_AXI();
    simple_memory i_mem_out();
    // module declarations
    AXI_master_adapter axi_master(.mem(i_mem_in), .AXI(i_AXI));
    AXI_slave_adapter axi_slave(.mem(i_mem_out), .AXI(i_AXI));

    */

    import axi_lite_sim::*;


    SimpleMemory smem(.clk_i(clk), .resetn_i(resetn));

    virtual SimpleMemory v_smem = smem;

    MemActiveDriver m_act = new(v_smem);
    MemReactiveDriver m_react = new(v_smem);

    MemoryTransaction m_trans_1;
    MemoryTransaction m_trans_2;

    initial begin
        $display("test1");
        $dumpvars;
        clk = 1'b1;
        resetn = 1'b1;
        m_act.reset();
        m_react.reset();
        repeat (10) @(posedge clk);

        $display("test2");
        resetn = 1'b0;
        m_trans_1 = new;

        $display("test3");
        m_trans_1.randomize();
        fork
            m_act.drive(m_trans_1);
            m_react.drive(m_trans_2);
        join
        $display("test4");
        
        repeat (100) @(posedge clk);
        $finish;

    end
    
    
endmodule
