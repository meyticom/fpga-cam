----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:45:31 03/14/2012 
-- Design Name: 
-- Module Name:    blob_detection - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.log2;
use ieee.math_real.ceil;

library work;
use work.camera.all ;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;
-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity blob_detection is
generic(LINE_SIZE : natural := 640);
port(
 		clk : in std_logic; 
 		arazb: in std_logic; 
 		pixel_clock, hsync, vsync : in std_logic;
		pixel_clock_out, hsync_out, vsync_out : out std_logic;
 		pixel_data_in : in std_logic_vector(7 downto 0 );
		pixel_data_out : out std_logic_vector(7 downto 0 );
		big_blob_posx, big_blob_posy : out unsigned(9 downto 0)
		);
end blob_detection;

architecture Behavioral of blob_detection is


type blob_states is (WAIT_VSYNC, WAIT_HSYNC, WAIT_PIXEL, COMPARE_PIXEL, ADD_TO_BLOB, END_PIXEL) ;

signal blob_state0 : blob_states ;
signal pixel_x, pixel_y : std_logic_vector(9 downto 0);
signal hsync_old, pixel_clock_old : std_logic := '0';
signal sraz_neighbours, sraz_blobs : std_logic ;
signal neighbours0 : pix_neighbours;
signal new_line, add_neighbour, add_pixel, merge_blob, new_blob : std_logic ;
signal current_pixel : std_logic_vector(7 downto 0) ;
signal new_blob_index, current_blob, blob_index_to_merge, true_blob_index : unsigned(7 downto 0) ;
signal big_blob_posx_tp, big_blob_posy_tp :unsigned(9 downto 0) ;

begin


blobs0 : blobs
	port map(
		clk => clk, arazb => arazb, sraz => sraz_blobs,
		blob_index => current_blob,
		next_blob_index => new_blob_index,
		blob_index_to_merge => blob_index_to_merge ,
		true_blob_index => true_blob_index,
		get_blob => '0' ,
		merge_blob => merge_blob,
		new_blob => new_blob, 
		add_pixel => add_pixel,
		pixel_posx => unsigned(pixel_x), pixel_posy => unsigned(pixel_y),
		max_blob_centerx => big_blob_posx_tp, max_blob_centery => big_blob_posy_tp
	);

update_neighbours : neighbours
		generic map(LINE_SIZE => LINE_SIZE )
		port map(
			clk => clk, 
			arazb => arazb , sraz => sraz_neighbours, 
			add_neighbour => add_neighbour, next_line => new_line,  
			neighbour_in => current_blob,
			neighbours => neighbours0);
			
pixel_counter0: pixel_counter
		port map(
			clk => clk,
			arazb => arazb, 
			pixel_clock => pixel_clock, hsync => hsync,
			pixel_count => pixel_x
			);
			
line_counter0: line_counter
		port map(
			clk => clk,
			arazb => arazb, 
			hsync => hsync, vsync => vsync, 
			line_count => pixel_y
			);


process(clk, arazb)
begin
if arazb = '0' then
	blob_state0 <= WAIT_VSYNC ;
	big_blob_posx <= (others => '0');
	big_blob_posy <= (others => '0');
elsif clk'event and clk = '1' then
	case blob_state0 is
		when WAIT_VSYNC =>
			pixel_clock_out <= '0' ;
			sraz_neighbours <= '1' ;
			sraz_blobs <= '0' ;
			add_neighbour <= '0' ;
			add_pixel <= '0';
			merge_blob <= '0' ;
			new_line <= '0' ;
			if vsync = '0' and  hsync = '0' then
				blob_state0 <= WAIT_PIXEL ;
			end if;
		when WAIT_HSYNC =>
			pixel_clock_out <= '0' ;
			sraz_neighbours <= '0' ;
			sraz_blobs <= '0' ;
			add_neighbour <= '0' ;
			add_pixel <= '0';
			merge_blob <= '0' ;
			new_line <= '1' ;
			if vsync = '1' then
				big_blob_posx <= big_blob_posx_tp ;
				big_blob_posy <= big_blob_posy_tp ;
				sraz_blobs <= '1' ;
				blob_state0 <= WAIT_VSYNC ;
			elsif hsync = '0' then
				blob_state0 <= WAIT_PIXEL ;
			end if;
		when WAIT_PIXEL =>
			pixel_clock_out <= '0' ;
			sraz_neighbours <= '0' ;
			sraz_blobs <= '0' ;
			add_neighbour <= '0' ;
			add_pixel <= '0';
			merge_blob <= '0' ;
			new_line <= '0' ;
			if pixel_clock =  '1' and hsync = '0' and vsync = '0' then
				if pixel_data_in /= X"00" then
					current_pixel <= pixel_data_in ;
					blob_state0 <= COMPARE_PIXEL ;
				else
					current_blob <= (others => '0') ;
					blob_state0 <= ADD_TO_BLOB ;
				end if;
			elsif hsync = '1' then
				new_line <= '1' ;
				blob_state0 <= WAIT_HSYNC ;
			elsif vsync = '1' then
				sraz_blobs <= '1' ;
				big_blob_posx <= big_blob_posx_tp ;
				big_blob_posy <= big_blob_posy_tp ;
				blob_state0 <= WAIT_VSYNC ;
			end if;
		when COMPARE_PIXEL =>
			pixel_clock_out <= '0' ;
			sraz_neighbours <= '0' ;
			sraz_blobs <= '0' ;
			add_neighbour <= '0' ;
			add_pixel <= '0';
			merge_blob <= '0' ;
			new_line <= '0' ;
			if neighbours0 (2) /= X"00" then
				current_blob <= neighbours0 (2) ;
				blob_state0 <= ADD_TO_BLOB ;
			elsif neighbours0 (0) /= X"00" then
				current_blob <= neighbours0 (0) ;
				blob_state0 <= ADD_TO_BLOB ;
			elsif neighbours0 (1) /= X"00" then
				current_blob <= neighbours0 (1) ;
				blob_state0 <= ADD_TO_BLOB ;
			elsif neighbours0 (3) /= X"00" then
				current_blob <= neighbours0 (3) ;
				blob_state0 <= ADD_TO_BLOB ;
			else
				new_blob <= '1' ; --storing a new blob
				current_blob <= new_blob_index; -- getting new blob index from blobs
				blob_state0 <= END_PIXEL ;
			end if ; 
		when ADD_TO_BLOB =>
			pixel_clock_out <= '1' ;
			sraz_neighbours <= '0' ;
			sraz_blobs <= '0' ;
			add_neighbour <= '1' ;
			new_line <= '0' ;
			if current_blob /= X"00" and pixel_x > 3 and pixel_y > 3 and  pixel_x < LINE_SIZE - 3 and pixel_y < 480 - 3 then
				pixel_data_out <= std_logic_vector(true_blob_index(4 downto 0)) & "111";
				add_pixel <= '1';
				if neighbours0(3) /= current_blob then -- left pixel and upper right pixel are different, merge
					blob_index_to_merge <= neighbours0(3) ;
					merge_blob <= '1' ;
				end if ;
			else
				pixel_data_out <= (others => '0') ;
				add_pixel <= '0';
				merge_blob <= '0' ;
			end if;
			blob_state0 <= END_PIXEL ;
		when END_PIXEL =>
			pixel_clock_out <= '1' ;
			sraz_neighbours <= '0' ;
			sraz_blobs <= '0' ;
			add_neighbour <= '0' ;
			add_pixel <= '0';
			merge_blob <= '0' ;
			new_line <= '0' ;
			if pixel_clock =  '0' then
				blob_state0 <= WAIT_PIXEL ;
			end if;
		when others => 
			merge_blob <= '0' ;
			sraz_neighbours <= '0' ;
			sraz_blobs <= '0' ;
			add_neighbour <= '0' ;
			add_pixel <= '0';
			new_line <= '0' ;
			blob_state0 <= WAIT_PIXEL ;
	end case;
end if;
end process;



hsync_out <= hsync ;
vsync_out <= vsync ;

end Behavioral;

