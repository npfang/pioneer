-- Copyright © 2008-2013 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Engine = import("Engine")
local Lang = import("Lang")
local Game = import("Game")
local EquipDef = import("EquipDef")
local Comms = import("Comms")
local utils = import("utils")

local l = Lang.GetResource("ui-core")

-- XXX equipment strings are in core. this sucks
local lcore = Lang.GetResource("core")

local ui = Engine.ui

local equipIcon = {
	HYDROGEN =              "Hydrogen",
	LIQUID_OXYGEN =         "Liquid_Oxygen",
	METAL_ORE =             "Metal_ore",
	CARBON_ORE =            "Carbon_ore",
	METAL_ALLOYS =          "Metal_alloys",
	PLASTICS =              "Plastics",
	FRUIT_AND_VEG =         "Fruit_and_Veg",
	ANIMAL_MEAT =           "Animal_Meat",
	LIVE_ANIMALS =          "Live_Animals",
	LIQUOR =                "Liquor",
	GRAIN =                 "Grain",
	TEXTILES =              "Textiles",
	FERTILIZER =            "Fertilizer",
	WATER =                 "Water",
	MEDICINES =             "Medicines",
	CONSUMER_GOODS =        "Consumer_goods",
	COMPUTERS =             "Computers",
	ROBOTS =                "Robots",
	PRECIOUS_METALS =       "Precious_metals",
	INDUSTRIAL_MACHINERY =  "Industrial_machinery",
	FARM_MACHINERY =        "Farm_machinery",
	MINING_MACHINERY =      "Mining_machinery",
	AIR_PROCESSORS =        "Air_processors",
	SLAVES =                "Slaves",
	HAND_WEAPONS =          "Hand_weapons",
	BATTLE_WEAPONS =        "Battle_weapons",
	NERVE_GAS =             "Nerve_Gas",
	NARCOTICS =             "Narcotics",
	MILITARY_FUEL =         "Military_fuel",
	RUBBISH =               "Rubbish",
	RADIOACTIVES =          "Radioactive_waste",
}

local stationColumnHeading = {
	icon  = "",
	name  = l.NAME,
	price = l.PRICE,
	stock = "In stock",
	mass  = l.MASS,
}
local shipColumnHeading = {
	icon      = "",
	name      = l.NAME,
	amount    = "Amount",
	mass      = l.MASS,
	massTotal = "Total mass",
}

local stationColumnValue = {
	icon  = function (e) return equipIcon[e] and ui:Image("icons/goods/"..equipIcon[e]..".png") or "" end,
	name  = function (e) return lcore[e] end,
	price = function (e) return string.format("%0.2f", Game.player:GetDockedWith():GetEquipmentPrice(e)) end,
	stock = function (e) return Game.player:GetDockedWith():GetEquipmentStock(e) end,
	mass  = function (e) return string.format("%dt", EquipDef[e].mass) end,
}
local shipColumnValue = {
	icon      = function (e) return equipIcon[e] and ui:Image("icons/goods/"..equipIcon[e]..".png") or "" end,
	name      = function (e) return lcore[e] end,
	amount    = function (e) return Game.player:GetEquipCount(EquipDef[e].slot, e) end,
	mass      = function (e) return string.format("%dt", EquipDef[e].mass) end,
	massTotal = function (e) return string.format("%dt", Game.player:GetEquipCount(EquipDef[e].slot,e)*EquipDef[e].mass) end,
}

local EquipmentTableWidgets = {}

function EquipmentTableWidgets.Pair (config)
	local equipTypes = {}
	for k,v in pairs(EquipDef) do
		if config.isTradeable(v) and k ~= "NONE" then
			table.insert(equipTypes, k)
		end
	end
	table.sort(equipTypes)

	local stationTable =
		ui:Table()
			:SetRowSpacing(5)
			:SetColumnSpacing(10)
			:SetHeadingRow(utils.build_table(utils.map(function (k,v) return k,stationColumnHeading[v] end, ipairs(config.stationColumns))))
			:SetHeadingFont("LARGE")
			:SetMouseEnabled(true)

	local function fillStationTable ()
		stationTable:ClearRows()

		local rowEquip = {}
		local row = 1
		for i=1,#equipTypes do
			local e = equipTypes[i]
			stationTable:AddRow(utils.build_table(utils.map(function (k,v) return k,stationColumnValue[v](e) end, ipairs(config.stationColumns))))
			rowEquip[row] = e
			row = row + 1
		end

		return rowEquip
	end
	local stationRowEquip = fillStationTable()

	local shipTable =
		ui:Table()
			:SetRowSpacing(5)
			:SetColumnSpacing(10)
			:SetHeadingRow(utils.build_table(utils.map(function (k,v) return k,shipColumnHeading[v] end, ipairs(config.shipColumns))))
			:SetHeadingFont("LARGE")
			:SetMouseEnabled(true)

	local function fillShipTable ()
		shipTable:ClearRows()

		local rowEquip = {}
		local row = 1
		for i=1,#equipTypes do
			local e = equipTypes[i]
			local n = Game.player:GetEquipCount(EquipDef[e].slot, e)
			if n > 0 then
				local icon = equipIcon[e] and ui:Image("icons/goods/"..equipIcon[e]..".png") or ""
				shipTable:AddRow(utils.build_table(utils.map(function (k,v) return k,shipColumnValue[v](e) end, ipairs(config.shipColumns))))
				rowEquip[row] = e
				row = row + 1
			end
		end

		return rowEquip
	end
	local shipRowEquip = fillShipTable()

	local function onBuy (e)
		local player = Game.player
		local station = player:GetDockedWith()

		if station:GetEquipmentStock(e) <= 0 then
			Comms.Message(l.ITEM_IS_OUT_OF_STOCK)
			return
		end

		if player:GetEquipFree(EquipDef[e].slot) < 1 then
			Comms.Message(l.SHIP_IS_FULLY_LADEN)
			return
		end

		if player.freeCapacity < EquipDef[e].mass then
			Comms.Message(l.SHIP_IS_FULLY_LADEN)
			return
		end

		if player:GetMoney() < station:GetEquipmentPrice(e) then
			Comms.Message(l.YOU_NOT_ENOUGH_MONEY)
			return
		end

		assert(player:AddEquip(e) == 1)
		player:AddMoney(-station:GetEquipmentPrice(e))
		station:AddEquipmentStock(e, -1)
	end

	local function onSell (e)
		local player = Game.player
		local station = player:GetDockedWith()

		player:RemoveEquip(e)
		player:AddMoney(station:GetEquipmentPrice(e))
		station:AddEquipmentStock(e, 1)
	end

	stationTable.onRowClicked:Connect(function(row)
		local e = stationRowEquip[row+1]

		onBuy(e)

		stationRowEquip = fillStationTable()
		shipRowEquip = fillShipTable()
	end)

	shipTable.onRowClicked:Connect(function (row)
		local e = shipRowEquip[row+1]

		onSell(e)

		stationRowEquip = fillStationTable()
		shipRowEquip = fillShipTable()
	end)

	return stationTable, shipTable
end

return EquipmentTableWidgets
