local math_floor = math.floor
local string_rep = string.rep

local cast = CreateFrame("Frame", nil, UIParent)

function cast:Print(...)
	local str = tostring(self) .. ": "
	for i = 1, select("#", ...) do
		str = str .. tostring(select(i, ...)) .. " "
	end

	ChatFrame1:AddMessage(str)
end

do
	local i = getmetatable(cast).__index
	local mt = {
		__index = i,
		__tostring = function() return "ASCIIbar" end,
	}
	setmetatable(cast, mt)
end

local OnEvent = function(self, event, ...)
	self[event](self, ...)
end

cast:SetScript("OnEvent", OnEvent)

cast:RegisterEvent("PLAYER_ENTERING_WORLD")
cast:RegisterEvent("ADDON_LOADED")

local equal, arrow, hyphen, bracket = 9, 9, 4.5, 7.5

do
	cast:SetScript("OnMouseDown", function(self, button)
		if IsAltKeyDown() and self:IsMovable() then
			self:StartMoving()
		end
	end)

	cast:SetScript("OnMouseUp", function(self, button)
		if self:IsMovable() then
			self:StopMovingOrSizing()
			local x, y = self:GetLeft(), self:GetTop()
			self.db.x, self.db.y = x, y
		end
	end)

	cast:SetHeight(14.5)
	cast:SetWidth(328)
	cast:SetClampedToScreen(true)

	local font = cast:CreateFontString(nil, "OVERLAY")
	font:SetPoint("LEFT")
	font:SetFont(STANDARD_TEXT_FONT, 15)
	font:SetJustifyH("LEFT")
	font:SetShadowColor(0, 0, 0, 1)
	font:SetShadowOffset(0, -1)
	cast.bar = font

	local time = cast:CreateFontString(nil, "OVERLAY")
	time:SetPoint("LEFT", font, "RIGHT")
	time:SetFont(STANDARD_TEXT_FONT, 15)
	time:SetJustifyH("LEFT")
	time:SetShadowColor(0, 0, 0, 1)
	time:SetShadowOffset(0, -1)
	cast.time = time
end

local CreateString = function(per, reverse)
	per = math_floor(per * 100) / 100
	local nE = math_floor((per * 270) / 9)
	local nH = (30 - nE) * 2

	local nA = nE < 1 and 0 or 1
	local str
	if reverse then
		str = "[" .. string_rep("-", nH) .. string_rep("<", nA) .. string_rep("=", nE) .. "]"
	else
		str = "[" .. string_rep("=", nE - 1) .. string_rep(">", nA) .. string_rep("-", nH) .. "]"
	end

	return str
end

local OnUpdate = function(self)
	local time = GetTime()
	local startTime = self.startTime
	local endTime = self.endTime
	local duration = self.duration
	if self.casting then
		if time > endTime then
			self.casting = false
			self.stopTime = time
			self:Hide()
			return
		end
		local elapsed = (time - startTime)
		local per = elapsed / duration
		self.bar:SetText(CreateString(per))
		self.time:SetFormattedText("[%0.1f:%0.1f]", elapsed, duration)
		self:Show()
	elseif self.channeling then
		if time > endTime then
			self.channeling = false
			self.stopTime = time
			return
		end
		local elapsed = (time - startTime)
		local per = elapsed / duration
		self.bar:SetText(CreateString(per, true))
		self.time:SetFormattedText("[%02.0f:%02.0f]", elapsed, duration)
		self:Show()
	else
		self:Hide()
	end
end

function cast:Unlock()
	if self:IsMovable() then
		self:SetScript("OnUpdate", OnUpdate)
		self:SetScript("OnEvent", OnEvent)
		self:Hide()
		self:EnableMouse(nil)
		self:SetMovable(nil)
	else
		self:SetScript("OnUpdate", nil)
		self:SetScript("OnEvent", nil)
		self:Show()
		self:EnableMouse(true)
		self:SetMovable(true)
	end
end

function cast:ADDON_LOADED(addon)
	if addon:lower() == "asciibar" then
		local db = _G.ASCIIbarDB
		local server, name = GetRealmName(), UnitName("player")
		local defaults = {
			[server] = {
				[name] = {
					x = 0,
					y = 0
				}
			}
		}

		if not db then
			db = defaults
		elseif not db[server] then
			db[server] = defaults[server]
		elseif not db[server][name] then
			db[server][name] = defaults[server][name]
		end

		_G.ASCIIbarDB = db

		self.db = _G.ASCIIbarDB[server][name]

		local x, y = self.db.x, self.db.y

		self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
	end
end

function cast:PLAYER_ENTERING_WORLD()
	self:RegisterEvent("UNIT_SPELLCAST_SENT")
	self:RegisterEvent("UNIT_SPELLCAST_START")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
	self:RegisterEvent("UNIT_SPELLCAST_STOP")
	self:RegisterEvent("UNIT_SPELLCAST_FAILED")
	self:RegisterEvent("UNIT_SPELLCAST_DELAYED")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
	self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

	self:SetScript("OnUpdate", OnUpdate)
end

function cast:UNIT_SPELLCAST_SENT(unit, spellName, spellRank, spellTarget)
	if unit ~= "player" then return end

	if not spellTarget then spellTarget = PlayerName end
	self.target = spellTarget
end

function cast:UNIT_SPELLCAST_START(unit, spellName, spellRank)
	if unit ~= "player" then return end

	local spell, rank, displayName, icon, startTime, endTime = UnitCastingInfo(unit)
	if not startTime then
		self.casting = false
		return self:Hide()
	end
	startTime = startTime/1000
	endTime = endTime/1000
	self.casting = true
	self.channeling = false
	self.startTime = startTime
	self.endTime = endTime
	self.fade = true
	local length = (endTime - startTime)
	self.duration = length

	self:Show()
end

function cast:UNIT_SPELLCAST_DELAYED(unit, spellName, spellRank)
	if unit ~= "player" then return end

	local spell, rank, displayName, icon, startTime, endTime = UnitCastingInfo(unit)
	startTime = startTime/1000
	endTime = endTime/1000
	self.startTime = startTime
	self.endTime = endTime
end

function cast:UNIT_SPELLCAST_SUCCEEDED(unit)
	if unit ~= "player" then return end
	self.casting = false
	self.target = nil
	self.stopTime = GetTime()
end

function cast:UNIT_SPELLCAST_STOP(unit, spellName, spellRank)
	if unit ~= "player" then return end

	if self.casting then
		self.casting = false
		self.target = nil
		self.stopTime = GetTime()
	end
end

function cast:UNIT_SPELLCAST_CHANNEL_START(unit, spellName, spellRank)
	if unit ~= "player" then return end

	local spell, rank, displayName, icon, startTime, endTime = UnitChannelInfo(unit)
	startTime = startTime/1000
	endTime = endTime/1000
	self.casting = false
	self.channeling = true
	self.startTime = startTime
	self.endTime = endTime
	local length = (endTime - startTime)
	self.duration = length
	self.fade = true

	self:Show()
end

function cast:UNIT_SPELLCAST_CHANNEL_STOP(unit, spellname, spellRank)
	if unit ~= "player" then return end

	if self.channeling then
		self.channeling = false
		self.target = nil
		self.stopTime = GetTime()
	end
end

function cast:UNIT_SPELLCAST_CHANNEL_UPDATE(unit, spellName, spellRank)
	if unit ~= "player" then return end

	local spell, rank, displayName, icon, startTime, endTime = UnitChannelInfo(unit)
	startTime = startTime/1000
	endTime = endTime/1000
	self.channeling = true
	self.startTime = startTime
	self.endTime = endTime
end

function cast:UNIT_SPELLCAST_FAILED(unit)
	if unit ~= "player" then return end
	self:UNIT_SPELLCAST_STOP(unit)
end

function cast:UNIT_SPELLCAST_INTERRUPTED(unit)
	if unit ~= "player" then return end
	self:UNIT_SPELLCAST_STOP(unit)
end

cast.slash = {}
local slash = cast.slash
SLASH_ASCII1 = "/asciibar"

-- Copied from tekkubs StealYourCarbon, best slash command method.
SlashCmdList.ASCII = function(input)
	local cmd, rest = string.match(input, "^%s*(%S+)%s*(.*)$")
	local handler = cmd and slash[cmd:lower()]

	if handler then
		handler(cast, rest)
	else
		local self = cast
		self:Print("Because its cooler")
		self:Print("         Yeah you cant change the size unless you know lua")
		self:Print("         lock: you can move it though")
	end
end

function slash.lock(self, state)
	self:Unlock()
end
