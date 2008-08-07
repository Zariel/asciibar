local math_floor = math.floor
local string_rep = string.rep

local print = function(str) ChatFrame1:AddMessage(tostring(str)) end

local cast = CreateFrame("Frame", nil, UIParent)
cast:SetScript("OnEvent", function(self, event, ...)
	if not self[event] then
		ChatFrame1:AddMessage(event)
	else
		self[event](self, ...)
	end
end)
cast:RegisterEvent("PLAYER_ENTERING_WORLD")

local equal, arrow, hyphen, bracket = 9, 9, 4.5, 7.5

do
	cast:SetHeight(15)
	cast:SetWidth(328)

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

cast:SetPoint("CENTER")

local CreateString = function(per, reverse)
	per = math_floor(per * 100) / 100
	local nE = math_floor((per * 306) / 9)
	local nH = (34 - nE) * 2

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

	--[[

	if not self.target or self.target == "" then
		self.name:SetFormattedText("%s", spell)
	else
		self.name:SetFormattedText("%s --> %s", spell, self.target)
	end

	]]

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
