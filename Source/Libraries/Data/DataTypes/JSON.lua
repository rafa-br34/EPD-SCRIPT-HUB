local JSON = {}


local string_gsub = string.gsub
local string_sub = string.sub
local string_byte = string.byte
local table_insert = table.insert
local table_remove = table.remove

function JSON.Encode(Input, CustomEncoders)
	local Buffer = ""
	
	local function EscapeString(String)
		local Filters = {
			{"\\", "\\\\"}, -- \ -> \\
			{"\"", "\\\""}, -- " -> \"
		}
		
		for _, Filter in pairs(Filters) do
			String = string_gsub(String, Filter[1], Filter[2])
		end
		return String
	end
	
	local ItemType = nil
	local function EncodeItem(Item, ItemName, Depth)
		ItemType = typeof(Item)
		
		if ItemName then
			if type(ItemName) == "number" then
				-- [1] -> ["i1"]
				ItemName = "i" .. tostring(ItemName)
			elseif tostring(ItemName):sub(1, 1) == "i" then
				-- ["i1"] -> ["\i1"]
				ItemName = "\\" .. ItemName
			end
			
			Buffer ..= '"' .. EscapeString(ItemName) .. '":'
		end
		
		if ItemType == "nil" then
			Buffer ..= "null"
		elseif ItemType == "number" then
			Buffer ..= tostring(Item)
		elseif ItemType == "string" then
			Buffer ..= '"' .. EscapeString(Item) .. '"'
		elseif ItemType == "boolean" then
			Buffer ..= (Item == true and "true") or "false"
		elseif ItemType == "table" then
			Buffer ..= "{"
			for Name, SubItem in pairs(Item) do
				EncodeItem(SubItem, Name, Depth + 1)
			end
			-- Remove Trailing ","
			-- Faster Than Iterating The Dictionary Just To Get The Size
			Buffer = string_sub(Buffer, 0, #Buffer - 1)
			
			Buffer ..= "}"
		else
			for _, Encoder in pairs(CustomEncoders) do
				if Encoder.Type == ItemType then
					Buffer ..= string_gsub(EscapeString(Encoder.Encode(Item, Depth)), ",", "\\,")
					break
				end
			end
		end
		
		-- Add Trailing Comma If Needed
		Buffer ..= (Depth > 0 and ",") or ""
	end
	
	EncodeItem(Input, nil, 0)
	return Buffer
end



--------------
-- DECODING --
--------------

--------------------
-- INITIALIZATION --
--------------------
local function NewSet(...)
	local Result = {}
	for Index=1, select("#", ...) do
		Result[select(Index, ...)] = true
	end
	return Result
end

local Sets_SpaceChars	= NewSet(" ", "\t", "\r", "\n")
local Sets_DelimChars	= NewSet(" ", "\t", "\r", "\n", "]", "}", ",")
local Sets_EscapeChars	= NewSet("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local Sets_Literals		= NewSet("true", "false", "null")

JSON.ParseItem = nil

local LiteralMap = {
	["true"] = true,
	["false"] = false,
	["null"] = nil,
}

local function NextChar(String, Index, TargetSet, Negate)
	for i=Index, #String do
		if TargetSet[String:sub(i, i)] ~= Negate then
			return i
		end
	end
	return #String + 1
end

local function DecodeError(String, At, Error)
	local CharIndex = 0
	local RowIndex = 1 -- Line Will Always Start At 1
	local Char = ""
	for Index=1, At do
		if String:sub(Index, Index) == "\n" then
			CharIndex = 0
			RowIndex += 1
		else
			CharIndex += 1
		end
	end
	error(Error .. string.format(" At Character: %d Line: %d", CharIndex - 1, RowIndex))
end


local function CodepointToUTF8(Code)
	local Floor = math.floor
	if Code <= 0x7F then 			-- 1 Byte UTF-8
		return string.char(
			Code
		)
	elseif Code <= 0x7FF then 		-- 2 Byte UTF-8
		return string.char(
			Floor(Code / 0x40) + 0xC0,
			Code % 0x40 + 0x80
		)
	elseif Code <= 0xFFFF then 	-- 3 Byte UTF-8
		return string.char(
			Floor(Code / 0x1000) + 0xF0,
			Floor(Code % 0x1000 / 0x40) + 0x80,
			Code % 0x40 + 0x80
		)
	elseif Code <= 0x10FFFF then 	-- 4 Byte UTF-8
		return string.char(
			Floor(Code / 0x40000) + 0xF0,
			Floor(Code % 0x40000 / 0x1000) + 0x80,
			Floor(Code % 0x1000 / 0x40) + 0x80,
			Code % 0x40 + 0x80
		)
	end
	error("Invalid Unicode Codepoint '" .. tostring(Code) .. "'")
end

local function ParseUnicodeEscape(String)
	local Number1 = tonumber(String:sub(1, 4), 16)
	local Number2 = tonumber(String:sub(7, 10), 16)
	
	-- Surrogate Pair?
	if Number2 then
		return CodepointToUTF8((Number1 - 0xD800) * 0x400 + (Number2 - 0xDC00) + 0x10000)
	else
		return CodepointToUTF8(Number1)
	end
end


local EscapeChars = {
	["\""] = "\"",
	["\\"] = "\\",
	["\n"] = "\n",
	["\r"] = "\r",
	["\b"] = "\b",
	["\f"] = "\f",
	["\t"] = "\t",
}

local function ParseString(String, Index)
	-- Check If Start Contains Double Quotes
	if String:sub(Index, Index) == "\"" then
		Index = Index + 1
	end
	
	
	local Checkpoint = Index
	local Result = ""
	
	local Char = ""
	while Index < #String do
		Char = String:sub(Index, Index)
		
		
		
		if Char == "\\" then -- Escape Char
			-- Save What We Parsed Until Now And Ignore The '\'
			Result ..= String:sub(Checkpoint, Index - 1)
			Index += 1
			
			-- Escape Char
			Char = String:sub(Index, Index)
			if Char == "u" then
				Index += 1
				
				-- Get UTF-8 Value
				local UnicodeValue =
					String:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", Index)
					or String:match("^%x%x%x%x", Index)
					or DecodeError(String, Index, "Invalid Unicode Escape In String")
				
				Result ..= ParseUnicodeEscape(UnicodeValue)
				
				Index += #UnicodeValue
			else
				if not EscapeChars[Char] then
					DecodeError(String, Index, "Invalid Escape '\\" .. Char .. "' In String")
				end
				Result ..= EscapeChars[Char]
			end
			Checkpoint = Index + 1
			
		elseif Char == "\"" then -- End Of String
			Result ..= String:sub(Checkpoint, Index - 1)
			return Result, Index + 1
		end
		
		Index += 1
	end
end

local function ParseNumber(String, Index)
	local NumberEnd = NextChar(String, Index, Sets_DelimChars)
	local NumberString = String:sub(Index, NumberEnd - 1)
	local Number = tonumber(NumberString)
	if not Number then
		DecodeError(String, Index, "Invalid Number '" .. NumberString .. "'")
	end
	return Number, NumberEnd
end

local function ParseLiteral(String, Index)
	local LiteralEnd = NextChar(String, Index, Sets_DelimChars)
	local Literal = String:sub(Index, LiteralEnd - 1)
	if not Sets_Literals[Literal] then
		DecodeError(String, Index, "Invalid Literal '" .. Literal .. "'")
	end
	return LiteralMap[Literal], LiteralEnd
end

local function ParseArray(String, Index, DecodersList)
	-- Check If Start Contains Opening Bracket
	if String:sub(Index, Index) == "[" then
		Index = Index + 1
	end
	
	local Stack = {}
	local StackIndex = 1
	local Char = ""
	
	local Object = nil
	while true do
		
		Index = NextChar(String, Index, Sets_SpaceChars, true)
		
		-- Empty/End Of The Array?
		if String:sub(Index, Index) == "]" then
			Index = Index + 1
			break
		end
		
		-- Read Object
		Object, Index = JSON.ParseItem(String, Index, DecodersList)
		Stack[StackIndex] = Object
		StackIndex += 1
		
		-- Next Object
		Index = NextChar(String, Index, Sets_SpaceChars, true)
		Char = String:sub(Index, Index)
		Index += 1
		if Char == "]" then break end
		if Char ~= "," then DecodeError(String, Index, "Expected ']' Or ',' Got '" .. tostring(Char) .. "'") end
	end
	return Stack, Index
end

local function ParseObject(String, Index, DecodersList)
	-- Check If Start Contains Opening Brace
	if String:sub(Index, Index) == "{" then
		Index = Index + 1
	end
	
	local Result = {}
	local Token, Value = nil, nil
	local Char = ""
	
	while true do
		
		Index = NextChar(String, Index, Sets_SpaceChars, true)
		
		-- Empty/End Of Object?
		if String:sub(Index, Index) == "}" then
			Index = Index + 1
			break
		end
		
		-- Read Token
		if String:sub(Index, Index) ~= "\"" then
			DecodeError(String, Index, "Expected String As Token")
		end
		
		Token, Index = JSON.ParseItem(String, Index, DecodersList)
		
		-- Read ":" Delimiter
		Index = NextChar(String, Index, Sets_SpaceChars, true)
		Char = String:sub(Index, Index)
		if Char ~= ":" then
			DecodeError(String, Index, "Expected ':' After Token Got '" .. tostring(Char) .. "'")
		end
		
		Index = NextChar(String, Index + 1, Sets_SpaceChars, true)
		
		-- Read value
		Value, Index = JSON.ParseItem(String, Index, DecodersList)
		
		-- Write Object
		Result[Token] = Value
		
		-- Next token
		Index = NextChar(String, Index, Sets_SpaceChars, true)
		
		Char = String:sub(Index, Index)
		Index += 1
		
		if Char == "}" then break end
		if Char ~= "," then DecodeError(String, Index,  "Expected '}' Or ',' Got '" .. tostring(Char) .. "'") end
	end
	return Result, Index
end


local InterpretationList = {
	["\""] = ParseString,
	["0"] = ParseNumber,
	["1"] = ParseNumber,
	["2"] = ParseNumber,
	["3"] = ParseNumber,
	["4"] = ParseNumber,
	["5"] = ParseNumber,
	["6"] = ParseNumber,
	["7"] = ParseNumber,
	["8"] = ParseNumber,
	["9"] = ParseNumber,
	["-"] = ParseNumber,
	["t"] = ParseLiteral,
	["f"] = ParseLiteral,
	["n"] = ParseLiteral,
	["["] = ParseArray,
	["{"] = ParseObject,
}


JSON.ParseItem = function(String, Index, ExtraList)
	local Char = String:sub(Index, Index)
	local Function = InterpretationList[Char] or ExtraList[Char]
	if Function then
		return Function(String, Index, ExtraList) -- We Need To Maintain The Decoders List
	end
	DecodeError(String, Index, "No Decoder For Trigger '" .. Char .. "'")
end


--[[
	Decodes Some Table That Is In JSON Format
	
	Input<String> The String To Decode
	CustomDecoders<Table> Custom Decoders Table, Index Should Be The Trigger Char, Example:
	{
		["<"] = function(String, Index, DecoderList)
			-- Decode The "<..." Part To Something, Return The Index To The Next Character
			-- If JSON.ParseItem Needs To Be Called Send The String, Current Index, And DecoderList
			return Result, Index
		end
	}
--]]
function JSON.Decode(Input, CustomDecoders)
	CustomDecoders = CustomDecoders or {}
	
	if type(Input) ~= "string" then
		error("Expected string Got " .. type(Input))
	end
	
	local Result, Index = JSON.ParseItem(Input, NextChar(Input, 1, Sets_SpaceChars, true), CustomDecoders)
	Index = NextChar(Input, Index, Sets_SpaceChars, true)
	if Index <= #Input then
		DecodeError(Input, Index, "Bad Trailing")
	end
	return Result
end


--[[
	Post Process Decoded Tables That Where Encoded With JSON.Encode
--]]
function JSON.PostProcess(Table)
	local TodoTables = {Table}
	
	local function CleanTable(Input)
		for Index, Value in pairs(Input) do
			if type(Index) ~= "string" then continue end
			
			if Index:sub(1, 1) == "i" then
				Input[tonumber(Index:sub(2, #Index))] = Value
				Input[Index] = nil
			elseif Index:sub(1, 1) == "\\" then
				Input[Index:sub(2, #Index)] = Value
				Input[Index] = nil
			elseif tonumber(Index) then
				Input[tonumber(Index)] = Value
				Input[Index] = nil
			end
			if type(Value) == "table" then
				table_insert(TodoTables, Value)
			end
		end
	end
	
	while 0 < #TodoTables do
		CleanTable(table_remove(TodoTables, #TodoTables))
	end
	
	return Table
end


return JSON