module tb();
// Inputs
    reg                   clk;
    reg                   rst;
    reg  [15:0]           cpu_addr;
    reg  [31:0]           cpu_data_in;
    reg                   cpu_req;
    reg                   cpu_wen;
// Outputs 
    wire [31:0]           cpu_data_out;
    wire                  cpu_ready;
//////////////////////////////////////////////////////////////////////////////
// Instantiate the Cache System Top Module
    CacheSystem_top dut (
        .clk(clk),
        .rst(rst),
        .cpu_addr(cpu_addr),
        .cpu_data_in(cpu_data_in),
        .cpu_req(cpu_req),
        .cpu_wen(cpu_wen),
        .cpu_data_out(cpu_data_out),
        .cpu_ready(cpu_ready)
    );
initial begin
// Memory Initialization
    $readmemh("mem.dat", dut.main_memory.mem);
// Clock Generation
    clk = 0;
    forever
    #5 clk = ~clk;
end
// Task: CPU Write Request ad operation
    task write_op;
        input [15:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            cpu_req = 1;
            cpu_wen = 1;
            cpu_addr = addr;
            cpu_data_in = data;
            // Wait for acknowledgment
            wait(cpu_ready);
            @(posedge clk);
            cpu_req = 0;
            cpu_wen = 0;
            // Hold idle for a cycle
            @(posedge clk);
        end
    endtask
// Task: CPU Read Request
    task read_op;
        input [15:0] addr;
        begin
            @(posedge clk);
            cpu_req = 1;
            cpu_wen = 0;
            cpu_addr = addr;
            // Wait for acknowledgment
            wait(cpu_ready);
            @(posedge clk);
            cpu_req = 0;
            // Hold idle state for a cycle
            @(posedge clk);
        end
    endtask

initial begin
// Initialize Inputs
    cpu_req = 0;
    cpu_wen = 0;
    cpu_addr = 0;
    cpu_data_in = 0;
// Apply Reset
    rst = 1; 
    @(negedge clk);
    rst = 0;
// Test Case 1: Compulsory Miss & Allocation///////////////////////////////////////////////
    $display("[Time %0t] Test 1: Read Miss at 0x1000", $time);
    read_op(16'h1000);
// Test Case 2: Write Hit (Dirty Bit Verification)/////////////////////////////////////////
    $display("[Time %0t] Test 2: Write 0xAAAA_AAAA to 0x1000", $time);
    write_op(16'h1000, 32'hAAAA_AAAA);
// Test Case 3: Verify Data Integrity (Read Hit)///////////////////////////////////////////
    $display("[Time %0t] Test 3: Read back 0x1000", $time);
    read_op(16'h1000);
    if (cpu_data_out === 32'hAAAA_AAAA) 
        $display(">> Test 3 PASS: Data match (0xAAAA_AAAA)");
    else 
        $display(">> Test 3 FAIL: Expected 0xAAAA_AAAA, got %h", cpu_data_out);
// Test Case 4: Force Eviction (LRU) & Write-Back//////////////////////////////////////////
    $display("[Time %0t] Test 4a: Thrashing Set 0 to force Write-Back", $time);
    write_op(16'h1100, 32'h1111_1111); // Way A filled
    write_op(16'h1200, 32'h2222_2222); // Way B filled
    write_op(16'h1300, 32'h3333_3333); // Way C filled
    $display("[Time %0t] Test 4b: Evicting...", $time);
    write_op(16'h1400, 32'h4444_4444); // Forces eviction of one way
// Test Case 5: Verify Write-Back to RAM///////////////////////////////////////////////////    
    $display("[Time %0t] Test 5: Read 0x1000 (Should fetch from RAM)", $time);
    read_op(16'h1000);
    if (dut.main_memory.mem[14'h400] === 32'hAAAA_AAAA) 
        $display(">> Test 5 PASS: Write-Back successful, RAM contained updated data.");
    else 
        $display(">> Test 5 FAIL: Write-Back failed. RAM returned %h", dut.main_memory.mem[14'h400]);

$display("Test Completed");
$stop;
end
endmodule
