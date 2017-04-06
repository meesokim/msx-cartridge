-- sram_controller.vhd
-- ****************************************** --
-- Performs a read write operation to a SRAM ---
-- When fed by a 25.175MHz clock, this code ----
-- will have a cycle time of 140ns and a  ------
-- access time of 160ns --
-- To write to SRAM:
--      on rising edge of clock,
-- if done signal is asserted,
-- set: ce = '0', we = '0', and saddr = 15bit addr
--      DIN = 8 bit data
--
-- To read from SRAM:
--      on rising edge of clock,
-- if done signal is asserted,
-- set: ce = '0', we = '0', and saddr = 15bit addr
--
-- To perform burst read/writes, check for
-- done_transac after each operation to be asserted
-- before performing another operation
--
-- when done_transac = '1' or done = '1', then
-- the operation you requested will be performed
-- in the case of reading SRAM, you can
-- read the data (DOUT) anytime after either one of these
-- signals are asserted.
-- ****************************************** --

-- EE552
-- Data Co-processor
-- Eric Chan
-- Tim Bensler

Library ieee; 
use ieee.std_logic_1164.all; 
use ieee.std_logic_arith.all; 
use ieee.std_logic_unsigned.all; 

package sram_pkg is
	constant sram_data_width : positive := 8;
	constant sram_addr_width : positive := 16;
	subtype sram_addr is std_logic_vector(sram_addr_width-1 downto 0);
	subtype sram_data is std_logic_vector(sram_data_width-1 downto 0);
	type states is (INIT_ADDR, INIT_SIG, READ_REQ, WRITE_REQ,
--					WAIT_WRITE, WAIT_READ,
					WRITE_COMPL, READ_COMPL);
	
	component sram_controller is
		port (
			mem_clk : in std_logic;
			reset : in std_logic;
			addr : in sram_addr;
			addr_out : out sram_addr;
			-- This signals connect directly to the SRAM
			D : inout sram_data;
			-- These signals interacts with the user
			DIN : in sram_data;
			DOUT : out sram_data;
			-- signals transaction completed when asserted
			done : BUFFER std_logic;
			done_transac : out std_logic;
			-- Write Enable (active low)
			we : in std_logic;
			nwe : BUFFER std_logic;
			-- Output Enable (active low)
			-- Output Enable will be controlled by the sram controller
--			oe : in std_logic;
			noe : out std_logic;
			-- Chip Enable (active low)
			ce : in std_logic;
			nce : BUFFER std_logic
			-- Debugging Purposes
--			c_state : out states
		);
	end component sram_controller;
end sram_pkg;

---------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------

library ieee; 
use ieee.std_logic_1164.all; 
use ieee.std_logic_arith.all; 
use ieee.std_logic_unsigned.all; 
library work;
use work.sram_pkg.all;

entity sram_controller is
	port (
		reset : in std_logic;
		mem_clk : in std_logic;
		addr : in sram_addr;
		addr_out : out sram_addr;
		D : inout sram_data;
		DIN : in sram_data;
		DOUT : out sram_data;
		done : BUFFER std_logic;
		done_transac : out std_logic;
		we : in std_logic;
		nwe : BUFFER std_logic;
		noe : out std_logic;
		ce : in std_logic;
		nce : BUFFER std_logic;
		c_state : out states
	);
end sram_controller; 
	
architecture beh_component of sram_controller is
signal saddr : sram_addr;
signal addr_same : sram_addr;
signal d_in : sram_data;
signal d_out : sram_data;

signal cstate : states;
begin

	addr_out <= saddr;
	c_state <= cstate;
		
	sram_readwrite : process (mem_clk) is
	type sram_rw_states is (SRAM_IDLE, SRAM_DONE);
	variable sram_rw_cstate : sram_rw_states;
	begin
		if reset = '1' then
			done_transac <= '1';
			sram_rw_cstate := SRAM_IDLE;
		elsif falling_edge(mem_clk) then
			case sram_rw_cstate is
			when SRAM_IDLE =>
				if done = '1' then
					done_transac <= '1';
					sram_rw_cstate := SRAM_DONE; 
				end if;
			when SRAM_DONE =>
				done_transac <= '0';
				if done = '0' then
					sram_rw_cstate := SRAM_IDLE;
				end if;
			end case;
		end if;
	end process sram_readwrite;

	MEM_LOGIC: process (mem_clk)
	begin
		if (reset = '1') then
			nce <= '1';
			noe <= '1';
			cstate <= WRITE_COMPL;	
		elsif rising_edge(mem_clk) then
			case cstate is
			when INIT_ADDR =>
				-- Check if user wants to access the SRAM
				if (ce = '0') then
					cstate <= INIT_SIG;	
				end if;
				nce <=	ce;
			when INIT_SIG =>
				-- Determines whether to read or write
				if (we = '0') then
					-- Output Enable is Enabled, SRAM driving the D-bus
					noe <= '1';
					cstate <= WRITE_REQ;
				else
					-- Output Enable is Disabled, SRAM Controller driving the D-bus
					noe <= '0';
					cstate <= READ_REQ;		
				end if;
			-- 0th wait cycle
			when WRITE_REQ =>
--				cstate <= WAIT_WRITE;
				cstate <= WRITE_COMPL;
			when READ_REQ =>
				cstate <= READ_COMPL;
--				cstate <= WAIT_READ;
			-- 1st wait cycle
--			when WAIT_WRITE =>
--				cstate <= WRITE_COMPL;
--			when WAIT_READ =>
--				cstate <= READ_COMPL;
			-- 2nd wait cycle
			when WRITE_COMPL =>
				cstate <= INIT_ADDR;			
			when READ_COMPL =>
				DOUT <= D;
				-- Data is sent to user, SRAM no longer has to drive the bus
				noe <= '1';
				cstate <= INIT_ADDR;			
			end case;
		end if;
	end process MEM_LOGIC;	

	WITH cstate SELECT
		D <= (others => 'Z') when INIT_ADDR, 
			(others => 'Z') when INIT_SIG,
			(others => 'Z') when READ_REQ,
--			(others => 'Z') when WAIT_READ,
			(others => 'Z') when READ_COMPL,
			d_out WHEN others;

	WITH cstate SELECT
		done <=	'1' WHEN INIT_ADDR, 
				'0' WHEN others;
--	WITH cstate SELECT
--		nce <=	ce	WHEN INIT_ADDR,
--				nce WHEN others;
	WITH cstate SELECT
		nwe <=	we	WHEN INIT_SIG, 
				nwe WHEN others;
	WITH cstate SELECT
		d_out <= DIN WHEN INIT_SIG, 
				d_out WHEN others;
	WITH cstate SELECT
		-- This is implemented to satisfy tAS (Setup time) timing
		-- 	before Chip Enabled signal is se nt to SRAM chip
		-- Also used to prevent user from changing mem address during SRAM access
		saddr <= addr WHEN INIT_ADDR,
				saddr WHEN others;
end beh_component;