-- Constants
-- Github Root Path And Path To BaseLibrary
local c_RootPath = "https://raw.githubusercontent.com/rafa_br34/EPD-SCRIPT-HUB/main/Source/"
local c_BaseLib = "Libraries/BaseLibrary.lua"

-- Default Global Environment, Can Be _G Or getgenv(), If Changed Here Change In Other Scripts Too
local c_GlobalEnv = (((getgenv and getgenv()) or _G)["EPD_GENV_REF"] or _G)

-- Default Script List If There Isn't Any Stored
local c_DefaultScripts = {
	Utils = {
		{"Explorer", "Scripts/Explorer.lua", "REL"}
	},

	OtherUtils = {
		{"Hydroxide", "local owner='Upbolt';local branch='revision';local function webImport(file)return loadstring(game:HttpGetAsync((\"https://raw.githubusercontent.com/%s/Hydroxide/%s/%s.lua\"):format(owner,branch,file)),file..'.lua')()end;webImport(\"init\")webImport(\"ui/main\")", "SRC"},
		{"Infinite Yeild", "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source", "URL"},
	},

	Cheats = {
		{"Universal ESP", "Scripts/UniversalESP.lua", "REL"}
	}

}

-- File Paths
local c_Files = {
	["SCRIPTS"] = "EPD/Scripts.json"
}

-- List Of Exploits That Are Supported
local c_Exploits = {
	{
		Name = "Synapse X",
		Checksums = {0x282CD0F6, 0x8C763513},
		IID = 1
	}
}


local c_ScriptButtonSize = UDim2.new(1, 0, 0, 18)


local c_VisualScheme = {
	Borders = Color3.new(1, 1, 1),
	Background = Color3.fromRGB(30, 30, 30),
	Text = Color3.new(1, 1, 1),
	Disabled = Color3.fromRGB(100, 100, 100),

	Selector = {
		SelectedTransparency = 0.6,
		OutTransparency = 1,
		Idle = Color3.fromRGB(100, 100, 100),
		Select = Color3.fromRGB(100, 255, 100),
		Delete = Color3.fromRGB(255, 100, 100),
		Loading = Color3.fromRGB(255, 255, 100)
	},
	ScriptList = {
		LabelBackground = Color3.fromRGB(60, 60, 60),
		ButtonBackground = Color3.fromRGB(50, 50, 50),

		Text = Color3.new(1, 1, 1),

		ToolbarButtons = {
			AddScript = Color3.fromRGB(100, 185, 255),
			RemoveScript = Color3.fromRGB(100, 185, 255), -- 255, 65, 65
			MoveUp = Color3.fromRGB(185, 255, 100),
			MoveDown = Color3.fromRGB(185, 255, 100),
			Configs = Color3.fromRGB(200,200,200),
			Execute = Color3.fromRGB(0, 255, 60)
		}
	}
}
local c_TransparencyTweening = TweenInfo.new(
	0.5,
	Enum.EasingStyle.Quint,
	Enum.EasingDirection.InOut
)
local c_SelectorTweening = TweenInfo.new(
	0.5,
	Enum.EasingStyle.Quart,
	Enum.EasingDirection.Out
)
local c_EffectsTweening = TweenInfo.new(
	0.5,
	Enum.EasingStyle.Quint,
	Enum.EasingDirection.InOut
)



-- Services
local g_UserInputSerivce 	= game:GetService("UserInputService")
local g_TweenService 		= game:GetService("TweenService")
local g_RunService 			= game:GetService("RunService")
local g_CoreGui 			= game:GetService("CoreGui")

-- Localized
local string_sub = string.sub
local table_remove = table.remove
local table_insert = table.insert


-- Uninitialized
local u_Connections = {}
local u_Scripts = {}
local u_HostExploit = {
	Name = "Unknown",
	Checksums = {}
}

local HttpGet = (c_GlobalEnv.EPD or {}).HttpGet
	-- Just In Case Loader.lua Is Executed Manually
	or httpget or http_get
	or (syn 			and function(Link) return syn.request({Url = Link, Method = "GET"}).Body end)
	or (game.HttpGet 	and function(Link) return game:HttpGet(Link) end)
	or error("No HTTP Get Function.")


-- Functions
local function LoadScript(ScriptSource)
	local LoadedFunction = loadstring(ScriptSource)
	if type(LoadedFunction) == "function" then
		local Success, Returned = pcall(LoadedFunction)
		if Success then
			return Returned
		end
	end

	return false
end

local RandGen = Random.new(os.clock())
local function SecureGui(Gui)

	local Dict = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

	local function RandomString(Len)
		Len = Len or 25
		local Buffer = ""
		local RandIndex = 0


		for _=1, Len do
			RandIndex = RandGen:NextNumber() * Len
			Buffer ..= string_sub(Dict, RandIndex, RandIndex)
		end

		return Buffer
	end

	Gui.Name = RandomString(RandGen:NextInteger(15, 30))
end



--------------------
-- BASE LIB SETUP --
--------------------
do
	if not ((getgenv and getgenv()) or _G)["EPD_GENV_REF"] then
		((getgenv and getgenv()) or _G)["EPD_GENV_REF"] = _G
	end

	c_GlobalEnv.EPD = c_GlobalEnv.EPD or {}
	local EPDTable = c_GlobalEnv.EPD

	EPDTable.BaseLib = EPDTable.BaseLib or LoadScript(HttpGet(c_RootPath .. c_BaseLib))

	EPDTable.BaseLib.RootPath = c_RootPath
	EPDTable.BaseLib.Exploit = u_HostExploit

	if not c_GlobalEnv.EPD.BaseLib.IsFolder("EPD") then
		c_GlobalEnv.EPD.BaseLib.CreateFolder("EPD")
	end
end

-- Modules
local m_Hashing = c_GlobalEnv.EPD.BaseLib.LoadLibrary("Libraries/Data/Hashing")
local m_JSON = c_GlobalEnv.EPD.BaseLib.LoadLibrary("Libraries/Data/Types/JSON")

-----------------------
-- LOAD SCRIPTS LIST --
-----------------------
local l_SaveScriptList = error
do
	local ScriptsFile = c_GlobalEnv.EPD.BaseLib.GetFile(c_Files["SCRIPTS"])
	if ScriptsFile then
		u_Scripts = m_JSON.PostProcess(m_JSON.Decode(ScriptsFile))
	else
		u_Scripts = c_DefaultScripts
	end
	
	l_SaveScriptList = function()
		c_GlobalEnv.EPD.BaseLib.WriteFile(c_Files["SCRIPTS"], m_JSON.Encode(u_Scripts))
	end
end

-------------------------
-- DEBUGGING FUNCTIONS --
-------------------------
local DBGLOG, DBGWARN
do
	--c_GlobalEnv.EPD.DEBUG = true
	if c_GlobalEnv.EPD.DEBUG then
		DBGLOG = function(...)
			print(...)
		end
		DBGWARN = function(...)
			warn(...)
		end
	else
		DBGLOG = function() end
		DBGWARN = function() end
	end
end

-----------------------
-- EXPLOIT DETECTION --
-----------------------
do

	local getgenv = getgenv or error("No Get Global Env(getgenv) Function")


	local function MakeExploitEnvString(Env)
		local Result = ""
		local Queue = {Env}
		local ForbiddenItems = {"_G", "EPD"}
		local AllowedTypes = {"function", "table"}

		local Table = nil
		local Type = nil
		while #Queue > 0 do
			Table = table.remove(Queue, 1)
			for Name, Item in next, Table do
				if type(Name) ~= "string" then continue end
				Type = type(Item)

				if table.find(ForbiddenItems, Item) then
					continue
				end

				if table.find(AllowedTypes, Type) then
					if Type == "table" then
						table.insert(Queue, Item)
					end
					Result = Result .. Name .. "<"..Type .. ">"
				end
			end
		end

		return Result
	end

	local Env = getgenv()
	local PossibleExploits = {
		1, -- Synapse
	}

	-- Manual Checks
	do
		-- Synapse Check
		if not Env.syn then
			table.remove(PossibleExploits, table.find(PossibleExploits, 1))
		else
			Env = Env.syn -- Only Scan Env.syn Validity
		end
	end

	local Checksum = m_Hashing.CRC.CRC32(MakeExploitEnvString(Env))
	--setclipboard(string.format("0x%X", Checksum))

	-- Do The Detection
	do
		-- Save Checksum In Case The Exploit Is Unknown
		u_HostExploit.Checksums = {Checksum}
		for _, Exploit in pairs(c_Exploits) do
			if table.find(Exploit.Checksums, Checksum) then
				u_HostExploit = Exploit
			end
		end
	end
end

--------------
-- MAIN GUI --
--------------
do
	-- Uninitialized Locals
	local l_IsInsideScripts = false
	local l_ScriptsButtons = {}
	local l_ApplyTween = {}
	local l_LockSelector = false
	
	-- Uninitialized Functions
	local l_SetSelectorTarget = nil
	local l_SetToolbarButton = nil
	local l_MoveSelected = nil
	
	
	local l_Selected = {Button = nil, Execute = nil, DescriptorRef = nil}
	local l_ScriptToolbarButtons = {}

	-- Functions
	function RoundGui(GUI, Rounding: UDim)
		local RoundUI = Instance.new("UICorner", GUI)
		RoundUI.CornerRadius = Rounding
		return RoundUI
	end

	local function NewInstance(ClassName, Settings, Parent)
		local Created = Instance.new(ClassName)
		for Name, Value in pairs(Settings) do
			Created[Name] = Value
		end
		Created.Parent = Parent
		return Created
	end

	local function AddToApplyTweenList(Item)
		table_insert(l_ApplyTween, {Item, Item.Transparency})
	end

	local function SetTransparency(Value: number, UseTween: boolean)
		if not UseTween then
			for _, Item in pairs(l_ApplyTween) do
				Item[1].BackgroundTransparency = (Item[2] > Value and Item[2]) or Value
			end
		else
			for _, Item in pairs(l_ApplyTween) do
				g_TweenService:Create(Item[1], c_TransparencyTweening, {BackgroundTransparency = (Item[2] > Value and Item[2]) or Value}):Play()
			end
		end
	end

	------------------------
	-- GUI INITIALIZATION --
	------------------------
	local
	ScriptsSelectionFrame,
	ToolbarMenu,
	CloseButton,
	MainFrame,
	ScriptList,
	Core

	local
	SecureCore -- <Boolean> true If syn.protect Was Used

	do
		Core = NewInstance("ScreenGui", {IgnoreGuiInset = true})
		SecureGui(Core)
		if syn and syn.protect_gui and syn.unprotect_gui then
			syn.protect_gui(Core)
			SecureCore = true
		end

		MainFrame = NewInstance("Frame", {
			Size = UDim2.new(0.5, 0, 0.45, 0),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = c_VisualScheme.Background,
			BorderColor3 = Color3.new(1, 1, 1),
			ClipsDescendants = true,
			BorderSizePixel = 2
		}, Core)
		SecureGui(MainFrame)
		AddToApplyTweenList(MainFrame)

		local InfoFrame = NewInstance("Frame", {
			Size = UDim2.new(1, 0, 0, 29),
			Position = UDim2.new(0, 0, 1, 0),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = c_VisualScheme.Background,
			BorderColor3 = Color3.new(1, 1, 1),
		}, MainFrame)
		SecureGui(InfoFrame)
		AddToApplyTweenList(InfoFrame)

		local InfoFrameListLayout = NewInstance("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2)
		}, InfoFrame)
		SecureGui(InfoFrameListLayout)

		local InfoSubFrame = NewInstance("Frame", {
			Size = UDim2.new(1, -80, 1, 0),
			Position = UDim2.new(0, 0, 1, 0),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,
		}, InfoFrame)
		SecureGui(InfoSubFrame)

		CloseButton = NewInstance("TextButton", {
			Size = UDim2.new(0, 80, 1, 0),
			Font = Enum.Font.Ubuntu,
			TextColor3 = c_VisualScheme.Text,
			BackgroundColor3 = c_VisualScheme.Background,
			BorderColor3 = c_VisualScheme.Borders,
			Text = "Close",
			TextScaled = true,
			Active = false
		}, InfoFrame)
		SecureGui(CloseButton)

		ScriptList = NewInstance("ScrollingFrame", {
			Size = UDim2.new(0.3, 0, 1, -50),
			TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
			BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
			CanvasSize = UDim2.new(0, 0, 0, 0),
			VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Left,
			BackgroundColor3 = c_VisualScheme.Background,
			BorderColor3 = c_VisualScheme.Borders,
			ScrollBarThickness = 3
		}, MainFrame)
		SecureGui(ScriptList)
		AddToApplyTweenList(ScriptList)

		local ScriptsListLayout = NewInstance("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.Name,
			Padding = UDim.new(0, 2)
		}, ScriptList)
		SecureGui(ScriptsListLayout)

		ScriptsSelectionFrame = NewInstance("Frame", {
			Size = UDim2.new(ScriptList.Size.X.Scale, 0, 0, c_ScriptButtonSize.Y.Offset),
			Position = UDim2.new(-1, 0, 0, 0),
			BackgroundColor3 = c_VisualScheme.Selector.Idle,
			BorderSizePixel = 0,
			BackgroundTransparency = c_VisualScheme.Selector.OutTransparency,
			ZIndex = 1
		}, MainFrame)
		SecureGui(ScriptsSelectionFrame)
		AddToApplyTweenList(ScriptsSelectionFrame)

		ToolbarMenu = NewInstance("Frame", {
			Size = UDim2.new(ScriptList.Size.X.Scale, 0, 0, 20),
			BorderSizePixel = 1,
			BorderColor3 = c_VisualScheme.Borders,
			BackgroundColor3 = c_VisualScheme.Background,
			Position = UDim2.new(0, 0, 1, -30),
			AnchorPoint = Vector2.new(0, 1)
		}, MainFrame)
		SecureGui(ToolbarMenu)

		local ScriptsEditMenuLayout = NewInstance("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0)
		}, ToolbarMenu)
		SecureGui(ScriptsEditMenuLayout)

		local ExploitLabel = NewInstance("TextLabel", {
			Size = UDim2.new(0, ScriptList.AbsoluteSize.X, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.Ubuntu,
			TextColor3 = c_VisualScheme.Text,
			AutomaticSize = Enum.AutomaticSize.X,
			Text = "Exploit: " .. u_HostExploit.Name,
			TextSize = 15
		}, InfoSubFrame)
		SecureGui(ExploitLabel)
	end


	---------------------
	-- TOOLBAR BUTTONS --
	---------------------
	do
		local c_ToolbarButtons = {
			{
				Image = "rbxassetid://3926307971",
				Buttons = {
					{"AddScript", Vector2.new(324, 364)},
					{"RemoveScript", Vector2.new(884, 284)},
					{"MoveUp", Vector2.new(164, 524)},
					{"MoveDown", Vector2.new(204, 484)},
				}
			},
			{
				Image = "rbxassetid://3926305904",
				Buttons = {
					{"Configs", Vector2.new(4, 124)},
					{"Execute", Vector2.new(644, 204)}
				}
			}
		}


		local Config = {
			Size = UDim2.new(1, 0, 1, 0),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundTransparency = 1,
			ImageRectSize = Vector2.new(36, 36)
		}


		for _, ButtonSet in pairs(c_ToolbarButtons) do
			Config.Image = ButtonSet.Image
			for _, Button in pairs(ButtonSet.Buttons) do
				Config.ImageRectOffset = Button[2]
				Config.ImageColor3 = c_VisualScheme.Disabled
				l_ScriptToolbarButtons[Button[1]] = NewInstance("ImageButton", Config, ToolbarMenu)
			end
		end
	end


	-----------------------------
	-- BUTTONS & SELECTOR ANIM --
	-----------------------------
	do
		local l_YOffset = math.round((ScriptsSelectionFrame.AbsoluteSize.Y - c_ScriptButtonSize.Y.Offset) / 2)
		DBGLOG(l_YOffset)
		local l_TargetCurrentTween = nil
		local l_LastTweenTarget = nil

		local l_RunnerConnection = nil


		l_SetSelectorTarget = function(Target, Refresh, SkipAnim, IgnoreLock)
			if (not Refresh and not IgnoreLock) and (l_LastTweenTarget == Target or l_LockSelector) then return end
			if l_TargetCurrentTween then
				l_TargetCurrentTween:Cancel()
				l_TargetCurrentTween = nil
			end

			if Refresh then
				Target = l_Selected.Button
			end

			if Target then
				local NewPos = (Target.AbsolutePosition - MainFrame.AbsolutePosition) - Vector2.new(0, l_YOffset)
				local NewPos = Vector2.new(math.round(NewPos.X), math.round(NewPos.Y))
				
				if SkipAnim or l_LastTweenTarget == nil then
					ScriptsSelectionFrame.Position = UDim2.new(0, NewPos.X, 0, NewPos.Y)
				end


				l_TargetCurrentTween = g_TweenService:Create(
					ScriptsSelectionFrame,
					c_SelectorTweening,
					{BackgroundTransparency = c_VisualScheme.Selector.SelectedTransparency, Position = UDim2.new(0, NewPos.X, 0, NewPos.Y)}
				)
				l_TargetCurrentTween:Play()
			else
				l_TargetCurrentTween = g_TweenService:Create(
					ScriptsSelectionFrame,
					c_SelectorTweening,
					{BackgroundTransparency = c_VisualScheme.Selector.OutTransparency}
					--{Position = UDim2.new(-1, 0, 0, (l_LastTweenTarget.AbsolutePosition.Y - MainFrame.AbsolutePosition.Y) - l_YOffset)}
				)
				l_TargetCurrentTween:Play()
			end
			l_LastTweenTarget = Target
			
			
		end

		local function StartRunner()
			if l_RunnerConnection then return end
			local LastMousePos = 0
			local Debounce = false

			l_RunnerConnection = g_RunService.Heartbeat:Connect(function()
				if Debounce then return end
				Debounce = true
				if l_IsInsideScripts == false then
					l_RunnerConnection:Disconnect()
					l_RunnerConnection = nil
				end

				local MousePos = g_UserInputSerivce:GetMouseLocation().Y - 36
				if true or LastMousePos ~= MousePos then
					local Lower = {Button = nil, Score = math.huge}
					for _, Button in pairs(l_ScriptsButtons) do
						if not Button.Visible then continue end

						local Dist = MousePos - (Button.AbsolutePosition.Y + (Button.AbsoluteSize.Y / 2))
						if Dist < 0 then Dist = Dist*-1 end
						if Dist < Lower.Score then
							Lower.Button = Button
							Lower.Score = Dist
						end


					end

					if Lower.Score < 20 then
						l_SetSelectorTarget(Lower.Button)
					else
						l_SetSelectorTarget(nil)
					end


					LastMousePos = MousePos
				end
				Debounce = false
			end)
		end

		table_insert(u_Connections, ScriptList.MouseEnter:Connect(function()
			l_IsInsideScripts = true
			StartRunner()
		end))

		table_insert(u_Connections, ScriptList.MouseLeave:Connect(function()
			l_IsInsideScripts = false
			l_RunnerConnection:Disconnect()
			l_RunnerConnection = nil
			l_SetSelectorTarget(nil)
		end))

		table_insert(u_Connections, CloseButton.MouseButton1Click:Connect(function()
			for _, Conn in pairs(u_Connections) do
				Conn:Disconnect()
			end
			if SecureCore then
				syn.unprotect_gui(Core)
			end
			Core:Destroy()
		end))
	end

	-------------------------
	-- LOAD & LINK SCRIPTS --
	-------------------------
	do
		l_SetToolbarButton = function(State, Name)
			local Target = l_ScriptToolbarButtons[Name]
			if State then
				g_TweenService:Create(Target, c_EffectsTweening, {ImageColor3 = c_VisualScheme.ScriptList.ToolbarButtons[Name]}):Play()
			else
				g_TweenService:Create(Target, c_EffectsTweening, {ImageColor3 = c_VisualScheme.Disabled}):Play()
			end

		end


		local function SetSelectedButton(Button, LoaderLambda, DescriptorRef)
			-- Same Button? Unselect
			if Button == l_Selected.Button then
				g_TweenService:Create(ScriptsSelectionFrame, c_EffectsTweening, {BackgroundColor3 = c_VisualScheme.Selector.Idle}):Play()
				l_Selected.Button = nil
				l_Selected.Execute = nil
				l_Selected.DescriptorRef = nil
				l_LockSelector = false
				l_SetToolbarButton(false, "Execute")
				l_SetToolbarButton(false, "Configs")
				l_SetToolbarButton(false, "MoveUp")
				l_SetToolbarButton(false, "MoveDown")
				return
			end

			l_LockSelector = false
			l_SetSelectorTarget(Button)
			
			l_Selected.Button = Button
			l_Selected.Execute = LoaderLambda
			l_Selected.DescriptorRef = DescriptorRef
			l_LockSelector = true
			
			l_SetToolbarButton(true, "Execute")
			l_SetToolbarButton(true, "Configs")
			
			if l_MoveSelected(false, true) == 2 then
				l_SetToolbarButton(false, "MoveDown")
			else
				l_SetToolbarButton(true, "MoveDown")
			end
			if l_MoveSelected(true, true) == 2 then
				l_SetToolbarButton(false, "MoveUp")
			else
				l_SetToolbarButton(true, "MoveUp")
			end
			
			
			
			g_TweenService:Create(ScriptsSelectionFrame, c_EffectsTweening, {BackgroundColor3 = c_VisualScheme.Selector.Select}):Play()
		end


		-----------------------------
		-- CREATE BUTTONS & LABELS --
		-----------------------------
		local l_RebuildGui = nil

		do
			-- TODO: New Tweening Approach
			local function SetLabel(Label, Dropdowns, State)
				Dropdowns[1].Rotation = (State and 0) or -90
				Dropdowns[2].Rotation = (State and 0) or 90

				for Name, Button in pairs(Label:GetChildren()) do
					if Button.ClassName == "TextButton" and not Button:FindFirstChildOfClass("ImageLabel") then
						if l_Selected.Button == Button then
							SetSelectedButton(Button)
						end
						Button.Visible = State
					end
				end
			end

			local function CreateDropdown(Text, InitialState, StatesTable, IdName)
				local DropdownFrame = NewInstance("Frame", {
					Size = UDim2.new(1, 0, 0, 15),
					AutomaticSize = Enum.AutomaticSize.Y,
					BorderSizePixel = 0,
					Transparency = 1
				}, ScriptList)

				NewInstance("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 1)
				}, DropdownFrame)

				local LabelShown = InitialState
				local LabelButton = NewInstance("TextButton", {
					Text = Text,
					TextScaled = true,
					Name = tostring(IdName),
					Size = UDim2.new(1, 0, 0, 15),
					TextColor3 = c_VisualScheme.Text,
					Font = Enum.Font.Ubuntu,
					BackgroundColor3 = c_VisualScheme.ScriptList.LabelBackground,
					BorderSizePixel = 0,
					ZIndex = 2,
					AutoButtonColor = false,
					AnchorPoint = Vector2.new(0.5, 0.5)
				}, DropdownFrame)
				AddToApplyTweenList(LabelButton)

				-- Side Dropdown Arrows
				local
				Arrow1, Arrow2

				do
					local c_Info = {
						Image = "rbxassetid://3926307971",
						ImageColor3 = c_VisualScheme.Borders,
						ImageRectOffset = Vector2.new(324, 524),
						ImageRectSize = Vector2.new(36, 36),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.new(0, 15, 0, 15),
						ZIndex = 2,
						BackgroundTransparency = 1,
						BorderSizePixel = 0
					}
					Arrow1 = NewInstance("ImageLabel", c_Info, LabelButton)
					Arrow2 = NewInstance("ImageLabel", c_Info, LabelButton)

					Arrow1.Position = UDim2.new(0, 10, 0.5, 0)
					Arrow1.Rotation = (InitialState and 0) or -90
					Arrow2.Position = UDim2.new(1, -10, 0.5, 0)
					Arrow2.Rotation = (InitialState and 0) or 90
				end

				LabelButton.MouseButton1Click:Connect(function()
					LabelShown = not LabelShown
					StatesTable[Text] = LabelShown
					SetLabel(DropdownFrame, {Arrow1, Arrow2}, LabelShown)
					task.wait()
					l_SetSelectorTarget(nil, true, true)
				end)

				return LabelButton
			end

			local function CreateButton(ScriptInfo, StartState, Label, Base)
				local Button = Base or Instance.new("TextButton", Label)
				Button.Text = ScriptInfo[1] -- Name
				Button.TextScaled = true
				Button.Font = Enum.Font.Ubuntu
				Button.Size = c_ScriptButtonSize
				Button.TextColor3 = c_VisualScheme.ScriptList.Text
				Button.BackgroundTransparency = 0.5
				Button.BackgroundColor3 = c_VisualScheme.ScriptList.ButtonBackground
				Button.AnchorPoint = Vector2.new(0.5, 0.5)
				Button.BorderSizePixel = 0
				Button.ZIndex = 2
				Button.AutoButtonColor = false
				Button.Visible = (StartState and true) or false
				AddToApplyTweenList(Button)
				table_insert(l_ScriptsButtons, Button)

				local ExecutionLambda = function() error("Execution Lambda Not Registered") end

				if ScriptInfo[3] == "REL" then
					ExecutionLambda = function()
						return LoadScript(HttpGet(c_RootPath .. ScriptInfo[2]))
					end
				elseif ScriptInfo[3] == "URL" then
					ExecutionLambda = function()
						return LoadScript(HttpGet(ScriptInfo[2]))
					end
				elseif ScriptInfo[3] == "SRC" then
					ExecutionLambda = function()
						return LoadScript(ScriptInfo[2])
					end
				end

				table_insert(u_Connections, Button.MouseButton1Click:Connect(function()
					SetSelectedButton(Button, ExecutionLambda, ScriptInfo)
				end))

				return Button
			end


			local StatesTable = {} -- Keep Track Of In What State The Dropdowns Are Currently In
			local DropdownTable = {} -- Keep A List Of The Labels

			l_RebuildGui = function()
				
				-- Destroy All Dropdowns
				for _, Dropdown in pairs(DropdownTable) do
					Dropdown.Parent:Destroy()
				end
				
				local BuildHeight = 0
				
				for SectionName, ItemVal in pairs(u_Scripts) do
					if type(SectionName) ~= "number" then
						DropdownTable[SectionName] = CreateDropdown(SectionName, StatesTable[SectionName], StatesTable, BuildHeight)

						for _, Script in pairs(ItemVal) do
							local NewButton = CreateButton(
								Script,
								StatesTable[SectionName],
								DropdownTable[SectionName].Parent
							)
							if l_Selected.Button and Script[1] == l_Selected.Button.Text then
								task.spawn(function()
									task.wait()
									l_SetSelectorTarget(NewButton, false, true, true)
								end)
							end
						end

						BuildHeight += 1
					end
				end
			end

			l_RebuildGui()
		end



		---------------------
		-- TOOLBAR BUTTONS --
		--------------------
		do
			local ExecutionDebounce = false
			table_insert(u_Connections, l_ScriptToolbarButtons["Execute"].MouseButton1Click:Connect(function()
				if ExecutionDebounce then return end
				ExecutionDebounce = true
				if l_LockSelector == true and l_Selected.Button then
					g_TweenService:Create(ScriptsSelectionFrame, c_EffectsTweening, {BackgroundColor3 = c_VisualScheme.Selector.Loading}):Play()
					l_SetToolbarButton(false, "Execute")
					pcall(l_Selected.Execute)
					l_SetToolbarButton(true, "Execute")
					g_TweenService:Create(ScriptsSelectionFrame, c_EffectsTweening, {BackgroundColor3 = c_VisualScheme.Selector.Select}):Play()
				end
				ExecutionDebounce = false
			end))

			l_MoveSelected = function(To, CheckOnly)
				local Swap = not CheckOnly
				local SwapResult = 0
				
				local function CheckValue(Value, StartIndex, Table)
					if Value == l_Selected.DescriptorRef then
						DBGLOG("Swapping:", Value)
						local IndexOffset = (To and -1) or 1
						assert(type(StartIndex) == "number", "Index Is Not The Number Datatype")
						local TempRef = Table[StartIndex + IndexOffset] -- To:true == Up(-1), To:false == Down(+1)

						if not TempRef then SwapResult = 2 return DBGWARN("Cant Go " .. ((To and "UP") or "DOWN")) end -- Can't Go Up/Down
						
						if Swap then
							-- Set Item + Offset(Up/Down) = Value And Swap
							Table[StartIndex + IndexOffset] = Value
							Table[StartIndex] = TempRef
						end
						
						SwapResult = 1
					else
						SwapResult = 0
					end
				end
				
				
				for Name, Value in pairs(u_Scripts) do
					if type(Value) == "table" then
						for Index, ScriptDesc in pairs(Value) do
							CheckValue(ScriptDesc, Index, Value)
							if SwapResult ~= 0 then
								return SwapResult
							end
						end
					else
						CheckValue(Value, Name, u_Scripts)
						if SwapResult ~= 0 then
							return SwapResult
						end
					end

				end
			end

			table_insert(u_Connections, l_ScriptToolbarButtons["MoveUp"].MouseButton1Click:Connect(function()
				l_MoveSelected(true)
				l_SaveScriptList()
				l_RebuildGui()
			end))
			
			table_insert(u_Connections, l_ScriptToolbarButtons["MoveDown"].MouseButton1Click:Connect(function()
				l_MoveSelected(false)
				l_SaveScriptList()
				l_RebuildGui()
			end))
		end

	end




	SetTransparency(1, false)
	Core.Parent = g_CoreGui

	SetTransparency(0, true)
end
