PortalFu = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceEvent-2.0", "FuBarPlugin-2.0")
local PortalFu = PortalFu

local L = AceLibrary("AceLocale-2.2"):new("PortalFu")
local tablet = AceLibrary("Tablet-2.0")
local dewdrop = AceLibrary("Dewdrop-2.0")

local string_find = string.find
local string_sub = string.sub
local math_floor = math.floor

local GetSpellInfo = GetSpellInfo
local GetSpellName = GetSpellName
local GetContainerNumSlots = GetContainerNumSlots
local GetContainerItemInfo = GetContainerItemInfo
local GetContainerItemLink = GetContainerItemLink
local GetContainerItemCooldown = GetContainerItemCooldown
local GetBindLocation = GetBindLocation

local scrollOfRecallIcon 	= "Interface\\Icons\\INV_Scroll_16"
local hearthstoneIcon		= "Interface\\Icons\\INV_Misc_Rune_01"

PortalFu.hasIcon = true
PortalFu.canHideText = true
PortalFu.hasNoColor = true
PortalFu.defaultMinimapPosition = 20
PortalFu.overrideMenu = true

PortalFu:RegisterDB("PortalFuDB", "PortalFuPerCharDB")
PortalFu:RegisterDefaults('profile', {
	showTag = true,
})


local function pairsByKeys(t)
	local a = {}
	for n in pairs(t) do
		table.insert(a, n)
	end
	table.sort(a)
	
	local i = 0
	local iter = function ()
		i = i + 1
		if a[i] == nil then
			return nil
		else
			return a[i], t[a[i]]
		end
	end
	return iter
end

local function findSpell(spellName)
	local i = 1
	while true do
		local s = GetSpellName(i, BOOKTYPE_SPELL)
		if not s then
			break
		end
		
		if s == spellName then
			return i
		end
		
		i = i + 1
	end
end


local function getHearthCooldown()
	local cooldown, startTime, duration

  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      local item = GetContainerItemLink(bag, slot)
      if item then
        if string_find(item, L["HEARTHSTONE"]) then
          startTime, duration = GetContainerItemCooldown(bag, slot)
          cooldown = duration - (GetTime() - startTime)
          cooldown = cooldown / 60
          cooldown = math_floor(cooldown)
          if cooldown <= 0 then
            return L["READY"]
          end

          return cooldown.." "..L["MIN"]
        end
      end
    end
  end
  
  return L["N/A"]
end

local function getReagentCount(name)
	local count = 0
  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      local item = GetContainerItemLink(bag, slot)
      if item then
        if string_find(item, name) then
          local _, itemCount = GetContainerItemInfo(bag, slot)
          count = count + itemCount
        end
      end
    end
  end
	
	return count
end

local function idAndNameFromLink(link)
	local name
	if (not link) then
		return ""
	end
	for id, name in string.gfind(link, "|c%x+|Hitem:(%d+):%d+:%d+:%d+|h%[(.-)%]|h|r$") do
		return tonumber(id), name
	end
	return nil
end

function PortalFu:GetItemSlot(itemId)
	local bag = nil
	local slot = nil
	if self.teleItems[itemId].slot then
		bag = self.teleItems[itemId].bag
		slot = self.teleItems[itemId].slot
	end

	if self.teleItems[itemId].slotCheckedSinceUpdate then
		return slot, bag
	end

	-- Check if the slot is not nil or has changed
	if slot then
		-- Check equipped items first
		if not bag then
			local link = GetInventoryItemLink("player", slot)
			if (link) then
				local id = idAndNameFromLink(link)
				if (id and id == itemId) then
					self.teleItems[itemId].slotCheckedSinceUpdate = true
					return slot, bag
				end
			end
		elseif bag then
			local link = GetContainerItemLink(bag, slot)
			if (link) then
				local id = idAndNameFromLink(link)
				if (id and id == itemId) then
					self.teleItems[itemId].slotCheckedSinceUpdate = true
					return slot, bag
				end
			end
		end
	end

	-- Old values did not match. Clear the previous values
	self.teleItems[itemId].bag = nil
	self.teleItems[itemId].slot = nil
	bag = nil
	slot = nil

	-- Do a full inventory/equipment search
	-- Check equipped items first
	for slot = 0, 19 do
		local link = GetInventoryItemLink("player", slot)
		if (link) then
			local id, name = idAndNameFromLink(link)
			if (id and id == itemId) then
				self.teleItems[itemId].bag = bag
				self.teleItems[itemId].slot = slot
				self.teleItems[itemId].slotCheckedSinceUpdate = true
				self.teleItems[itemId].icon = GetInventoryItemTexture("player", slot)
				return slot, bag
			end
		end
	end
	for bag = 4, 0, -1 do
		for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot)
			if (link) then
				local id, name = idAndNameFromLink(link)
				if (id and id == itemId) then
					self.teleItems[itemId].bag = bag
					self.teleItems[itemId].slot = slot
					self.teleItems[itemId].slotCheckedSinceUpdate = true
					self.teleItems[itemId].icon = GetContainerItemInfo(bag, slot)
					return slot, bag
				end
			end
		end
	end


	self.teleItems[itemId].slotCheckedSinceUpdate = true
	return slot, bag
end


function PortalFu:CheckTransport()

	local allSpells = {
		Alliance = {
			"Teleport: Darnassus",
			"Teleport: Ironforge",
			"Teleport: Stormwind",
			"Portal: Darnassus",
			"Portal: Ironforge",
			"Portal: Stormwind",
			"Teleport: Theramore",
			"Portal: Theramore",
			"Teleport: Alah'Thalas",
			"Portal: Alah'Thalas",
		},
		Horde = {
			"Teleport: Orgrimmar",
			"Teleport: Thunder Bluff",
			"Teleport: Undercity",
			"Portal: Orgrimmar",
			"Portal: Thunder Bluff",
			"Portal: Undercity",
			"Teleport: Stonard",
			"Portal: Stonard",
		},
		Druid = {
			"Teleport: Moonglade" --18960 --TP:Moonglade
		},
		Shaman = {
			"Astral Recall" -- 556 --
		}
	}
	local faction = UnitFactionGroup('player')
	if faction == nil then --GM
		self.portals = {}
		for _, spells in pairs(allSpells) do
			for _, spell in ipairs(spells) do
				table.insert(self.portals, spell)
			end
		end
	else
		local _, class = UnitClass("player")
		if class == "MAGE" then
			self.portals = allSpells[faction]
		elseif class == "DRUID" then
			self.portals = allSpells.Druid
		elseif class == "SHAMAN" then
			self.portals = allSpells.Shaman
		end
	end

	self.teleItems = {
		[61000] = {name = "Teleport: Cavern of Times"}, -- Time-Worn Rune
		[18984] = {name = "Teleport: Everlook"},
		[18986] = {name = "Teleport: Gadgetzan"},
		[51312] = {name = "Portable Wormhole Generator: Stormwind"},
		[51313] = {name = "Portable Wormhole Generator: Orgrimmar"},
		[5976] = {name = "Guild Tabard"},
	}
end


function PortalFu:OnInitialize()
	self:RegisterChatCommand({"/portalfu"}, function() PortalFu:ToggleMinimapAttached() end)
end

function PortalFu:OnEnable()
	self.METHODS = {}
	self.ITEMS = {}
	self.lastCast = L["N/A"]
	self:CheckTransport()
	self:UpdateSpells()
	self:RegisterEvent("LEARNED_SPELL_IN_TAB")
	self:RegisterEvent("BAG_UPDATE")
	self:UpdateDisplay()
	self:SetIcon(hearthstoneIcon)
end

function PortalFu:OnDisable()
	self.METHODS = nil
	self.lastCast = nil
	self.ITEMS = nil
	self:UnregisterAllEvents()
end

function PortalFu:LEARNED_SPELL_IN_TAB()
	self:UpdateSpells()
end

function PortalFu:BAG_UPDATE()
	for k,v in pairs(self.teleItems) do
		v.slotCheckedSinceUpdate = false
	end
	PortalFu:UpdateItems()
end

function PortalFu:OnMenuRequest(level,value)
	if level == 1 then
		for k,v in pairsByKeys(self.METHODS) do
			dewdrop:AddLine(
				'text', v.text,
--					'secure', v.secure,
				'icon', v.spellIcon,
				'func', function(v) 
					self:SetIcon(v.spellIcon)
					self.lastCast = v.text
					self:UpdateDisplay()
					CastSpellByName(v.text)
				end,
				'arg1', v,
				'disabled', false,
				'closeWhenClicked', true
			)
		end
		if self.METHODS then dewdrop:AddLine() end
		self:ShowItems()
		if self.ITEMS then dewdrop:AddLine() end
		self:ShowHearthstone()
		dewdrop:AddLine(
			'text', "FuBar Options",
			'hasArrow', true,
			'value', "fubar"
		)
		
		
	elseif level > 1 and (value == "fubar" or value == "position") then
		level = value == "position" and 2 or level
		self:AddImpliedMenuOptions(level )
	end
end

function PortalFu:UpdateText()
	if self.lastCast then
		local text = self.lastCast
		if string_find(self.lastCast,"Item:") then
			local _, _, id = string_find(self.lastCast,"Item:(%d+)")
			id = tonumber(id)
			text = self.teleItems[id].name
		end
		if string_find(text, ":") then
			 _, _, text = string_find(text,": (.+)")
		end
		self:SetText(text)
	else
		self:SetText(L["N/A"])
	end
end

function PortalFu:OnTooltipUpdate()
	local cat = tablet:AddCategory(
		'columns', 2,
		'child_textR', 1,
		'child_textG', 1,
		'child_textB', 0,
		'child_text2R', 1,
		'child_text2G', 1,
		'child_text2B', 1
	)
	cat:AddLine('text', L["RCLICK"], 'text2', L["SEE_SPELLS"])
	cat:AddLine('text', ' ')
	cat:AddLine('text', L["HEARTHSTONE"].." : "..GetBindLocation(), 'text2', getHearthCooldown())
	cat:AddLine('text', ' ')
	cat:AddLine('text', L["TP_P"], 'text2', getReagentCount(L["TP_RUNE"]).."/"..getReagentCount(L["P_RUNE"]))
end

function PortalFu:UpdateSpells()
	if self.portals then
		for _,unTransSpell in ipairs(self.portals) do
			local spell = L[unTransSpell]
			local spellIcon = self:GetSpellIcon(unTransSpell)
			local spellid = findSpell(spell)
			
			if spellid then	
				self.METHODS[spell] = {
					spellid = spellid,
					text = spell,
					spellIcon = spellIcon,
				}
			end
		end
	end
end

local spellIcons = {
	["Astral Recall"] = "Spell_Nature_AstralRecal",
	["Portal: Alah'Thalas"] = "Spell_Arcane_PortalStormWind",
	["Portal: Darnassus"] = "Spell_Arcane_PortalDarnassus",
	["Portal: Ironforge"] = "Spell_Arcane_PortalIronForge",
	["Portal: Orgrimmar"] = "Spell_Arcane_PortalOrgrimmar",
	["Portal: Stormwind"] = "Spell_Arcane_PortalStormWind",
	["Portal: Thunder Bluff"] = "Spell_Arcane_PortalThunderBluff",
	["Portal: Undercity"] = "Spell_Arcane_PortalUnderCity",
	["Portal: Stonard"] = "Spell_Arcane_PortalStonard",
	["Portal: Theramore"] = "Spell_Arcane_PortalTheramore",
	["Teleport: Alah'Thalas"] = "Spell_Arcane_TeleportStormWind",
	["Teleport: Darnassus"] = "Spell_Arcane_TeleportDarnassus",
	["Teleport: Ironforge"] = "Spell_Arcane_TeleportIronForge",
	["Teleport: Moonglade"] = "Spell_Arcane_TeleportMoonglade",
	["Teleport: Orgrimmar"] = "Spell_Arcane_TeleportOrgrimmar",
	["Teleport: Stormwind"] = "Spell_Arcane_TeleportStormWind",
	["Teleport: Thunder Bluff"] = "Spell_Arcane_TeleportThunderBluff",
	["Teleport: Undercity"] = "Spell_Arcane_TeleportUnderCity",
	["Teleport: Stonard"] = "Spell_Arcane_TeleportStonard",
	["Teleport: Theramore"] = "Spell_Arcane_TeleportTheramore",
}

function PortalFu:GetSpellIcon(spell)
	local icon = spellIcons[spell]
	if not icon then
		return scrollOfRecallIcon
	end
	return "Interface\\Icons\\" .. icon
end

function PortalFu:UpdateItems()
	if not self.teleItems then return end
	for id, v in pairs(self.teleItems) do
		local slot, bag = self:GetItemSlot(id)
		if slot then
			self.ITEMS[id] = slot
		else
			self.ITEMS[id] = nil
		end
	end	
end

function PortalFu:ShowHearthstone()
	local text, icon
	local hsCd = getHearthCooldown()
	if hsCd == L["READY"] then
		local bindLoc = GetBindLocation()
		text = L["HEARTHSTONE"]
		if bindLoc then
			text = L["INN"] .." "..bindLoc
		end
		icon = hearthstoneIcon
		dewdrop:AddLine(
			'text', text,
			'icon', icon,
			'func', function(icon,text) 
				self:SetIcon(icon)
				self.lastCast = text
				self:UpdateDisplay()
				UseHearthstone()
			end,
			'arg1', icon,
			'arg2', text,
			'closeWhenClicked', true
		)
		dewdrop:AddLine()
	end
end

function PortalFu:ShowItems()
	for k,v in pairs(self.ITEMS) do
		dewdrop:AddLine(
			'text', self.teleItems[k].name,
			'icon', self.teleItems[k].icon,
			'func', function(id) 
				self:SetIcon(self.teleItems[id].icon)
				self.lastCast = "Item:"..id
				self:UpdateDisplay()
				local slot, bag = self:GetItemSlot(id)
				if not bag then
					UseInventoryItem(slot)
				else
					UseContainerItem(bag, slot)
				end
			end,
			'arg1', k,
			'closeWhenClicked', true
		)
	end
end

function PortalFu:OnClick(button)
	if button == "RightButton" then
		return
	end
	if self.lastCast and self.lastCast ~= L["N/A"] then
		if string_find(self.lastCast,L["INN"]) then
			UseHearthstone()
		elseif string_find(self.lastCast,"Item:") then
			local _, _, id = string_find(self.lastCast,"Item:(%d+)")
			id = tonumber(id)
			local slot, bag = self:GetItemSlot(id)
			if not bag then
				UseInventoryItem(slot)
			else
				UseContainerItem(bag, slot)
			end
		else
			CastSpellByName(self.lastCast)
		end
	else
		UseHearthstone()
	end
end

function UseHearthstone()
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			local itemLink = GetContainerItemLink(bag, slot)
			if itemLink and string.find(itemLink, "Hearthstone") then
				UseContainerItem(bag, slot)
				return
			end
		end
	end
end
