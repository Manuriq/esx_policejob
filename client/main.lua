local Keys = {
	["ESC"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57, 
	["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177, 
	["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18,
	["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
	["LEFTSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
	["LEFTCTRL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RIGHTCTRL"] = 70, 
	["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178,
	["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173,
	["NENTER"] = 201, ["N4"] = 108, ["N5"] = 60, ["N6"] = 107, ["N+"] = 96, ["N-"] = 97, ["N7"] = 117, ["N8"] = 61, ["N9"] = 118
}

ESX                             = nil
local PlayerData                = {}
local GUI                       = {}
GUI.Time                        = 0
local HasAlreadyEnteredMarker   = false
local LastStation               = nil
local LastPart                  = nil
local LastPartNum               = nil
local LastEntity                = nil
local CurrentAction             = nil
local CurrentActionMsg          = ''
local CurrentActionData         = {}
local IsHandcuffed              = false

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
end)

function SetVehicleMaxMods(vehicle)

	local props = {
		modEngine       = 2,
		modBrakes       = 2,
		modTransmission = 2,
		modSuspension   = 3,
		modTurbo        = true,
	}

	ESX.Game.SetVehicleProperties(vehicle, props)

end

function OpenCloakroomMenu()

	ESX.UI.Menu.CloseAll()

	ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'cloakroom',
		{
			title    = 'Vestiaire',
			align    = 'top-left',
			elements = {
				{label = 'Tenue Civil',    value = 'citizen_wear'},
				{label = 'Tenue Policier', value = 'police_wear'},
			},
		},
		function(data, menu)
			
			menu.close()

			if data.current.value == 'citizen_wear' then
				
				ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin, jobSkin)
					TriggerEvent('skinchanger:loadSkin', skin)
				end)

			end

			if data.current.value == 'police_wear' then

				ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin, jobSkin)

					if skin.sex == 0 then
						TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_male)
					else
						TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_female)
					end
					
				end)

			end	

			CurrentAction     = 'menu_cloakroom'
			CurrentActionMsg  = 'Appuez sur ~INPUT_CONTEXT~ pour vous changer'
			CurrentActionData = {}

		end,
		function(data, menu)
			
			menu.close()

			CurrentAction     = 'menu_cloakroom'
			CurrentActionMsg  = 'Appuez sur ~INPUT_CONTEXT~ pour vous changer'
			CurrentActionData = {}
		end
	)

end

function OpenArmoryMenu(station)

	if Config.EnableArmoryManagement then

		local elements = {
			{label = 'Prendre Arme', value = 'get_weapon'},
			{label = 'Déposer Arme', value = 'put_weapon'}
		}

		if PlayerData.job.grade_name == 'boss' then
			table.insert(elements, {label = 'Acheter Armes', value = 'buy_weapons'})
		end

		ESX.UI.Menu.CloseAll()

		ESX.UI.Menu.Open(
			'default', GetCurrentResourceName(), 'armory',
			{
				title    = 'Armurerie',
				align    = 'top-left',
				elements = elements,
			},
			function(data, menu)

				if data.current.value == 'get_weapon' then
					OpenGetWeaponMenu()
				end

				if data.current.value == 'put_weapon' then
					OpenPutWeaponMenu()
				end

				if data.current.value == 'buy_weapons' then
					OpenBuyWeaponsMenu(station)
				end		

			end,
			function(data, menu)
				
				menu.close()

				CurrentAction     = 'menu_armory'
				CurrentActionMsg  = 'Appuez sur ~INPUT_CONTEXT~ pour accéder à l\'armurerie'
				CurrentActionData = {station = station}
			end
		)

	else

		local elements = {}

		for i=1, #Config.PoliceStations[station].AuthorizedWeapons, 1 do
			local weapon = Config.PoliceStations[station].AuthorizedWeapons[i]
			table.insert(elements, {label = ESX.GetWeaponLabel(weapon.name), value = weapon.name})
		end

		ESX.UI.Menu.CloseAll()

		ESX.UI.Menu.Open(
			'default', GetCurrentResourceName(), 'armory',
			{
				title    = 'Armurerie',
				align    = 'top-left',
				elements = elements,
			},
			function(data, menu)
				local weapon = data.current.value
				TriggerServerEvent('esx_policejob:giveWeapon', weapon,  1000)
			end,
			function(data, menu)

				menu.close()

				CurrentAction     = 'menu_armory'
				CurrentActionMsg  = 'Appuez sur ~INPUT_CONTEXT~ pour accéder à l\'armurerie'
				CurrentActionData = {station = station}

			end
		)

	end

end

function OpenVehicleSpawnerMenu(station, partNum)

	local elements = {}
	local vehicles = Config.PoliceStations[station].Vehicles

	for i=1, #Config.PoliceStations[station].AuthorizedVehicles, 1 do
		local vehicle = Config.PoliceStations[station].AuthorizedVehicles[i]
		table.insert(elements, {label = vehicle.label, value = vehicle.name})
	end

	ESX.UI.Menu.CloseAll()

	ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'vehicle_spawner',
		{
			title    = 'Véhicule',
			align    = 'top-left',
			elements = elements,
		},
		function(data, menu)

			menu.close()

			local model = data.current.value

			local vehicle, distance = ESX.Game.GetClosestVehicle({
				x = vehicles[partNum].SpawnPoint.x, 
				y = vehicles[partNum].SpawnPoint.y, 
				z = vehicles[partNum].SpawnPoint.z
			})

			if distance > 3.0 then

				local playerPed = GetPlayerPed(-1)

				if Config.MaxInService == -1 then

					ESX.Game.SpawnVehicle(model, {
						x = vehicles[partNum].SpawnPoint.x, 
						y = vehicles[partNum].SpawnPoint.y, 
						z = vehicles[partNum].SpawnPoint.z
					}, vehicles[partNum].Heading, function(vehicle)
						TaskWarpPedIntoVehicle(playerPed,  vehicle,  -1)
						SetVehicleMaxMods(vehicle)
					end)

				else

					ESX.TriggerServerCallback('esx_service:enableService', function(canTakeService, maxInService, inServiceCount)

						if canTakeService then

							ESX.Game.SpawnVehicle(model, {
								x = vehicles[partNum].SpawnPoint.x, 
								y = vehicles[partNum].SpawnPoint.y, 
								z = vehicles[partNum].SpawnPoint.z
							}, vehicles[partNum].Heading, function(vehicle)
								TaskWarpPedIntoVehicle(playerPed,  vehicle,  -1)
								SetVehicleMaxMods(vehicle)
							end)

						else
							ESX.ShowNotification('Service complet : ' .. inServiceCount .. '/' .. maxInService)
						end

					end, 'police')

				end

			else
				ESX.ShowNotification('Il y a déja un véhicule de sorti')
			end

		end,
		function(data, menu)

			menu.close()

			CurrentAction     = 'menu_vehicle_spawner'
			CurrentActionMsg  = 'Appuez sur ~INPUT_CONTEXT~ pour sortir un véhicule'
			CurrentActionData = {station = station, partNum = partNum}

		end
	)

end

function OpenPoliceActionsMenu()
	
	ESX.UI.Menu.CloseAll()

	ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'police_actions',
		{
			title    = 'Police',
			align    = 'top-left',
			elements = {
		  	{label = 'Interaction citoyen',  value = 'citizen_interaction'},
		  	{label = 'Interaction véhicule', value = 'vehicle_interaction'},
		  	{label = 'Placer objets',        value = 'object_spawner'},
			},
		},
		function(data, menu)

			if data.current.value == 'citizen_interaction' then

				ESX.UI.Menu.Open(
					'default', GetCurrentResourceName(), 'citizen_interaction',
					{
						title    = 'Interaction Citoyen',
						align    = 'top-left',
						elements = {
							{label = 'Carte d\'identité',     value = 'identity_card'},
							{label = 'Fouiller',              value = 'body_search'},
							{label = 'Menotter / Démenotter', value = 'handcuff'},
							{label = 'Mettre dans véhicule',  value = 'put_in_vehicle'},
							{label = 'Amende',                value = 'fine'}
						},
					},
					function(data2, menu2)

						local player, distance = ESX.Game.GetClosestPlayer()

						if distance ~= -1 and distance <= 3.0 then

							if data2.current.value == 'identity_card' then
								OpenIdentityCardMenu(player)
							end

							if data2.current.value == 'body_search' then
								OpenBodySearchMenu(player)
							end

							if data2.current.value == 'handcuff' then
								TriggerServerEvent('esx_policejob:handcuff', GetPlayerServerId(player))
							end

							if data2.current.value == 'put_in_vehicle' then
								TriggerServerEvent('esx_policejob:putInVehicle', GetPlayerServerId(player))
							end

							if data2.current.value == 'fine' then
								OpenFineMenu(player)
							end

						else
							ESX.ShowNotification('Aucun joueur à proximité')
						end

					end,
					function(data2, menu2)
						menu2.close()
					end
				)

			end

			if data.current.value == 'vehicle_interaction' then

				ESX.UI.Menu.Open(
					'default', GetCurrentResourceName(), 'vehicle_interaction',
					{
						title    = 'Interaction Véhicule',
						align    = 'top-left',
						elements = {
					  	{label = 'Infos véhicule',      value = 'vehicle_infos'},
					  	{label = 'Crocheter véhicule',  value = 'hijack_vehicle'},
						},
					},
					function(data2, menu2)

						local vehicle, distance = ESX.Game.GetClosestVehicle()

						if distance ~= -1 and distance <= 3.0 then

							local vehicleData = ESX.Game.GetVehicleProperties(vehicle)

							if data2.current.value == 'vehicle_infos' then
								OpenVehicleInfosMenu(vehicleData)
							end

							if data2.current.value == 'hijack_vehicle' then

					      local playerPed = GetPlayerPed(-1)
					      local coords    = GetEntityCoords(playerPed)

					      if IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 5.0) then

					        local vehicle, distance = ESX.Game.GetClosestVehicle({
					        	x = coords.x,
					        	y = coords.y,
					        	z = coords.z
					        })

					        if DoesEntityExist(vehicle) then

					        	Citizen.CreateThread(function()

											TaskStartScenarioInPlace(playerPed, "WORLD_HUMAN_WELDING", 0, true)

											Wait(20000)

											ClearPedTasksImmediately(playerPed)

						        	SetVehicleDoorsLocked(vehicle, 1)
					            SetVehicleDoorsLockedForAllPlayers(vehicle, false)

					            TriggerEvent('esx:showNotification', 'Véhicule ~g~déverouillé~s~')

					        	end)

					        end

					      end

							end

						else
							ESX.ShowNotification('Aucun véhicule à proximité')
						end

					end,
					function(data2, menu2)
						menu2.close()
					end
				)

			end

			if data.current.value == 'object_spawner' then

				ESX.UI.Menu.Open(
					'default', GetCurrentResourceName(), 'citizen_interaction',
					{
						title    = 'Interactions Voirie',
						align    = 'top-left',
						elements = {
					    {label = 'Plot',     value = 'prop_roadcone02a'},
					    {label = 'Barrière', value = 'prop_barrier_work06a'},
					    {label = 'Herse',    value = 'p_ld_stinger_s'},
					    {label = 'Caisse',   value = 'prop_boxpile_07d'},
					    {label = 'Caisse',   value = 'hei_prop_cash_crate_half_full'}
						},
					},
					function(data2, menu2)


						local model     = data2.current.value
						local playerPed = GetPlayerPed(-1)
						local coords    = GetEntityCoords(playerPed)
						local forward   = GetEntityForwardVector(playerPed)
						local x, y, z   = table.unpack(coords + forward * 1.0)

						if model == 'prop_roadcone02a' then
							z = z - 2.0
						end

						ESX.Game.SpawnObject(model, {
							x = x,
							y = y,
							z = z
						}, 3.0, function(obj)
							SetEntityHeading(obj, GetEntityHeading(playerPed))
							PlaceObjectOnGroundProperly(obj)
						end)

					end,
					function(data2, menu2)
						menu2.close()
					end
				)

			end

		end,
		function(data, menu)
			
			menu.close()

		end
	)

end

function OpenIdentityCardMenu(player)

	ESX.TriggerServerCallback('esx_policejob:getOtherPlayerData', function(data)

		local jobLabel = nil

		if data.job.grade_label ~= nil and  data.job.grade_label ~= '' then
			jobLabel = 'Job : ' .. data.job.label .. ' - ' .. data.job.grade_label
		else
			jobLabel = 'Job : ' .. data.job.label
		end

		local elements = {
			{label = 'Nom : ' .. data.name, value = nil},
			{label = jobLabel,              value = nil},
		}

		if data.drunk ~= nil then
			table.insert(elements, {label = 'Alcoolémie : ' .. data.drunk .. '%', value = nil})
		end

		if data.licenses ~= nil then

			table.insert(elements, {label = '--- Licenses ---', value = nil})

			for i=1, #data.licenses, 1 do
				table.insert(elements, {label = data.licenses[i].label, value = nil})
			end

		end

		ESX.UI.Menu.Open(
			'default', GetCurrentResourceName(), 'citizen_interaction',
			{
				title    = 'Interaction Citoyen',
				align    = 'top-left',
				elements = elements,
			},
			function(data, menu)

			end,
			function(data, menu)
				menu.close()
			end
		)

	end, GetPlayerServerId(player))

end

function OpenBodySearchMenu(player)

	ESX.TriggerServerCallback('esx_policejob:getOtherPlayerData', function(data)

		local elements = {}
		
		local blackMoney = 0

		for i=1, #data.accounts, 1 do
			if data.accounts[i].name == 'black_money' then
				blackMoney = data.accounts[i].money
			end
		end

		table.insert(elements, {
			label          = 'Confisquer argent sale : $' .. blackMoney,
			value          = 'black_money',
			itemType       = 'item_account',
			amount         = blackMoney
		})

		table.insert(elements, {label = '--- Armes ---', value = nil})

		for i=1, #data.weapons, 1 do
			table.insert(elements, {
				label          = 'Confisquer ' .. ESX.GetWeaponLabel(data.weapons[i].name),
				value          = data.weapons[i].name,
				itemType       = 'item_weapon',
				amount         = data.ammo,
			})
		end

		table.insert(elements, {label = '--- Inventaire ---', value = nil})

		for i=1, #data.inventory, 1 do
			if data.inventory[i].count > 0 then
				table.insert(elements, {
					label          = 'Confisquer x' .. data.inventory[i].count .. ' ' .. data.inventory[i].label,
					value          = data.inventory[i].name,
					itemType       = 'item_standard',
					amount         = data.inventory[i].count,
				})
			end
		end
		
		
		ESX.UI.Menu.Open(
			'default', GetCurrentResourceName(), 'body_search',
			{
				title    = 'Fouille',
				align    = 'top-left',
				elements = elements,
			},
			function(data, menu)

				local itemType = data.current.itemType
				local itemName = data.current.value
				local amount   = data.current.amount

				if data.current.value ~= nil then

					TriggerServerEvent('esx_policejob:confiscatePlayerItem', GetPlayerServerId(player), itemType, itemName, amount)

					OpenBodySearchMenu(player)

				end

			end,
			function(data, menu)
				menu.close()
			end
		)

	end, GetPlayerServerId(player))

end

function OpenFineMenu(player)

	ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'fine',
		{
			title    = 'Amende',
			align    = 'top-left',
			elements = {
		  	{label = 'Code de la route', value = 0},
		  	{label = 'Délit mineur',     value = 1},
		  	{label = 'Délit moyen',      value = 2},
		  	{label = 'Délit grave',      value = 3}
			},
		},
		function(data, menu)
			
			OpenFineCategoryMenu(player, data.current.value)

		end,
		function(data, menu)
			menu.close()
		end
	)

end

function OpenFineCategoryMenu(player, category)

	ESX.TriggerServerCallback('esx_policejob:getFineList', function(fines)

		local elements = {}
		
		for i=1, #fines, 1 do
			table.insert(elements, {
				label     = fines[i].label .. ' $' .. fines[i].amount,
				value     = fines[i].id,
				amount    = fines[i].amount,
				fineLabel = fines[i].label
			})
		end

		ESX.UI.Menu.Open(
			'default', GetCurrentResourceName(), 'fine_category',
			{
				title    = 'Amende',
				align    = 'top-left',
				elements = elements,
			},
			function(data, menu)

				local label  = data.current.fineLabel
				local amount = data.current.amount

				menu.close()

				if Config.EnablePlayerManagement then
					TriggerServerEvent('esx_billing:sendBill', GetPlayerServerId(player), 'society_police', 'Amende : ' .. label, amount)
				else
					TriggerServerEvent('esx_billing:sendBill', GetPlayerServerId(player), '', 'Amende : ' .. label, amount)
				end

				ESX.SetTimeout(300, function()
					OpenFineCategoryMenu(player, category)
				end)

			end,
			function(data, menu)
				menu.close()
			end
		)

	end, category)

end

function OpenVehicleInfosMenu(vehicleData)

	ESX.TriggerServerCallback('esx_policejob:getVehicleInfos', function(infos)

		local elements = {}

		table.insert(elements, {label = 'N°: ' .. infos.plate, value = nil})

		if infos.owner == nil then
			table.insert(elements, {label = 'Propriétaire : Inconnu', value = nil})
		else
			table.insert(elements, {label = 'Propriétaire : ' .. infos.owner, value = nil})
		end

		ESX.UI.Menu.Open(
			'default', GetCurrentResourceName(), 'vehicle_infos',
			{
				title    = 'Infos Véhicule',
				align    = 'top-left',
				elements = elements,
			},
			nil,
			function(data, menu)
				menu.close()
			end
		)

	end, vehicleData.plate)

end

function OpenGetWeaponMenu()

	ESX.TriggerServerCallback('esx_policejob:getArmoryWeapons', function(weapons)

		local elements = {}

		for i=1, #weapons, 1 do
			if weapons[i].count > 0 then
				table.insert(elements, {label = 'x' .. weapons[i].count .. ' ' .. ESX.GetWeaponLabel(weapons[i].name), value = weapons[i].name})
			end
		end

		ESX.UI.Menu.Open(
			'default', GetCurrentResourceName(), 'armory_get_weapon',
			{
				title    = 'Armurerie - Prendre Arme',
				align    = 'top-left',
				elements = elements,
			},
			function(data, menu)

				menu.close()

				ESX.TriggerServerCallback('esx_policejob:removeArmoryWeapon', function()
					OpenGetWeaponMenu()
				end, data.current.value)

			end,
			function(data, menu)
				menu.close()
			end
		)
		
	end)

end

function OpenPutWeaponMenu()

	local elements   = {}
	local playerPed  = GetPlayerPed(-1)
	local weaponList = ESX.GetWeaponList()

	for i=1, #weaponList, 1 do

		local weaponHash = GetHashKey(weaponList[i].name)

		if HasPedGotWeapon(playerPed,  weaponHash,  false) and weaponList[i].name ~= 'WEAPON_UNARMED' then
			local ammo = GetAmmoInPedWeapon(playerPed, weaponHash)
			table.insert(elements, {label = weaponList[i].label, value = weaponList[i].name})
		end

	end

	ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'armory_put_weapon',
		{
			title    = 'Armurerie - Déposer Arme',
			align    = 'top-left',
			elements = elements,
		},
		function(data, menu)
			
			menu.close()

			ESX.TriggerServerCallback('esx_policejob:addArmoryWeapon', function()
				OpenPutWeaponMenu()
			end, data.current.value)

		end,
		function(data, menu)
			menu.close()
		end
	)

end

function OpenBuyWeaponsMenu(station)

	ESX.TriggerServerCallback('esx_policejob:getArmoryWeapons', function(weapons)

		local elements = {}

		for i=1, #Config.PoliceStations[station].AuthorizedWeapons, 1 do
			
			local weapon = Config.PoliceStations[station].AuthorizedWeapons[i]
			local count  = 0

			for i=1, #weapons, 1 do
				if weapons[i].name == weapon.name then
					count = weapons[i].count
					break
				end
			end

			table.insert(elements, {label = 'x' .. count .. ' ' .. ESX.GetWeaponLabel(weapon.name) .. ' $' .. weapon.price, value = weapon.name, price = weapon.price})
		
		end

		ESX.UI.Menu.Open(
			'default', GetCurrentResourceName(), 'armory_buy_weapons',
			{
				title    = 'Armurerie - Acheter Armes',
				align    = 'top-left',
				elements = elements,
			},
			function(data, menu)

				ESX.TriggerServerCallback('esx_policejob:buy', function(hasEnoughMoney)
					
					if hasEnoughMoney then
						ESX.TriggerServerCallback('esx_policejob:addArmoryWeapon', function()
							OpenBuyWeaponsMenu(station)
						end, data.current.value)
					else
						ESX.ShowNotification('Vous n\'avez pas assez d\'argent')
					end

				end, data.current.price)

			end,
			function(data, menu)
				menu.close()
			end
		)

	end)

end

function OpenBossActionsMenu()

	ESX.UI.Menu.CloseAll()

	ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'realestateagent',
		{
			title    = PlayerData.job.grade_label,
			elements = {
				{label = 'Retirer argent société', value = 'withdraw_society_money'},
				{label = 'Déposer argent',         value = 'deposit_money'},
			}
		},
		function(data, menu)

			if data.current.value == 'withdraw_society_money' then

				ESX.UI.Menu.Open(
					'dialog', GetCurrentResourceName(), 'withdraw_society_money_amount',
					{
						title = 'Montant du retrait'
					},
					function(data, menu)

						local amount = tonumber(data.value)

						if amount == nil then
							ESX.ShowNotification('Montant invalide')
						else
							menu.close()
							TriggerServerEvent('esx_society:withdrawMoney', 'police', amount)
						end

					end,
					function(data, menu)
						menu.close()
					end
				)

			end

			if data.current.value == 'deposit_money' then

				ESX.UI.Menu.Open(
					'dialog', GetCurrentResourceName(), 'deposit_money_amount',
					{
						title = 'Montant du dépôt'
					},
					function(data, menu)

						local amount = tonumber(data.value)

						if amount == nil then
							ESX.ShowNotification('Montant invalide')
						else
							menu.close()
							TriggerServerEvent('esx_society:depositMoney', 'police', amount)
						end

					end,
					function(data, menu)
						menu.close()
					end
				)

			end

		end,
		function(data, menu)

			menu.close()

			CurrentAction     = 'menu_boss_actions'
			CurrentActionMsg  = 'Appuez sur ~INPUT_CONTEXT~ pour ouvrir le menu'
			CurrentActionData = {}

		end
	)

end

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
  PlayerData = xPlayer 
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
  PlayerData.job = job
end)

RegisterNetEvent('esx_phone:loaded')
AddEventHandler('esx_phone:loaded', function(phoneNumber, contacts)

	local specialContact = {
		name       = 'Police',
		number     = 'police',
		base64Icon = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAyJpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuMy1jMDExIDY2LjE0NTY2MSwgMjAxMi8wMi8wNi0xNDo1NjoyNyAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENTNiAoV2luZG93cykiIHhtcE1NOkluc3RhbmNlSUQ9InhtcC5paWQ6NDFGQTJDRkI0QUJCMTFFN0JBNkQ5OENBMUI4QUEzM0YiIHhtcE1NOkRvY3VtZW50SUQ9InhtcC5kaWQ6NDFGQTJDRkM0QUJCMTFFN0JBNkQ5OENBMUI4QUEzM0YiPiA8eG1wTU06RGVyaXZlZEZyb20gc3RSZWY6aW5zdGFuY2VJRD0ieG1wLmlpZDo0MUZBMkNGOTRBQkIxMUU3QkE2RDk4Q0ExQjhBQTMzRiIgc3RSZWY6ZG9jdW1lbnRJRD0ieG1wLmRpZDo0MUZBMkNGQTRBQkIxMUU3QkE2RDk4Q0ExQjhBQTMzRiIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/PoW66EYAAAjGSURBVHjapJcLcFTV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'
	}

	TriggerEvent('esx_phone:addSpecialContact', specialContact.name, specialContact.number, specialContact.base64Icon)

end)

AddEventHandler('esx_policejob:hasEnteredMarker', function(station, part, partNum)

	if part == 'Cloakroom' then
		CurrentAction     = 'menu_cloakroom'
		CurrentActionMsg  = 'Appuez sur ~INPUT_CONTEXT~ pour vous changer'
		CurrentActionData = {}
	end

	if part == 'Armory' then
		CurrentAction     = 'menu_armory'
		CurrentActionMsg  = 'Appuez sur ~INPUT_CONTEXT~ pour accéder à l\'armurerie'
		CurrentActionData = {station = station}
	end

	if part == 'VehicleSpawner' then
		CurrentAction     = 'menu_vehicle_spawner'
		CurrentActionMsg  = 'Appuez sur ~INPUT_CONTEXT~ pour sortir un véhicule'
		CurrentActionData = {station = station, partNum = partNum}
	end

	if part == 'HelicopterSpawner' then

		local helicopters = Config.PoliceStations[station].Helicopters
		
		local vehicle, distance = ESX.Game.GetClosestVehicle({
			x = helicopters[partNum].SpawnPoint.x, 
			y = helicopters[partNum].SpawnPoint.y, 
			z = helicopters[partNum].SpawnPoint.z
		})

		if distance > 3.0 then

			ESX.Game.SpawnVehicle('polmav', {
				x = helicopters[partNum].SpawnPoint.x, 
				y = helicopters[partNum].SpawnPoint.y, 
				z = helicopters[partNum].SpawnPoint.z
			}, helicopters[partNum].Heading, function(vehicle)
				SetVehicleModKit(vehicle, 0)
				SetVehicleLivery(vehicle, 0)
			end)

		end

	end

	if part == 'VehicleDeleter' then

		local playerPed = GetPlayerPed(-1)

		if IsPedInAnyVehicle(playerPed,  false) then

			local vehicle, distance = ESX.Game.GetClosestVehicle()

			if distance <= 2.0 then
				CurrentAction     = 'delete_vehicle'
				CurrentActionMsg  = 'Appuez sur ~INPUT_CONTEXT~ pour ranger le véhicule'
				CurrentActionData = {vehicle = vehicle}
			end

		end

	end

	if part == 'BossActions' then
		CurrentAction     = 'menu_boss_actions'
		CurrentActionMsg  = 'Appuez sur ~INPUT_CONTEXT~ pour ouvrir le menu'
		CurrentActionData = {}
	end

end)

AddEventHandler('esx_policejob:hasExitedMarker', function(station, part, partNum)
	CurrentAction = nil
end)

AddEventHandler('esx_policejob:hasEnteredEntityZone', function(entity)

	local playerPed = GetPlayerPed(-1)

	if PlayerData.job ~= nil and PlayerData.job.name == 'police' and not IsPedInAnyVehicle(playerPed, false) then
		CurrentAction     = 'remove_entity'
		CurrentActionMsg  = 'Appuez sur ~INPUT_CONTEXT~ pour enlever l\'objet'
		CurrentActionData = {entity = entity}
	end

	if GetEntityModel(entity) == GetHashKey('p_ld_stinger_s') then

		local playerPed = GetPlayerPed(-1)
		local coords    = GetEntityCoords(playerPed)

		if IsPedInAnyVehicle(playerPed,  false) then

			local vehicle, distance = ESX.Game.GetClosestVehicle({
				x = coords.x,
				y = coords.y,
				z = coords.z
			})

			if distance <= 1.0 then

				for i=0, 7, 1 do
					SetVehicleTyreBurst(vehicle,  i,  true,  1000)
				end

			end

		end

	end

end)

AddEventHandler('esx_policejob:hasExitedEntityZone', function(entity)

	if CurrentAction == 'remove_entity' then
		CurrentAction = nil
	end

end)

RegisterNetEvent('esx_policejob:handcuff')
AddEventHandler('esx_policejob:handcuff', function()

	IsHandcuffed    = not IsHandcuffed;
	local playerPed = GetPlayerPed(-1)

	Citizen.CreateThread(function()

		if IsHandcuffed then
			
			RequestAnimDict('mp_arresting')
			
			while not HasAnimDictLoaded('mp_arresting') do
				Wait(100)
			end
			
			TaskPlayAnim(playerPed, 'mp_arresting', 'idle', 8.0, -8, -1, 49, 0, 0, 0, 0)
			SetEnableHandcuffs(playerPed, true)
			SetPedCanPlayGestureAnims(playerPed, false)
			FreezeEntityPosition(playerPed,  true)
		
		else
			
			ClearPedSecondaryTask(playerPed)
			SetEnableHandcuffs(playerPed, false)
			SetPedCanPlayGestureAnims(playerPed,  true)
			FreezeEntityPosition(playerPed, false)
		
		end

	end)
end)

RegisterNetEvent('esx_policejob:putInVehicle')
AddEventHandler('esx_policejob:putInVehicle', function()

	local playerPed = GetPlayerPed(-1)
	local coords    = GetEntityCoords(playerPed)

  if IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 5.0) then

    local vehicle, distance = ESX.Game.GetClosestVehicle({
    	x = coords.x,
    	y = coords.y,
    	z = coords.z
    })

    if DoesEntityExist(vehicle) then

    	local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
    	local freeSeat = nil

    	for i=maxSeats - 1, 0, -1 do
    		if IsVehicleSeatFree(vehicle,  i) then
    			freeSeat = i
    			break
    		end
    	end

    	if freeSeat ~= nil then
    		TaskWarpPedIntoVehicle(playerPed,  vehicle,  freeSeat)
    	end

    end

  end	

end)

-- Handcuff
Citizen.CreateThread(function()
	while true do
		Wait(0)
		if IsHandcuffed then
			DisableControlAction(0, 142, true) -- MeleeAttackAlternate
			DisableControlAction(0, 30,  true) -- MoveLeftRight
			DisableControlAction(0, 31,  true) -- MoveUpDown
		end
	end
end)

-- Create blips
Citizen.CreateThread(function()

	for k,v in pairs(Config.PoliceStations) do

		local blip = AddBlipForCoord(v.Blip.Pos.x, v.Blip.Pos.y, v.Blip.Pos.z)
	  
	  SetBlipSprite (blip, 60)
	  SetBlipDisplay(blip, 4)
	  SetBlipScale  (blip, 1.2)
	  SetBlipColour (blip, v.Blip.Color)
	  SetBlipAsShortRange(blip, true)
		
		BeginTextCommandSetBlipName("STRING")
	  AddTextComponentString("Commissariat")
	  EndTextCommandSetBlipName(blip)

	end

end)

-- Display markers
Citizen.CreateThread(function()
	while true do
		
		Wait(0)
		
		if PlayerData.job ~= nil and PlayerData.job.name == 'police' then

			local playerPed = GetPlayerPed(-1)
			local coords    = GetEntityCoords(playerPed)
			
			for k,v in pairs(Config.PoliceStations) do

				for i=1, #v.Cloakrooms, 1 do
					if GetDistanceBetweenCoords(coords,  v.Cloakrooms[i].x,  v.Cloakrooms[i].y,  v.Cloakrooms[i].z,  true) < Config.DrawDistance then
						DrawMarker(Config.MarkerType, v.Cloakrooms[i].x, v.Cloakrooms[i].y, v.Cloakrooms[i].z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, Config.MarkerSize.x, Config.MarkerSize.y, Config.MarkerSize.z, Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, false, false, false, false)
					end
				end

				for i=1, #v.Armories, 1 do
					if GetDistanceBetweenCoords(coords,  v.Armories[i].x,  v.Armories[i].y,  v.Armories[i].z,  true) < Config.DrawDistance then
						DrawMarker(Config.MarkerType, v.Armories[i].x, v.Armories[i].y, v.Armories[i].z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, Config.MarkerSize.x, Config.MarkerSize.y, Config.MarkerSize.z, Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, false, false, false, false)
					end
				end

				for i=1, #v.Vehicles, 1 do
					if GetDistanceBetweenCoords(coords,  v.Vehicles[i].Spawner.x,  v.Vehicles[i].Spawner.y,  v.Vehicles[i].Spawner.z,  true) < Config.DrawDistance then
						DrawMarker(Config.MarkerType, v.Vehicles[i].Spawner.x, v.Vehicles[i].Spawner.y, v.Vehicles[i].Spawner.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, Config.MarkerSize.x, Config.MarkerSize.y, Config.MarkerSize.z, Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, false, false, false, false)
					end
				end

				for i=1, #v.VehicleDeleters, 1 do
					if GetDistanceBetweenCoords(coords,  v.VehicleDeleters[i].x,  v.VehicleDeleters[i].y,  v.VehicleDeleters[i].z,  true) < Config.DrawDistance then
						DrawMarker(Config.MarkerType, v.VehicleDeleters[i].x, v.VehicleDeleters[i].y, v.VehicleDeleters[i].z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, Config.MarkerSize.x, Config.MarkerSize.y, Config.MarkerSize.z, Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, false, false, false, false)
					end
				end

				if Config.EnablePlayerManagement and PlayerData.job ~= nil and PlayerData.job.name == 'police' and PlayerData.job.grade_name == 'boss' then

					for i=1, #v.BossActions, 1 do
						if not v.BossActions[i].disabled and GetDistanceBetweenCoords(coords,  v.BossActions[i].x,  v.BossActions[i].y,  v.BossActions[i].z,  true) < Config.DrawDistance then
							DrawMarker(Config.MarkerType, v.BossActions[i].x, v.BossActions[i].y, v.BossActions[i].z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, Config.MarkerSize.x, Config.MarkerSize.y, Config.MarkerSize.z, Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, false, false, false, false)
						end
					end

				end

			end

		end

	end
end)

-- Enter / Exit marker events
Citizen.CreateThread(function()

	while true do

		Wait(0)

		if PlayerData.job ~= nil and PlayerData.job.name == 'police' then

			local playerPed      = GetPlayerPed(-1)
			local coords         = GetEntityCoords(playerPed)
			local isInMarker     = false
			local currentStation = nil
			local currentPart    = nil
			local currentPartNum = nil

			for k,v in pairs(Config.PoliceStations) do

				for i=1, #v.Cloakrooms, 1 do
					if GetDistanceBetweenCoords(coords,  v.Cloakrooms[i].x,  v.Cloakrooms[i].y,  v.Cloakrooms[i].z,  true) < Config.MarkerSize.x then
						isInMarker     = true
						currentStation = k
						currentPart    = 'Cloakroom'
						currentPartNum = i
					end
				end

				for i=1, #v.Armories, 1 do
					if GetDistanceBetweenCoords(coords,  v.Armories[i].x,  v.Armories[i].y,  v.Armories[i].z,  true) < Config.MarkerSize.x then
						isInMarker     = true
						currentStation = k
						currentPart    = 'Armory'
						currentPartNum = i
					end
				end

				for i=1, #v.Vehicles, 1 do
					
					if GetDistanceBetweenCoords(coords,  v.Vehicles[i].Spawner.x,  v.Vehicles[i].Spawner.y,  v.Vehicles[i].Spawner.z,  true) < Config.MarkerSize.x then
						isInMarker     = true
						currentStation = k
						currentPart    = 'VehicleSpawner'
						currentPartNum = i
					end

					if GetDistanceBetweenCoords(coords,  v.Vehicles[i].SpawnPoint.x,  v.Vehicles[i].SpawnPoint.y,  v.Vehicles[i].SpawnPoint.z,  true) < Config.MarkerSize.x then
						isInMarker     = true
						currentStation = k
						currentPart    = 'VehicleSpawnPoint'
						currentPartNum = i
					end

				end

				for i=1, #v.Helicopters, 1 do
					
					if GetDistanceBetweenCoords(coords,  v.Helicopters[i].Spawner.x,  v.Helicopters[i].Spawner.y,  v.Helicopters[i].Spawner.z,  true) < Config.MarkerSize.x then
						isInMarker     = true
						currentStation = k
						currentPart    = 'HelicopterSpawner'
						currentPartNum = i
					end

					if GetDistanceBetweenCoords(coords,  v.Helicopters[i].SpawnPoint.x,  v.Helicopters[i].SpawnPoint.y,  v.Helicopters[i].SpawnPoint.z,  true) < Config.MarkerSize.x then
						isInMarker     = true
						currentStation = k
						currentPart    = 'HelicopterSpawnPoint'
						currentPartNum = i
					end

				end

				for i=1, #v.VehicleDeleters, 1 do
					if GetDistanceBetweenCoords(coords,  v.VehicleDeleters[i].x,  v.VehicleDeleters[i].y,  v.VehicleDeleters[i].z,  true) < Config.MarkerSize.x then
						isInMarker     = true
						currentStation = k
						currentPart    = 'VehicleDeleter'
						currentPartNum = i
					end
				end

				if Config.EnablePlayerManagement and PlayerData.job ~= nil and PlayerData.job.name == 'police' and PlayerData.job.grade_name == 'boss' then

					for i=1, #v.BossActions, 1 do
						if GetDistanceBetweenCoords(coords,  v.BossActions[i].x,  v.BossActions[i].y,  v.BossActions[i].z,  true) < Config.MarkerSize.x then
							isInMarker     = true
							currentStation = k
							currentPart    = 'BossActions'
							currentPartNum = i
						end
					end

				end

			end

			local hasExited = false

			if isInMarker and not HasAlreadyEnteredMarker or (isInMarker and (LastStation ~= currentStation or LastPart ~= currentPart or LastPartNum ~= currentPartNum) ) then
				
				if
					(LastStation ~= nil and LastPart ~= nil and LastPartNum ~= nil) and
					(LastStation ~= currentStation or LastPart ~= currentPart or LastPartNum ~= currentPartNum)
				then
					TriggerEvent('esx_policejob:hasExitedMarker', LastStation, LastPart, LastPartNum)
					hasExited = true
				end

				HasAlreadyEnteredMarker = true
				LastStation             = currentStation
				LastPart                = currentPart
				LastPartNum             = currentPartNum
				
				TriggerEvent('esx_policejob:hasEnteredMarker', currentStation, currentPart, currentPartNum)
			end

			if not hasExited and not isInMarker and HasAlreadyEnteredMarker then
				
				HasAlreadyEnteredMarker = false
				
				TriggerEvent('esx_policejob:hasExitedMarker', LastStation, LastPart, LastPartNum)
			end

		end

	end
end)

-- Enter / Exit entity zone events
Citizen.CreateThread(function()
	while true do

		Citizen.Wait(0)

		local playerPed = GetPlayerPed(-1)
		local coords    = GetEntityCoords(playerPed)

		local entity, distance = ESX.Game.GetClosestObject({
			'prop_roadcone02a',
			'prop_barrier_work06a',
			'p_ld_stinger_s',
			'prop_boxpile_07d',
			'hei_prop_cash_crate_half_full'
		})

		if distance ~= -1 and distance <= 3.0 then

 			if LastEntity ~= entity then
				TriggerEvent('esx_policejob:hasEnteredEntityZone', entity)
				LastEntity = entity
			end

		else

			if LastEntity ~= nil then
				TriggerEvent('esx_policejob:hasExitedEntityZone', LastEntity)
				LastEntity = nil
			end

		end

	end
end)

-- Key Controls
Citizen.CreateThread(function()
	while true do

		Citizen.Wait(0)

		if CurrentAction ~= nil then

			SetTextComponentFormat('STRING')
			AddTextComponentString(CurrentActionMsg)
			DisplayHelpTextFromStringLabel(0, 0, 1, -1)

			if IsControlPressed(0,  Keys['E']) and PlayerData.job ~= nil and PlayerData.job.name == 'police' and (GetGameTimer() - GUI.Time) > 150 then

				if CurrentAction == 'menu_cloakroom' then
					OpenCloakroomMenu()
				end

				if CurrentAction == 'menu_armory' then
					OpenArmoryMenu(CurrentActionData.station)
				end

				if CurrentAction == 'menu_vehicle_spawner' then
					OpenVehicleSpawnerMenu(CurrentActionData.station, CurrentActionData.partNum)
				end

				if CurrentAction == 'delete_vehicle' then

					if
						GetEntityModel(vehicle) == GetHashKey('police')  or
						GetEntityModel(vehicle) == GetHashKey('police2') or
						GetEntityModel(vehicle) == GetHashKey('police3') or
						GetEntityModel(vehicle) == GetHashKey('police4') or
						GetEntityModel(vehicle) == GetHashKey('policeb') or
						GetEntityModel(vehicle) == GetHashKey('policet')
					then
						TriggerServerEvent('esx_service:disableService', 'police')
					end
					
					ESX.Game.DeleteVehicle(CurrentActionData.vehicle)
				end

				if CurrentAction == 'menu_boss_actions' then
					OpenBossActionsMenu()
				end

				if CurrentAction == 'remove_entity' then
					DeleteEntity(CurrentActionData.entity)
				end

				CurrentAction = nil
				GUI.Time      = GetGameTimer()
				
			end

		end

		if IsControlPressed(0,  Keys['F6']) and PlayerData.job ~= nil and PlayerData.job.name == 'police' and not ESX.UI.Menu.IsOpen('default', GetCurrentResourceName(), 'police_actions') and (GetGameTimer() - GUI.Time) > 150 then
			OpenPoliceActionsMenu()
			GUI.Time = GetGameTimer()
		end

	end
end)
