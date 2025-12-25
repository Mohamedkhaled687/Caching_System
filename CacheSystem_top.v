module CacheSystem_top #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32
)(
    input                   clk,
    input                   rst,
    // CPU Interface
    input  [ADDR_WIDTH-1:0] cpu_addr,
    input  [DATA_WIDTH-1:0] cpu_data_in,
    input                   cpu_req,
    input                   cpu_wen,
    output [DATA_WIDTH-1:0] cpu_data_out,
    output                  cpu_ready
);
    // Internal wires between Controller and RAM
    wire [ADDR_WIDTH-1:0] mem_addr;
    wire [DATA_WIDTH-1:0] mem_data_in;
    wire [DATA_WIDTH-1:0] mem_data_out;
    wire                  mem_wen;
    wire                  mem_ren;
    wire                  mem_ready;
    // Instantiate Cache Controller
    controller cache_ctrl (
        .clk(clk),
        .rst(rst),
        .cpu_addr(cpu_addr),
        .cpu_data_in(cpu_data_in),
        .cpu_req(cpu_req),
        .cpu_wen(cpu_wen),
        .cpu_data_out(cpu_data_out),
        .cpu_ready(cpu_ready),
        // Memory side
        .mem_addr(mem_addr),
        .mem_data_in(mem_data_in),
        .mem_data_out(mem_data_out),
        .mem_wen(mem_wen),
        .mem_ren(mem_ren),
        .mem_ready(mem_ready));
    // Instantiate Main Memory (RAM)
    RAM main_memory (
        .clk(clk),
        .write_en(mem_wen),
        .read_en(mem_ren),
        .addr(mem_addr),
        .data_in(mem_data_in),
        .data_out(mem_data_out),
        .ack(mem_ready));
endmodule