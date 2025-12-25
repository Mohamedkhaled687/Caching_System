module cache #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter CE_PER_WAY = 64,
    parameter WAYS       = 4,
    parameter BYTE_OFFSET = 2,
    parameter INDEX_WIDTH  = $clog2(CE_PER_WAY),
    parameter TAG_WIDTH    = ADDR_WIDTH - INDEX_WIDTH - BYTE_OFFSET,
    parameter LINE_WIDTH  = 2 + TAG_WIDTH + DATA_WIDTH
) (
    input   clk,
    input   rst,
    // FROM CONTROLLER
    input [INDEX_WIDTH-1:0]  index,
    input [TAG_WIDTH-1:0]    tag,
    input                    data_wen, 
    input                    update_lru,
    input [1:0]              target_way,
    input [DATA_WIDTH-1:0]   data_in,
    input                    dirty,
    // TO CONTROLLER
    output reg                   hit,
    output reg  [1:0]            hit_way,
    output reg [DATA_WIDTH-1:0]  data_out,
    output reg  [1:0]            lru_way,
    output reg                   victim_dirty,
    output reg  [TAG_WIDTH-1:0]  victim_tag,
    output reg  [DATA_WIDTH-1:0] victim_data 
);
// way 4 lines
localparam VALID_BIT = LINE_WIDTH - 2;
localparam DIRTY_BIT = LINE_WIDTH - 1;
localparam TAG_MSB   = LINE_WIDTH - 3;
localparam TAG_LSB   = DATA_WIDTH;
localparam DATA_MSB  = DATA_WIDTH - 1;
localparam DATA_LSB  = 0;

reg[LINE_WIDTH-1:0] way0 [0:CE_PER_WAY-1];
reg[LINE_WIDTH-1:0] way1 [0:CE_PER_WAY-1];
reg[LINE_WIDTH-1:0] way2 [0:CE_PER_WAY-1];
reg[LINE_WIDTH-1:0] way3 [0:CE_PER_WAY-1];

wire [LINE_WIDTH-1:0] line_way0 = way0[index];
wire [LINE_WIDTH-1:0] line_way1 = way1[index];
wire [LINE_WIDTH-1:0] line_way2 = way2[index];
wire [LINE_WIDTH-1:0] line_way3 = way3[index];

reg [LINE_WIDTH-1:0] victim_line;
// counter for LRU
reg [1:0] lru_way0 [0:CE_PER_WAY-1];
reg [1:0] lru_way1 [0:CE_PER_WAY-1];
reg [1:0] lru_way2 [0:CE_PER_WAY-1];
reg [1:0] lru_way3 [0:CE_PER_WAY-1];
reg [1:0] current_value;
integer i;
// hit wires
wire wayout0 = line_way0[VALID_BIT] && (line_way0[TAG_MSB:TAG_LSB] == tag);
wire wayout1 = line_way1[VALID_BIT] && (line_way1[TAG_MSB:TAG_LSB] == tag);
wire wayout2 = line_way2[VALID_BIT] && (line_way2[TAG_MSB:TAG_LSB] == tag);
wire wayout3 = line_way3[VALID_BIT] && (line_way3[TAG_MSB:TAG_LSB] == tag);
    always @(*) begin
        hit = (wayout0 | wayout1 | wayout2 | wayout3);
        if (wayout0) begin 
            hit_way = 0; 
            data_out = line_way0[DATA_MSB:DATA_LSB]; 
        end else if (wayout1) begin 
            hit_way = 1; 
            data_out = line_way1[DATA_MSB:DATA_LSB]; 
        end else if (wayout2) begin 
            hit_way = 2; 
            data_out = line_way2[DATA_MSB:DATA_LSB]; 
        end else begin 
            hit_way = 3; 
            data_out = line_way3[DATA_MSB:DATA_LSB]; 
        end
    end
// LRU logic
    always @(*) begin
        if (lru_way0[index] > lru_way1[index] && lru_way0[index] > lru_way2[index] && lru_way0[index] > lru_way3[index])      
            lru_way = 2'd0;
        else if (lru_way1[index] > lru_way2[index] && lru_way1[index] > lru_way3[index])      
            lru_way = 2'd1;
        else if (lru_way2[index] > lru_way3[index])      
            lru_way = 2'd2;
        else                  
            lru_way = 2'd3;
        case(lru_way) 
            2'd0: victim_line = line_way0;
            2'd1: victim_line = line_way1;
            2'd2: victim_line = line_way2;
            2'd3: victim_line = line_way3;
        endcase
        victim_dirty = victim_line[DIRTY_BIT];
        victim_tag   = victim_line[TAG_MSB:TAG_LSB];
        victim_data  = victim_line[DATA_MSB:DATA_LSB];
    end
// Update LRU counters
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset all cache lines and LRU counters
            for(i=0; i<CE_PER_WAY; i=i+1) begin
                way0[i] <= 0; way1[i] <= 0; way2[i] <= 0; way3[i] <= 0;
                lru_way0[i] <= 0; lru_way1[i] <= 0; lru_way2[i] <= 0; lru_way3[i] <= 0;
            end
        end else begin
            if (data_wen) begin
                // Update: {Dirty, Valid, Tag, Data}
                case(target_way)
                    2'd0: way0[index] <= {dirty, 1'b1, tag, data_in};
                    2'd1: way1[index] <= {dirty, 1'b1, tag, data_in};
                    2'd2: way2[index] <= {dirty, 1'b1, tag, data_in};
                    2'd3: way3[index] <= {dirty, 1'b1, tag, data_in};
                endcase
            end  
            if (update_lru) begin
                case(target_way)
                    2'd0: current_value = lru_way0[index];
                    2'd1: current_value = lru_way1[index];
                    2'd2: current_value = lru_way2[index];
                    2'd3: current_value = lru_way3[index];
                endcase
                // all counters in parallel
                // way 0 counter update
                if (target_way == 0) lru_way0[index] <= 0;
                else if (lru_way0[index] < current_value) lru_way0[index] <= lru_way0[index] + 1;
                // way 1 counter update
                if (target_way == 1) lru_way1[index] <= 0;
                else if (lru_way1[index] < current_value) lru_way1[index] <= lru_way1[index] + 1;
                // way 2 counter update
                if (target_way == 2) lru_way2[index] <= 0;
                else if (lru_way2[index] < current_value) lru_way2[index] <= lru_way2[index] + 1;
                // way 3 counter update
                if (target_way == 3) lru_way3[index] <= 0;
                else if (lru_way3[index] < current_value) lru_way3[index] <= lru_way3[index] + 1;
            end
        end
    end
endmodule