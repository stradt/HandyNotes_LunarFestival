
------------------------------------------
--  This addon was heavily inspired by  --
--    HandyNotes_Lorewalkers            --
--    HandyNotes_LostAndFound           --
--  by Kemayo                           --
------------------------------------------


-- declaration
local _, LunarFestival = ...
LunarFestival.points = {}


-- our db and defaults
local db
local defaults = { profile = { completed = false, icon_scale = 1.4, icon_alpha = 0.8 } }


-- upvalues
local _G = getfenv(0)

local CalendarGetDate = _G.CalendarGetDate
local CloseDropDownMenus = _G.CloseDropDownMenus
local GameTooltip = _G.GameTooltip
local GetAchievementCriteriaInfo = _G.GetAchievementCriteriaInfo
local gsub = _G.string.gsub
local IsQuestFlaggedCompleted = _G.IsQuestFlaggedCompleted
local LibStub = _G.LibStub
local next = _G.next
local pairs = _G.pairs
local ToggleDropDownMenu = _G.ToggleDropDownMenu
local UIDropDownMenu_AddButton = _G.UIDropDownMenu_AddButton
local UIParent = _G.UIParent
local WorldMapButton = _G.WorldMapButton
local WorldMapTooltip = _G.WorldMapTooltip

local Astrolabe = DongleStub("Astrolabe-1.0")
local Cartographer_Waypoints = _G.Cartographer_Waypoints
local HandyNotes = _G.HandyNotes
local NotePoint = _G.NotePoint
local TomTom = _G.TomTom

local points = LunarFestival.points


-- plugin handler for HandyNotes
local function infoFromCoord(mapFile, coord)
	mapFile = gsub(mapFile, "_terrain%d+$", "")

	local point = points[mapFile] and points[mapFile][coord]

	if point == "Zidormi" then
		return point
	else
		return GetAchievementCriteriaInfo(point[2], point[3])
	end
end

function LunarFestival:OnEnter(mapFile, coord)
	local tooltip = self:GetParent() == WorldMapButton and WorldMapTooltip or GameTooltip

	if self:GetCenter() > UIParent:GetCenter() then -- compare X coordinate
		tooltip:SetOwner(self, "ANCHOR_LEFT")
	else
		tooltip:SetOwner(self, "ANCHOR_RIGHT")
	end

	local nameOfElder = infoFromCoord(mapFile, coord)

	tooltip:SetText(nameOfElder)

	if nameOfElder == "Zidormi" then
		tooltip:AddLine("Talk to the Time Keeper to change the zone's phase if you can't find the Elder.", 1, 1, 1)
	end

	tooltip:Show()
end

function LunarFestival:OnLeave()
	if self:GetParent() == WorldMapButton then
		WorldMapTooltip:Hide()
	else
		GameTooltip:Hide()
	end
end

local function createWaypoint(button, mapFile, coord)
	local c, z = HandyNotes:GetCZ(mapFile)
	local x, y = HandyNotes:getXY(coord)

	local nameOfElder = infoFromCoord(mapFile, coord)

	if TomTom then
		TomTom:AddZWaypoint(c, z, x * 100, y * 100, nameOfElder)
	elseif Cartographer_Waypoints then
		Cartographer_Waypoints:AddWaypoint( NotePoint:new(HandyNotes:GetCZToZone(c, z), x, y, nameOfElder) )
	end
end

do
	-- context menu generator
	local info = {}
	local currentZone, currentCoord, nameOfElder

	local function close()
		-- we need to do this to avoid "for initial value must be a number" errors
		CloseDropDownMenus()
	end

	local function generateMenu(button, level)
		if not level then return end

		for k in pairs(info) do info[k] = nil end

		if level == 1 then
			-- create the title of the menu
			info.isTitle = 1
			info.text = nameOfElder
			info.notCheckable = 1

			UIDropDownMenu_AddButton(info, level)

			if TomTom or Cartographer_Waypoints then
				-- waypoint menu item
				info.notCheckable = nil
				info.disabled = nil
				info.isTitle = nil
				info.icon = nil
				info.text = "Create waypoint"
				info.func = createWaypoint
				info.arg1 = currentZone
				info.arg2 = currentCoord

				UIDropDownMenu_AddButton(info, level)
			end

			-- close menu item
			info.text = "Close"
			info.func = close
			info.arg1 = nil
			info.arg2 = nil
			info.icon = nil
			info.isTitle = nil
			info.disabled = nil
			info.notCheckable = 1

			UIDropDownMenu_AddButton(info, level)
		end
	end

	local dropdown = CreateFrame("Frame", "HandyNotes_LunarFestivalDropdownMenu")
	dropdown.displayMode = "MENU"
	dropdown.initialize = generateMenu

	function LunarFestival:OnClick(button, down, mapFile, coord)
		if button == "RightButton" and not down then
			currentZone = mapFile
			currentCoord = coord

			nameOfElder = infoFromCoord(mapFile, coord)

			ToggleDropDownMenu(1, nil, dropdown, self, 0, 0)
		end
	end
end

do
	local continentMapFile = {
		["Kalimdor"]              = {__index = Astrolabe.ContinentList[1]},
		["Azeroth"]               = {__index = Astrolabe.ContinentList[2]},
		["Expansion01"]           = {__index = Astrolabe.ContinentList[3]},
		["Northrend"]             = {__index = Astrolabe.ContinentList[4]},
		["TheMaelstromContinent"] = {__index = Astrolabe.ContinentList[5]},
		["Vashjir"]               = {[0] = 613, 614, 615, 610},
		["Pandaria"]              = {__index = Astrolabe.ContinentList[6]},
	}

	for k, v in pairs(continentMapFile) do
		setmetatable(v, v)
	end

	-- custom iterator we use to iterate over every node in a given zone
	local function iter(t, prestate)
		if not t then return nil end

		local state, value = next(t, prestate)

		while state do -- have we reached the end of this zone?
			if value == "Zidormi" then
				return state, mapFile, "interface\\icons\\spell_mage_altertime", db.icon_scale, db.icon_alpha
			elseif (db.completed or not IsQuestFlaggedCompleted(value[1])) then
				return state, mapFile, "interface\\icons\\inv_misc_elvencoins", db.icon_scale, db.icon_alpha
			end

			state, value = next(t, state) -- get next data
		end

		return nil, nil, nil, nil
	end

	local function iterCont(t, prestate)
		if not t then return nil end

		local zone = t.Z
		local mapFile = HandyNotes:GetMapIDtoMapFile(t.C[zone])
		local data = points[mapFile]
		local state, value

		while mapFile do
			if data then -- only if there is data for this zone
				state, value = next(data, prestate)

				while state do -- have we reached the end of this zone?
					if value == "Zidormi" then
						return state, mapFile, "interface\\icons\\spell_mage_altertime", db.icon_scale, db.icon_alpha
					elseif (db.completed or not IsQuestFlaggedCompleted(value[1])) then
						return state, mapFile, "interface\\icons\\inv_misc_elvencoins", db.icon_scale, db.icon_alpha
					end

					state, value = next(data, state) -- get next data
				end
			end

			-- get next zone
			zone = zone + 1
			t.Z = zone
			mapFile = HandyNotes:GetMapIDtoMapFile(t.C[zone])
			data = points[mapFile]
			prestate = nil
		end
	end

	function LunarFestival:GetNodes(mapFile)
		mapFile = gsub(mapFile, "_terrain%d+$", "")

		local C = continentMapFile[mapFile] -- Is this a continent?

		if C then
			local tbl = { C = C, Z = 0 }
			return iterCont, tbl, nil
		else
			return iter, points[mapFile], nil
		end
	end
end


-- config
local options = {
	type = "group",
	name = "Lunar Festival",
	desc = "Lunar Festival elder NPC locations.",
	get = function(info) return db[info[#info]] end,
	set = function(info, v)
		db[info[#info]] = v
		LunarFestival:Refresh()
	end,
	args = {
		desc = {
			name = "These settings control the look and feel of the icon.",
			type = "description",
			order = 1,
		},
		completed = {
			name = "Show completed",
			desc = "Show icons for elder NPCs you have already visited.",
			type = "toggle",
			width = "full",
			arg = "completed",
			order = 2,
		},
		icon_scale = {
			type = "range",
			name = "Icon Scale",
			desc = "Change the size of the icons.",
			min = 0.25, max = 2, step = 0.01,
			arg = "icon_scale",
			order = 3,
		},
		icon_alpha = {
			type = "range",
			name = "Icon Alpha",
			desc = "Change the transparency of the icons.",
			min = 0, max = 1, step = 0.01,
			arg = "icon_alpha",
			order = 4,
		},
	},
}


-- initialise
function LunarFestival:OnEnable()
	local _, month, day = CalendarGetDate()

	if ( month == 2 and day >= 16 ) or ( month == 3 and day <= 2 ) then
		HandyNotes:RegisterPluginDB("LunarFestival", self, options)
		self:RegisterEvent("QUEST_FINISHED", "Refresh")

		db = LibStub("AceDB-3.0"):New("HandyNotes_LunarFestivalDB", defaults, "Default").profile
	else
		self:Disable()
	end
end

function LunarFestival:Refresh()
	self:SendMessage("HandyNotes_NotifyUpdate", "LunarFestival")
end


-- activate
LibStub("AceAddon-3.0"):NewAddon(LunarFestival, "HandyNotes_LunarFestival", "AceEvent-3.0")
