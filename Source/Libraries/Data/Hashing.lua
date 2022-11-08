--[[
	Algorithms Supported:
	CRC8, CRC8-CCITT, CRC8-MAXIM
	CRC16-IBM, CRC16-DNP, CRC16-CCITT
	CRC32, CRC32-C, CRC32-K
	CRC64 Algorithms Are WIP
	TODO: BLAKE-256, BLAKE-512, BLAKE2s, BLAKE2b, BLAKE3
--]]
local Hashing = {}


local GlobalEnv = (((getgenv and getgenv()) or _G)["EPD_GENV_REF"] or _G)
local m_Bitfield = GlobalEnv.EPD.BaseLib.LoadLibrary("Libraries/Data/Bitfield")

assert(m_Bitfield, "Bitfield Library Not Loaded")

local string_reverse = string.reverse
local string_byte = string.byte
local string_char = string.char
local string_sub = string.sub
local brsh 	= bit32.rshift 	-- >>
local blsh 	= bit32.lshift 	-- <<
local bxor 	= bit32.bxor 	-- ^
local bnot 	= bit32.bnot 	-- !
local band 	= bit32.band 	-- &
local bor 	= bit32.bor 	-- |


--[[
--<DEBUG>--
local TableId = 0
function DBG_SaveCRCLookupTable(Table, Header, RowWidth, FileName)
	RowWidth = RowWidth or 8
	FileName = FileName or "CRCLookupTable"
	
	local Output = (Header and Header .. "\n") or ""
	for Index, Value in pairs(Table) do
		Output ..= string.format("0x%X ", Value)
		if Index % RowWidth == 0 then
			Output ..= "\n"
		end
	end
	TableId += 1
	writefile(FileName .. "-" .. tostring(TableId) .. ".txt", Output)
end

--]]


local function MakeBitset(Size)
	local OutputValue = 1
	for _=1, Size - 1 do
		OutputValue = blsh(OutputValue, 1) + 1
	end
	return OutputValue
end

--[[PRECOMP<FLAGS<INLINE, CONST_OPTIMIZE>>]]
function BinaryReflect(Number, Size)
	
	local Result = 0x00
	for i=0, Size - 1 do
		-- Number & (1 << i)
		if band(Number, blsh(1, i)) ~= 0 then
			--Result = Result | (1 << ((Size - 1) - i))
			Result = bor(Result, blsh(1, ((Size - 1) - i)))
		end
	end
	
	return Result
end

local function ApplyOnString(String, Function, ...)
	local Output = ""
	for Index=1, #String do
		Output ..= string_char(Function(string_byte(String, Index), ...))
	end
	return Output
end


local function DualApplyOnString(String1, String2, Function)
	local Output = ""
	for Index=1, #String1 do
		Output ..= string_char(Function(string_byte(String1, Index), string_byte(String2, Index)))
	end
	return Output
end


------------------------------
-- Cyclic Redundancy Checks --
------------------------------
do
	Hashing.CRC = {}
	
	function Hashing.CRC.GenerateCRCLookupTable(Polynomial, Width, ReflectPolynomial, Reflected, Table, Len)
		Table = Table or {}
		Len = Len or 0xFF
		ReflectPolynomial = ReflectPolynomial or false
		
		Polynomial = (ReflectPolynomial == true and BinaryReflect(Polynomial, Width)) or Polynomial
		
		if Width < 8 then
			Width = 8
		end
		local CastMask = MakeBitset(Width)
		local MSBMask = blsh(0x01, (Width - 1))
		local Remainder = 0
		
		--print(string.format("Width: %d MSBMask: 0x%X CastMask: 0x%X", Width, MSBMask, CastMask))
		
		for Dividend=0, Len do
			
			Remainder = band(
				blsh(
					(Reflected and BinaryReflect(Dividend, 8)) or Dividend,
					(Width - 8)
				),
				CastMask
			)

			for _=1, 8 do
				if band(Remainder, MSBMask) ~= 0 then
					Remainder = bxor(blsh(Remainder, 1), Polynomial)
				else
					Remainder = blsh(Remainder, 1)
				end
			end
			Table[Dividend + 1] = band((Reflected and BinaryReflect(Remainder, Width)) or Remainder, CastMask)
		end

		return Table
	end

	-- Basic Modular CRC Implementation, Supports Up To 52 Bits
	function Hashing.CRC.InvertedCRC52(Input, Initial, XOROut, LookupTable)
		local CRC = Initial
		
		for Index=1, #Input do
			CRC = bxor(
				LookupTable[band(bxor(CRC, string_byte(Input, Index)), 0xFF) + 1],
				brsh(CRC, 8)
			)
			
		end

		return bxor(CRC, XOROut)
	end
	
	--[[ TODO: Fix, Not Working
	function Hashing.CRC.NormalCRC52(Input, Initial, XOROut, LookupTable, Width)
		local CRC = Initial
		local Len = Width - 8
		
		for Index=1, #Input do
			CRC = bxor(
				blsh(CRC, 8),
				LookupTable[band(bxor(brsh(CRC, Len), string_byte(Input, Index)), 0xFF) + 1]
			)
		end
		
		return bxor(CRC, XOROut)
	end
	--]]
	
	do
		local IntegrityCheck = "ABCDEF"

	--[[
	Table Format:
	{
		Name<String>: CRC Function Name
		Description<String>: Description For What It Is/Was Used
		
		Initial<Integer/String>: Initial Value For The CRC
		XOROut<Integer/String>: The Value Used To XOR The Output
		
		Polynomial<{<Integer/String>, <Bool>}>: Polynomial Seed, And Reflect The Polynomial
		Reflect<{Refin<Bool>, Refout<Bool>}>: If It Should Reflect The Input/Output
		Width<Integer>: CRC Size(In Bits)
		
		IntegrityCheck<Integer/String>: What The Output Should Be When The Input Is The 'IntegrityCheck' Variable
		
		NOTE: 'Polynomial', 'IntegrityCheck', 'Initial', And The 'XOROut' Variables Should Be A Binary String If The CRC Is Bigger Than 52 Bits
		NOTE: The 'Initial' And 'XOROut' Variable Will Be Assumed As 0 Or "\00" If Not Defined
	}
	--]]
		local Implementations = {
			{
				Name = "CRC8",
				Description = "DVB-S2",
				-- CRC Info
				Polynomial 	= {0x07, false},
				Reflect		= {false, false},
				Width 		= 8,

				IntegrityCheck = 0x10
			},
			{
				Name = "CRC8_CCITT",
				Description = "ITU-T I.432.1 (02/99); ATM HEC, ISDN HEC And Cell Delineation, SMBus PEC",
				-- CRC Info
				Initial = 0x00,
				XOROut = 0x55,

				Polynomial 	= {0x07, false},
				Reflect		= {false, false},
				Width 		= 8,

				IntegrityCheck = 0x45
			},
			{
				Name = "CRC8_MAXIM",
				Description = "1-Wire, Bus",
				-- CRC Info
				Polynomial 	= {0x31, false},
				Reflect		= {true, true},
				Width 		= 8,

				IntegrityCheck = 0x10
			},
			
			{
				Name = "CRC16_IBM",
				Description = "Bisync, Modbus, USB, ANSI X3.28, SIA DC-07, Many Others; Also Known As CRC-16 And CRC-16-ANSI",
				-- CRC Info
				Polynomial 	= {0x8005, false},
				Reflect		= {true, true},
				Width 		= 16,

				IntegrityCheck = 0xED91
			},
			{
				Name = "CRC16_DNP",
				Description = "DNP, IEC 870, M-Bus",
				-- CRC Info
				XOROut = 0xFFFF,
				
				Polynomial 	= {0x3D65, false},
				Reflect		= {true, true},
				Width 		= 16,

				IntegrityCheck = 0xA546
			},
			{
				Name = "CRC16_CCITT",
				Description = "X.25, V.41, HDLC FCS, XMODEM, Bluetooth, PACTOR, SD, DigRF, Many Others; Known As CRC-CCITT",
				-- CRC Info
				Polynomial 	= {0x1021, false},
				Reflect		= {true, true},
				Width 		= 16,

				IntegrityCheck = 0x98D1
			},
			
			{
				Name = "CRC32",
				Description = "ISO 3309 (HDLC), ANSI X3.66 (ADCCP), FIPS PUB 71, FED-STD-1003, ITU-T V.42, ISO/IEC/IEEE 802-3 (Ethernet), SATA, MPEG-2, PKZIP, Gzip, Bzip2, POSIX cksum, PNG, ZMODEM, Many Others",
				-- CRC Info
				Initial = 0xFFFFFFFF,
				XOROut = 0xFFFFFFFF,
				
				Polynomial 	= {0x04C11DB7, false},
				Reflect		= {true, true},
				Width 		= 32,

				IntegrityCheck = 0xBB76FE69
			},
			{
				Name = "CRC32_C",
				Description = "iSCSI, SCTP, G.hn Payload, SSE4.2, Btrfs, ext4, Ceph",
				-- CRC Info
				Initial = 0xFFFFFFFF,
				XOROut = 0xFFFFFFFF,

				Polynomial 	= {0x1EDC6F41, false},
				Reflect		= {true, true},
				Width 		= 32,

				IntegrityCheck = 0xA4B7CE68
			},
			{
				Name = "CRC32_K",
				Description = "Excellent At Ethernet Frame Length, Poor Performance With Long Files",
				-- CRC Info
				Initial = 0xFFFFFFFF,
				XOROut = 0xFFFFFFFF,

				Polynomial 	= {0x741B8CD7, false},
				Reflect		= {true, true},
				Width 		= 32,

				IntegrityCheck = 0xECE2DB2D
			},
			--[[ TODO: Fix Reflection
			{
				Name = "CRC32_MPEG2",
				Description = "Excellent At Ethernet Frame Length, Poor Performance With Long Files",
				-- CRC Info
				Initial = 0xFFFFFFFF,

				Polynomial 	= {0x04C11DB7, false},
				Reflect		= {false, false},
				Width 		= 32,

				IntegrityCheck = 0x5D516EE7
			},
			--]]
		}
		
		
		--DBG_SaveCRCLookupTable(Hashing.CRC.GenerateCRCLookupTable(0x04C11DB7, 32, false, false), "TABLE", 8)
		

		local InvertedCRC52 = Hashing.CRC.InvertedCRC52
		local NormalCRC52 = Hashing.CRC.NormalCRC52
		
		for _, Item in pairs(Implementations) do
			if Item.Width > 52 then
				error("CRCs Bigger Than 52-Bits Are Not Supported Yet.")
			else
				local Initial = Item.Initial or 0
				local XOROut = Item.XOROut or 0
				local Width = Item.Width
				local RefIn, RefOut = Item.Reflect[1], Item.Reflect[2]
				local LookupTable = Hashing.CRC.GenerateCRCLookupTable(Item.Polynomial[1], Width, Item.Polynomial[2], RefIn)
				
				--DBG_SaveCRCLookupTable(LookupTable, Item.Name, 16, Item.Name)
				
				local CRCFunc = nil
				
				CRCFunc = function(Data) return InvertedCRC52(Data, Initial, XOROut, LookupTable) end
				
				
				
				Hashing.CRC[Item.Name] = CRCFunc
				
				local ICResult = CRCFunc(IntegrityCheck)
				assert(
					ICResult == Item.IntegrityCheck,
					" Integrity Check Failed For CRC: '" .. Item.Name .. "' " .. string.format("Expected: 0x%X Got: 0x%X", Item.IntegrityCheck, ICResult)
				)
				--print("Sucessfully Loaded CRC: '" .. Item.Name .. "'")
			end
			
		end


	end
end




-----------
-- BLAKE --
-----------
do
	local BLAKE2b_BlockLen = 128
	local BLAKE2b_Rounds = 12
	local BLAKE2b_IV = {
		"\8\201\188\243\103\230\9\106", "\59\167\202\132\133\174\103\187",
		"\43\248\148\254\114\243\110\60", "\241\54\29\95\58\245\79\165",
		"\209\130\230\173\127\82\14\81", "\31\108\62\43\140\104\5\155",
		"\107\189\65\251\171\217\131\31", "\121\33\126\19\25\205\224\91"
	}
	local BLAKE2B_Sigma = {
		{0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15},
		{14,10,4,8,9,15,13,6,1,12,0,2,11,7,5,3},
		{11,8,12,0,5,2,15,13,10,14,3,6,7,1,9,4},
		{7,9,3,1,13,12,11,14,2,6,5,10,4,0,15,8},
		{9,0,5,7,2,4,10,15,14,1,11,12,6,8,3,13},
		{2,12,6,10,0,11,8,3,4,13,7,5,15,14,1,9},
		{12,5,1,15,14,13,4,10,0,7,6,3,9,2,8,11},
		{13,11,7,14,12,1,3,9,5,0,15,4,8,6,2,10},
		{6,15,14,9,11,3,0,8,12,2,13,7,1,4,10,5},
		{10,2,8,4,7,6,1,5,15,11,9,14,3,12,13,0},
		{0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15},
		{14,10,4,8,9,15,13,6,1,12,0,2,11,7,5,3}
	}
end




return Hashing