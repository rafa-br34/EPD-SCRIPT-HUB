local HTML = {}

local HTMLHeader = "<!doctype html>"



HTML.LoadDocument = function(Source, RootURL)
	local Document = {}
	
	Document.Source = Source or error("No Source Provided")
	Document.RootURL = RootURL or ""
	Document.Parsed = {}
	
	
	function Document:Parse()
		assert(string.find(string.lower(self.Source), HTMLHeader) == 1, "Invalid HTML Header")
		-- Remove Header
		self.Source = self.Source:sub(#HTMLHeader + 1, #self.Source)
		
		local Todo = #self.Source
		local At = 1
		
		--[[
		0 = None
		1 = Comment
		2 = Tag Ending
		3 = Tag Start
		4 = Tag Next
		5 = Tag String
		--]]
		local ParserMode = 0
		local ModeStack = {}
		local Char = ""
		local Buffer = ""
		
		local function CheckForText(Size, Match)
			if self.Source:sub(At, At + (Size - 1)) == Match then
				At += Size
				return true
			end
		end
		
		local function SubParse(Item)
			-- Remove First '<' And Last '>'
			Item = Item:sub(2, #Item)
			Item = Item:sub(1, #Item - 1)

			-- Check If It Is A Comment
			if Item:find("!--") == 1 then
				-- Remove The '!--' And '--'
				Item = Item:sub(4, #Item)
				Item = Item:sub(1, #Item - 2)

				table.insert(self.Parsed, {Type = "COMMENT", Text = Item})
			elseif Item:find("/") == 1 then
				-- Remove '/'
				Item = Item:sub(2, #Item)

				table.insert(self.Parsed, {Type = "TAG_END", Tag = Item})
			else
				local Object = {Type = "TAG", Tag = "", Info = {}}


				for _, String in pairs(string.split(Item, "\"")) do
					print(String)
				end

				table.insert(self.Parsed, Object)
			end
		end
		
		while At < Todo do
			Char = self.Source:sub(At, At)
			At += 1
			if Char == "<" and ParserMode == 0 then
				-- Check For Comments, Tag Endings, Tags
				if CheckForText(3, "!--") then
					ParserMode = 1 -- Comment
				elseif CheckForText(1, "/") then
					ParserMode = 2 -- Tag Ending
				else
					ParserMode = 3 -- Tag
				end
			else
				-- Comment
				if Char == "-" and CheckForText(2, "->") and ParserMode == 1 then
					print("Comment", Buffer)
					Buffer = ""
					ParserMode = 0
					continue
					
				-- Tag Ending
				elseif Char == ">" and ParserMode == 2 then
					print("TagEnd", Buffer)
					Buffer = ""
					ParserMode = 0
					
				-- String
				elseif Char == "\"" and ParserMode == 4 then
					ParserMode = 5
					continue
				elseif Char == "\\" and ParserMode == 5 then
					At += 1 -- Skip Next
				elseif Char == "\"" and ParserMode == 5 then
					print("String", Buffer)
					Buffer = ""
					ParserMode = 4
					
				-- Tag Name
				elseif Char == " " and ParserMode == 3 then
					print("Tag", Buffer)
					task.wait()
					Buffer = ""
					ParserMode = 4
				elseif Char == ">" and ParserMode == 3 then
					print("Tag", Buffer)
					task.wait()
					Buffer = ""
					ParserMode = 5
					
				-- Tag Items
				elseif Char == " " and ParserMode == 4 then
					print("Item", Buffer)
					Buffer = ""
				end
				
				if ParserMode ~= 0 then
					Buffer ..= Char
				end
			end
			
			
			
		end
		
		for _, i in pairs(self.Parsed) do
			print(i[1], i[2])
		end
	end
	
	--[[
	function Document:Parse()
		assert(string.find(self.Source, HTMLHeader) == 1, "Invalid HTML Header")
		-- Remove Header
		self.Source = self.Source:sub(#HTMLHeader + 1, #self.Source)
		
		for Item in string.gmatch(self.Source, "%b<>") do
			-- Remove First '<' And Last '>'
			Item = Item:sub(2, #Item)
			Item = Item:sub(1, #Item - 1)
			
			-- Check If It Is A Comment
			if Item:find("!--") == 1 then
				-- Remove The '!--' And '--'
				Item = Item:sub(4, #Item)
				Item = Item:sub(1, #Item - 2)
				
				table.insert(self.Parsed, {Type = "COMMENT", Text = Item})
			elseif Item:find("/") == 1 then
				-- Remove '/'
				Item = Item:sub(2, #Item)
				
				table.insert(self.Parsed, {Type = "TAG_END", Tag = Item})
			else
				local Object = {Type = "TAG", Tag = "", Info = {}}
				
				
				for _, String in pairs(string.split(Item, "\"")) do
					print(String)
				end
				
				table.insert(self.Parsed, Object)
			end
		end
	end
	--]]
	
	return Document
end


--return HTML