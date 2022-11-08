local GEnv = _G

local EnvRef = ((getgenv and getgenv()) or _G)
EnvRef["EPD_GENV_REF"] = GEnv

GEnv.EPD = GEnv.EPD or {}
GEnv.EPD.HttpGet =
	httpget or http_get
	or (syn 			and function(Link) return syn.request({Url = Link, Method = "GET"}).Body end)
	or (game.HttpGet 	and function(Link) return game:HttpGet(Link) end)
	or error("No HTTP Get Function.")

GEnv.EPD.DEBUG = false -- Enable For Debugging

local LoadedFunction = loadstring(_G.EPD.HttpGet("https://raw.githubusercontent.com/PBeta-R34/EPD-SCRIPT-HUB/main/Source/Loader.lua"))
if type(LoadedFunction) == "function" then
	local Success, Returned = pcall(LoadedFunction)
	-- We Don't Wanna Print Unless Debug Is True
	if not Success then
		error("Loader Fatal Error: " .. tostring(Returned))
	end
end