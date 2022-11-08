local Bitfield = {}

local string_reverse = string.reverse
local string_format = string.format
local string_byte = string.byte
local string_char = string.char
local string_sub = string.sub
local brsh 	= bit32.rshift 	-- >>
local blsh 	= bit32.lshift 	-- <<
local bxor 	= bit32.bxor 	-- ^
local bnot 	= bit32.bnot 	-- !
local band 	= bit32.band 	-- &
local bor 	= bit32.bor 	-- |


function Bitfield.New()
	local BitfieldInstance = newproxy(true)
	
	-- Constants
	local Distance = 31
	local MaxBit = blsh(1, Distance - 1)
	
	
	local BitfieldMeta = nil
	BitfieldMeta = {
		-- Table Of Luau Doubles, Only Use 52 Bits Since More Than That Will Be Rounded
		-- Use A Maximium Of 31 Bits For bit32
		Values52 = {},
		TargetLen = 0,
		
		__len = function(self)
			local Size = 0
			local Values = BitfieldMeta.Values52
			
			if #Values >= 1 then
				Size = ((#Values - 1) * Distance)
				local LastValue = Values[#Values]
				for i=Distance, 0, -1 do
					print(i, blsh(1, i))
					if band(LastValue, blsh(1, i)) == 1 then
						return Size + i
					end
				end
			end
			
			return 0
		end,
		
		__index = function(self, Index)
			return rawget(BitfieldMeta, Index)
		end,
		
		__add = function(self, Value)
			
		end,
		
		
		-----------------
		-- LUA METHODS --
		-----------------
		
		SHR = function(Value)
			print(Value)
		end,
		
		ROR = function(Value)
			print(Value)
		end,
	}
	
	for Name, Value in pairs(BitfieldMeta) do
		getmetatable(BitfieldInstance)[Name] = Value
	end
	
	return BitfieldInstance
end

--[[
local Test = Bitfield.New()
Test.ROR(16) -- Rotate Right
Test.ROL(16) -- Rotate Left

Test.SHL(1) -- Shift Left
Test.SHR(1) -- Shift Right
--]]

return Bitfield