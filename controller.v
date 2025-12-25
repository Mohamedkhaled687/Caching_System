module controller #(
    parameter ADDR_WIDTH   = 16,
    parameter DATA_WIDTH   = 32,
    parameter CE_PER_WAY   = 64,
    parameter WAYS         = 4,
    parameter BYTE_OFFSET  = 2,
    parameter INDEX_WIDTH  = $clog2(CE_PER_WAY),
    parameter TAG_WIDTH    = ADDR_WIDTH - INDEX_WIDTH - BYTE_OFFSET,
    parameter LINE_WIDTH   = 2 + TAG_WIDTH + DATA_WIDTH
)(
    input   clk,
    input   rst,
    input   [ADDR_WIDTH-1:0] cpu_addr,
    input   [DATA_WIDTH-1:0] cpu_data_in,
    input   cpu_req,
    input   cpu_wen,
    input   [DATA_WIDTH-1:0] mem_data_out,
    input   mem_ready,
    output reg  [DATA_WIDTH-1:0] cpu_data_out,
    output reg  cpu_ready,
    output reg  [ADDR_WIDTH-1:0] mem_addr,
    output reg  [DATA_WIDTH-1:0] mem_data_in,
    output reg  mem_wen,
    output reg  mem_ren
);
// states encoding
    localparam  IDLE=0, 
                CHECKING=1, 
                ALLOCATE=2, 
                WRITE_BACK=3;
// current state and next state
    reg [1:0] cs, ns;
// cache signals
    wire [INDEX_WIDTH-1:0] index = cpu_addr[INDEX_WIDTH+BYTE_OFFSET-1 : BYTE_OFFSET];
    wire [TAG_WIDTH-1:0]   tag   = cpu_addr[ADDR_WIDTH-1 : ADDR_WIDTH-TAG_WIDTH];
    reg  data_wen, update_lru, dirty;
    reg  [1:0] target_way;
    reg  [DATA_WIDTH-1:0] cache_data_in;
    wire hit, victim_dirty;
    wire [1:0] hit_way, lru_way;
    wire [DATA_WIDTH-1:0] int_data_out, victim_data;
    wire [TAG_WIDTH-1:0]   victim_tag;
// instantiating cache module
    cache cache_mod (.clk(clk), .rst(rst), .index(index), .tag(tag), .data_wen(data_wen), 
        .update_lru(update_lru),.target_way(target_way), .data_in(cache_data_in), 
        .dirty(dirty), .hit(hit), .hit_way(hit_way), .data_out(int_data_out),
        .lru_way(lru_way), .victim_dirty(victim_dirty), .victim_tag(victim_tag), 
        .victim_data(victim_data));
// reset state
    always @(posedge clk or posedge rst) begin
        if(rst) cs <= IDLE; 
        else cs <= ns;
    end
// next state logic
    always @(*) begin
        case(cs)
            IDLE:       if(cpu_req) ns = CHECKING;
            CHECKING: begin
                        if(hit) ns = IDLE;
                        else if(victim_dirty) ns = WRITE_BACK;
                        else ns = ALLOCATE;
            end
            ALLOCATE:   if(mem_ready) ns = CHECKING;
            WRITE_BACK: if(mem_ready) ns = ALLOCATE;
        endcase
    end
// output logic
    always @(*) begin
            cpu_ready = 0; cpu_data_out = int_data_out;
            mem_wen = 0; mem_ren = 0; mem_addr = 0; mem_data_in = 0; data_wen = 0;
            update_lru = 0; target_way = 0; cache_data_in = 0; dirty = 0;
            case(cs)
            CHECKING: begin
                if(hit) begin
                    cpu_ready = 1;
                    update_lru = 1;
                    target_way = hit_way;
                    if(cpu_wen) begin
                        data_wen = 1;
                        dirty = 1;
                        cache_data_in = cpu_data_in;
                    end
                end
            end
            ALLOCATE: begin
                mem_ren = 1;
                mem_addr = cpu_addr;
                if(mem_ready) begin
                    data_wen = 1;
                    update_lru = 1;
                    target_way = lru_way;
                    cache_data_in = mem_data_out;
                    dirty = 0;
                end
            end
            WRITE_BACK: begin
                mem_wen = 1;
                mem_addr = {victim_tag, index, {BYTE_OFFSET{1'b0}}};
                mem_data_in = victim_data;
            end
        endcase
    end
endmodule