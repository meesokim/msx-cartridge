//
//	LOGIC:		MAX II MSX BUS Master
//	MODULE NAME: 	MSX BUS
//	FILE NAME:		MsxBus.v
//	COMPANY:		Copyright 2017 Miso Kim. www.github.com/meesokim
//	REVISION HISTORY:
//	
//	Revision 1.0	2/3/2017	Description: Initial Release.
//
//  This module is the top level module for MAX II MSX BUS Master.
//
// Modify port declaration
module msxbus_simple (
    input CS,
    input PCLK,
    inout [7:0] RDATA,
    input [1:0] SW,
    input INT, BUSDIR, WAIT,
    inout [7:0] DATA,
    output reg RD,
    output reg WR,
    output reg MREQ,
    output reg IORQ,
    output reg RESET,
    output reg [15:0] ADDR,
    output reg SLTSL1,
    output reg SLTSL2,
    output reg SLTSL1_CS1,    // Changed from CS1
    output reg SLTSL1_CS2,    // Changed from CS2
    output reg SLTSL1_CS12,   // Changed from CS12
    output reg SLTSL2_CS1,    // New
    output reg SLTSL2_CS2,    // New
    output reg SLTSL2_CS12,   // New
    output reg CS1,
    output reg CS2,
    output reg CS12,
    output MCLK, SWOUT, RFSH,
    output reg M1
);

// Add CMD register to the reg declarations
reg [7:0] input_data;
reg [7:0] rdata_out;
reg [7:0] CMD;        // Added CMD register
reg [2:0] state;
reg rdata_drive;

// Add data_drive register declaration
reg [7:0] data_out;
reg data_drive;

// Add bidirectional control for DATA bus
assign RDATA = rdata_drive ? rdata_out : 8'bZ;
assign DATA = data_drive ? data_out : 8'bZ;
assign SWOUT = 1'b1;

// Add to register declarations
reg [1:0] delay_count;

// Add new state to localparam
localparam 
    IDLE = 3'd0,
    GET_CMD = 3'd1,
    GET_ADDR_L = 3'd2,
    GET_ADDR_H = 3'd3,
    SET_CONTROL = 3'd4,
    DELAY_STATE = 3'd5,
    GET_DATA = 3'd6,
    WAIT_STATE = 3'd7,
    GET_STATUS = 3'd8,    // New state
    COMPLETE = 4'd9;

initial begin
    state = IDLE;
    byte_counter = 0;
    SLTSL1 = 1'b1;
    SLTSL2 = 1'b1;
    SLTSL1_CS1 = 1'b1;
    SLTSL1_CS2 = 1'b1;
    SLTSL1_CS12 = 1'b1;
    SLTSL2_CS1 = 1'b1;
    SLTSL2_CS2 = 1'b1;
    SLTSL2_CS12 = 1'b1;
    CS1 = 1'b1;
    CS2 = 1'b1;
    CS12 = 1'b1;
    WR = 1'b1;
    RD = 1'b1;
    MREQ = 1'b1;
    IORQ = 1'b1;
    RESET = 1'b1;
    M1 = 1'b1;
    rdata_drive = 1'b0;
	data_drive = 1'b0;

end
// Modify always block to use only positive edge of CS
always @(negedge PCLK or posedge CS) begin
    if (CS) begin
        state <= GET_CMD;
        RD <= 1'b1;
        WR <= 1'b1;
        MREQ <= 1'b1;
        IORQ <= 1'b1;
        SLTSL1 <= 1'b1;    // Added
        SLTSL2 <= 1'b1;    // Added
		SLTSL1_CS1 = 1'b1;
		SLTSL1_CS2 = 1'b1;
		SLTSL1_CS12 = 1'b1;
		SLTSL2_CS1 = 1'b1;
		SLTSL2_CS2 = 1'b1;
		SLTSL2_CS12 = 1'b1;
	    RESET = 1'b1;
		M1 = 1'b1;
        rdata_drive <= 1'b0;
		data_drive <= 1'b0;
    end else begin
        case (state)
            GET_CMD: begin
                CMD <= RDATA;
                case (RDATA[3:0])    // Only use lower 4 bits for command
                    4'h1: begin // Memory Read
                        state <= GET_ADDR_L;
                    end
                    4'h2: begin // Memory Write
                        state <= GET_ADDR_L;
                    end
                    4'h3: begin // IO Read
                        state <= GET_ADDR_L;
                    end
                    4'h4: begin // IO Write
                        state <= GET_ADDR_L;
                    end
                    4'h5: begin // Reset
                        RESET <= 1'b0;
                        state <= COMPLETE;
                    end
                    4'h8: begin // Get Status
                        state <= GET_STATUS;
                        rdata_drive <= 1'b1;
                    end
                    default: state <= IDLE;
                endcase
            end

            GET_ADDR_L: begin
                ADDR[7:0] <= RDATA;
                state <= GET_ADDR_H;
            end

            GET_ADDR_H: begin
                ADDR[15:8] <= RDATA;
                if (CMD[3:0] != 4'h5) begin
                    state <= SET_CONTROL;
                end
            end

            SET_CONTROL: begin
                // Common control signals
                MREQ <= CMD[1];
                IORQ <= !CMD[1];
                RD <= CMD[0];    
                WR <= !CMD[0];     
                M1 <= CMD[7];
                // Memory access signals
                if (!CMD[1]) begin  // If MREQ is active
                    SLTSL1 <= !CMD[4];
                    SLTSL2 <= CMD[4];
                    if (!CMD[4]) begin  // SLTSL1 active
                        SLTSL1_CS1 <= (ADDR[15:14] == 2'b01) ? 1'b0 : 1'b1;
                        SLTSL1_CS2 <= (ADDR[15:14] == 2'b10) ? 1'b0 : 1'b1;
                        SLTSL1_CS12 <= ((ADDR[15:14] == 2'b01) || (ADDR[15:14] == 2'b10)) ? 1'b0 : 1'b1;
                    end else begin     // SLTSL2 active
                        SLTSL2_CS1 <= (ADDR[15:14] == 2'b01) ? 1'b0 : 1'b1;
                        SLTSL2_CS2 <= (ADDR[15:14] == 2'b10) ? 1'b0 : 1'b1;
                        SLTSL2_CS12 <= ((ADDR[15:14] == 2'b01) || (ADDR[15:14] == 2'b10)) ? 1'b0 : 1'b1;
                    end
                end
                // State transition and data direction
                if (CMD[0]) begin  // Write operations
                    data_out <= RDATA;
                    data_drive <= 1'b1;
                end else begin
                    data_drive <= 1'b0;
                end
                rdata_drive <= 1'b1;
				rdata_out <= 8'h00;
                delay_count <= 2'b11;  // Initialize delay counter
                state <= DELAY_STATE;
            end

            DELAY_STATE: begin
                if (delay_count == 2'b00) begin
                    state <= WAIT_STATE;
                end else begin
                    delay_count <= delay_count - 1;
                end
            end
            WAIT_STATE: begin
                if (WAIT) begin
                    rdata_out <= 8'hFF; // ACK
					if (CMD[0]) begin
	                    state <= GET_DATA;
					end else begin
	                    state <= COMPLETE;
					end
                end
            end

            GET_DATA: begin
                rdata_out <= DATA;
                state <= COMPLETE;
            end

            GET_STATUS: begin
                rdata_out <= {INT, SW, 6'b0000, WAIT};  // INT in bit 7, SW[1:0] in bit 6-5, WAIT in bit 0
                state <= COMPLETE;
            end

            COMPLETE: begin
                state <= IDLE;
				RESET <= 1'b1;
            end
        endcase
    end
end

// Remove the old combinational chip select logic block
endmodule

