module RAM #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,
    parameter BYTE_OFFSET = 2
)(
    input                       clk,
    input                       write_en,
    input                       read_en,
    input   [ADDR_WIDTH-1:0]    addr,
    input   [DATA_WIDTH-1:0]    data_in,
    output reg [DATA_WIDTH-1:0] data_out,
    output reg                  ack
);
    localparam DEPTH = (1 << (ADDR_WIDTH - BYTE_OFFSET));
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    always @(posedge clk) begin
        ack <= 0;
        if (write_en)  begin
          mem[addr[ADDR_WIDTH-1:BYTE_OFFSET]] <= data_in;
            ack <= 1;
        end
        else if (read_en) begin
            data_out <= mem[addr[ADDR_WIDTH-1:BYTE_OFFSET]];
            ack <= 1;
        end
    end
endmodule