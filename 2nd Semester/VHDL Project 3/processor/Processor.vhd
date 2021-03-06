LIBRARY ieee, work;
USE ieee.std_logic_1164.all; 
USE ieee.std_logic_signed.all; 
USE work.ALU16Bit.all;
ENTITY Processor IS 
    PORT ( DIN : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
			  Clock, Run : IN STD_LOGIC; 
			  resetn : INOUT STD_LOGIC; -- resetn is used asinput and as ALU output 
           Done : BUFFER STD_LOGIC; 
           BusWires : BUFFER STD_LOGIC_VECTOR(15 DOWNTO 0)); 
END Processor; 

ARCHITECTURE Behavior OF Processor IS 

COMPONENT regn IS
	GENERIC (n : INTEGER := 16); 
  PORT ( R : IN STD_LOGIC_VECTOR(n-1 DOWNTO 0); 
			Rin, Clock : IN STD_LOGIC; 
			Q : BUFFER STD_LOGIC_VECTOR(n-1 DOWNTO 0)); 
END COMPONENT;
 
COMPONENT upcount IS
	PORT ( Clear, Clock : IN STD_LOGIC; 
			 Q : OUT STD_LOGIC_VECTOR(1 DOWNTO 0)); 
END COMPONENT;

COMPONENT dec3to8 IS
	PORT ( W : IN STD_LOGIC_VECTOR(2 DOWNTO 0); 
			 En : IN STD_LOGIC; 
			 Y : OUT STD_LOGIC_VECTOR(0 TO 7));
END COMPONENT; 
-- signals 
SIGNAL Ain ,Gin ,IRin: STD_LOGIC; --control signals for registers A ,G ,and IR.
SIGNAL Clear ,High : STD_LOGIC;
SIGNAL ALUOP : STD_LOGIC_VECTOR(2 DOWNTO 0); --defines ALU operation 
--ALU operations (from previous exercice) :
		-- 000 : AND 
		-- 001 : OR
		-- 011 : ADD
		-- 010 : SUB
		-- 101 : NOR
		-- 100 : XOR
	   -- 110 : NOT 	
SIGNAL Sum : STD_LOGIC_VECTOR(15 DOWNTO 0); -- ALU sum 
SIGNAL Tstep_Q : STD_LOGIC_VECTOR(1 DOWNTO 0); --current function step 
SIGNAL A , G , R0 ,R1 ,R2 ,R3 ,R4, R5,R6, R7 : STD_LOGIC_VECTOR(15 DOWNTO 0); --16-bit registers
SIGNAL IR : STD_LOGIC_VECTOR(8 DOWNTO 0); --Encoded DIN 
SIGNAL I : STD_LOGIC_VECTOR(2 DOWNTO 0);
SIGNAL Gout ,DINout : STD_LOGIC ; -- Multiplexer select inputs
SIGNAL BusSelect : STD_LOGIC_VECTOR(9 DOWNTO 0);
SIGNAL Rin ,Rout ,Xreg ,Yreg : STD_LOGIC_VECTOR(7 DOWNTO 0); --Rin : control signal for each 16-bit register . Rout : multiplexer select input
 --Xreg : Rx register data . Yreg : Ry register data.
BEGIN 
  High <= '1'; 
  Clear <= resetn OR Done OR (NOT Run AND (NOT Tstep_Q(0)) AND (NOT Tstep_Q(1)));
  Tstep: upcount PORT MAP (Clear, Clock, Tstep_Q); --counter used to define each step
  I <= IR(8 DOWNTO 6); -- First 3 bits of IR define the function
  decX: dec3to8 PORT MAP (IR(5 DOWNTO 3), High, Xreg); --next 3 bits define Rx register's data
  decY: dec3to8 PORT MAP (IR(2 DOWNTO 0), High, Yreg); --next 3 bits define Ry register's data (not needed in mvi)

	-- Instruction Table
	--  000: mv			Rx,Ry
	--  001: mvi		Rx,#D
	--  010: and        Rx,Ry	
	--  011: or         Rx,Ry	
	--  100: add		Rx,Ry				: Rx <- [Rx] + [Ry]
	--  101: sub		Rx,Ry				: Rx <- [Rx] - [Ry]
	--  110: xor        Rx,Ry	
	--  111: not        Rx,Ry
	-- 	OPCODE format: III XXX YYY, where 
	-- 	III = instruction, XXX = Rx, and YYY = Ry. For mvi,
	-- 	a second word of data is loaded from DIN

  controlsignals: PROCESS (Tstep_Q, I, Xreg, Yreg) 
  BEGIN
	Rin <= (OTHERS=>'0') ;Rout<= (OTHERS =>'0') ;Ain <= '0' ;Gin <= '0' ; --Initialise values
	Done <= '0' ; ALUOP<= "000" ; IRin <= '0' ;Gout <= '0' ; DINout <= '0';
	CASE Tstep_Q IS -- Periptwseis gia to Bhma sto opoio brisketai o processor
			WHEN "00" =>  --store DIN in IR as long as Tstep_Q = 0 
				IRin <= '1'; 
			WHEN "01" =>  --define signals in time step T1 
				CASE I IS 
					WHEN "000" => --mv
						Done <= '1';
						Rin <= Xreg;
						Rout <= Yreg;
					WHEN "001" => -- mvi
						Done <= '1' ; 
						DINout <= '1';
						Rin <= Xreg;
					WHEN "111" => --NOT 
						Ain<= '1';
						Rout <= Yreg; 
					WHEN OTHERS => -- ALU functions (AND ,OR ,ADD ,SUB ,XOR ,NOT)
						Ain <= '1';
						Rout <= Xreg ;
				END CASE ;
			WHEN "10" => --define signals in time step T2
				CASE I IS
					WHEN "010" => --AND 
						Rout <= Yreg;
						ALUOP <= "000";
						Gin <= '1';
					WHEN "011" => --OR
						Rout <= Yreg;
						ALUOP <= "001";
						Gin <= '1';
					WHEN "100" => --ADD
						Rout <= Yreg;
						Gin <= '1';
						ALUOP <= "011";
					WHEN "101" => --SUB	
						Rout <= Yreg ;
						Gin <= '1';
						ALUOP <= "010";
					WHEN "110" => --XOR
						Rout <= Yreg;
						Gin <= '1';
						ALUOP <= "100";
					WHEN OTHERS => --NOT
						Rout <= Xreg;
						Gin <= '1';
						ALUOP <= "110";
        END CASE; 
      WHEN "11" =>  --define signals in time step T3 
        CASE I IS 
				WHEN "010" => --AND 
						Rin <= Xreg;
						Gout <= '1';
						Done <= '1';
					WHEN "011" => --OR
						Rin <= Xreg;
						Gout <= '1';
						Done <= '1';
					WHEN "100" => --ADD
						Rin <= Xreg;
						Gout <= '1';
						Done <= '1';
					WHEN "101" => --SUB	
						Rin <= Xreg ;
						Gout <= '1';
						Done <= '1';
					WHEN "110" => --XOR
						Rin <= Xreg;
						Gout <= '1';
						Done <= '1';
					WHEN OTHERS => --NOT
						Rin <= Xreg;
						Gout <= '1';
						Done <= '1';

        END CASE; 
    END CASE; 
  END PROCESS; 
  -- R0 to R7 Registers
  reg_0: regn PORT MAP (BusWires, Rin(0), Clock, R0); 
  reg_1: regn PORT MAP (BusWires, Rin(1), Clock, R1);
  reg_2: regn PORT MAP (BusWires, Rin(2), Clock, R2);
  reg_3: regn PORT MAP (BusWires, Rin(3), Clock, R3);
  reg_4: regn PORT MAP (BusWires, Rin(4), Clock, R4);
  reg_5: regn PORT MAP (BusWires, Rin(5), Clock, R5);
  reg_6: regn PORT MAP (BusWires, Rin(6), Clock, R6);
  reg_7: regn PORT MAP (BusWires, Rin(7), Clock, R7);
  -- A Register
  reg_A: regn PORT MAP (BusWires, Ain ,Clock , A );
  --Instructions Register
  In_reg: regn GENERIC MAP (N => 9)
					PORT MAP( DIN(15 DOWNTO 7), IRin ,Clock ,IR);
  -- ALU
  ALU_Unit : ALU_16_Bit PORT MAP (A , BusWires ,ALUOP ,resetn ,Sum );
  -- G register
  reg_G: regn PORT MAP (Sum, Gin , Clock ,G );
  --Bus 
  BusSelect <= Rout & Gout & DINout;
  WITH BusSelect SELECT 
		BusWires <= R0 WHEN "0000000100",
						R1 WHEN "0000001000",
						R2 WHEN "0000010000",
						R3 WHEN "0000100000",
						R4 WHEN "0001000000",
						R5 WHEN "0010000000",
						R6 WHEN "0100000000",
						R7 WHEN "1000000000",
						G WHEN  "0000000010",
						DIN WHEN OTHERS;
END Behavior; 




LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_signed.all;


ENTITY upcount IS 

  PORT ( Clear, Clock : IN STD_LOGIC; 
  Q : OUT STD_LOGIC_VECTOR(1 DOWNTO 0)); 
END upcount; 

ARCHITECTURE Behavior OF upcount IS 
 SIGNAL Count : STD_LOGIC_VECTOR(1 DOWNTO 0); 

BEGIN 
  PROCESS (Clock) 
  BEGIN 

    IF (Clock'EVENT AND Clock = '1') THEN 

     IF Clear = '1' THEN 
       Count <= "00"; 
     ELSE 
       Count <= Count + 1; 
     END IF; 

   END IF; 
  END PROCESS; 
  Q <= Count; 

END Behavior; 


LIBRARY ieee;
USE ieee.std_logic_1164.all;


ENTITY dec3to8 IS


  PORT ( W : IN STD_LOGIC_VECTOR(2 DOWNTO 0); 
  En : IN STD_LOGIC; 
  Y : OUT STD_LOGIC_VECTOR(7 downto 0)); 
END dec3to8; 

ARCHITECTURE Behavior OF dec3to8 IS 
BEGIN 
  PROCESS (W, En) 
	BEGIN 
		IF En = '1' THEN 
			CASE W IS 
				WHEN "000" =>
					Y <= "00000001";
				WHEN "001" =>
					Y <= "00000010";
				WHEN "010" =>
					Y <= "00000100";
				WHEN "011" =>
					Y <= "00001000";
				WHEN "100" =>
					Y <= "00010000";
				WHEN "101" =>
					Y <= "00100000";
				WHEN "110" =>
					Y <= "01000000";
				WHEN "111" =>
					Y <= "10000000";
			END CASE; 
		ELSE 
			Y <= "00000000"; 
		END IF; 
   END PROCESS; 
END Behavior; 

LIBRARY ieee;
USE ieee.std_logic_1164.all;


ENTITY regn IS 
  GENERIC (n : INTEGER := 16); 
  PORT ( R : IN STD_LOGIC_VECTOR(n-1 DOWNTO 0); 

  Rin, Clock : IN STD_LOGIC; 

  Q : BUFFER STD_LOGIC_VECTOR(n-1 DOWNTO 0)); 
END regn; 

ARCHITECTURE Behavior OF regn IS 

BEGIN 
  PROCESS (Clock) 
  BEGIN 

    IF Clock'EVENT AND Clock = '1' THEN 
      IF Rin = '1' THEN 
        Q <=R; 
      END IF; 
    END IF; 
  END PROCESS; 
END Behavior; 