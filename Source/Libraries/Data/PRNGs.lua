local PRNGs = {}

local brsh 	= bit32.rshift 	-- >>
local blsh 	= bit32.lshift 	-- <<
local bxor 	= bit32.bxor 	-- ^
local bnot 	= bit32.bnot 	-- !
local band 	= bit32.band 	-- &
local bor 	= bit32.bor 	-- |

local os_clock = os.time

-- Predefined Table References
local _XORShift32TableRef = nil

-- Lua Uses Co-Routines, So This Will Help.
local _State = nil

PRNGs.XORShift = {
	
	XORShift32 = {
		Seed = os_clock() % 0xffffffff, 	-- 32-BIT Seed
		
		Random = function()
			_State = _XORShift32TableRef.Seed
			_State = bxor(_State, blsh(_State, 13))
			_State = bxor(_State, brsh(_State, 17))
			_State = bxor(_State, blsh(_State, 5))
			_XORShift32TableRef.Seed = _State
			return _State
		end,
	},
	
	
}

_XORShift32TableRef = PRNGs.XORShift.XORShift32


return PRNGs