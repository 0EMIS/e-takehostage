function GetKeyCode(key)
    local keyMapping = {
        ["a"] = 34, ["b"] = 29, ["c"] = 44, ["d"] = 36, ["e"] = 38, ["f"] = 23,
        ["g"] = 47, ["h"] = 74, ["i"] = 36, ["j"] = 75, ["k"] = 74, ["l"] = 72,
    }

    return keyMapping[key] or -1  
end

local localePath = ("locales/%s.lua"):format(Config.Locale)
local localeFile = LoadResourceFile(GetCurrentResourceName(), localePath)
assert(localeFile, "Locale file not found: " .. localePath)
assert(load(localeFile))()

local function Translate(key)
    return Locales[Config.Locale][key] or key
end

local takeHostage = {
    allowedWeapons = Config.allowedWeapons, 
    InProgress = false,
    type = '',
    targetSrc = -1,
    aggressor = {
        animDict = 'anim@gangops@hostage@',
        anim = 'perp_idle',
        flag = 49,
    },
    hostage = {
        animDict = 'anim@gangops@hostage@',
        anim = 'victim_idle',
        attachX = -0.24,
        attachY = 0.11,
        attachZ = 0.0,
        flag = 49,
    }
}

function GetWeaponName(weaponHash)
    for name, _ in pairs(Config.allowedWeapons) do
        if weaponHash == GetHashKey(name) then
            return name
        end
    end
    return nil
end

RegisterCommand(Config.commandName, function()
    local playerPed = PlayerPedId()

    if IsEntityDead(playerPed) then
        lib.notify({type = 'error', description = Translate('cannot_use_dead'), position = 'top'})
        return
    end

    local currentWeapon = GetSelectedPedWeapon(playerPed)

    local currentWeaponName = GetWeaponName(currentWeapon)

    if currentWeapon == GetHashKey("WEAPON_UNARMED") then
        lib.notify({type = 'error', description = Translate('no_weapon'), position = 'top'})
        return
    end

    if not Config.allowedWeapons[currentWeaponName] then
        lib.notify({type = 'error', description = Translate('weapon_not_allowed'), position = 'top'})
        return
    end

    local closestPlayer, closestPlayerDistance = ESX.Game.GetClosestPlayer()
    if closestPlayerDistance == -1 or closestPlayerDistance > 3.0 then
        lib.notify({type = 'error', description = Translate('no_players_nearby'), position = 'top'})
        return
    end

	if not takeHostage.InProgress then
		local targetSrc = GetPlayerServerId(closestPlayer)
		local success = lib.skillCheck({'easy', 'easy', {areaSize = 60, speedMultiplier = 2}}, {'w', 'a', 's', 'd'}) 
	
		if success then
			takeHostage.InProgress = true
			takeHostage.targetSrc = targetSrc
	
			TriggerServerEvent('TakeHostage:sync', targetSrc)
	
			ESX.Streaming.RequestAnimDict(takeHostage.aggressor.animDict, function()
				TaskPlayAnim(playerPed, takeHostage.aggressor.animDict, takeHostage.aggressor.anim, 8.0, 8.0, -1, takeHostage.aggressor.flag, 0, false, false, false)
				takeHostage.type = 'aggressor'
				lib.notify({type = 'success', description = Translate('hostage_success'), position = 'top'})
			end)
		end
	end
end, false)

RegisterNetEvent('TakeHostage:syncTarget')
AddEventHandler('TakeHostage:syncTarget', function(target)
    takeHostage.InProgress = true
    ESX.Streaming.RequestAnimDict(takeHostage.hostage.animDict, function()
        AttachEntityToEntity(PlayerPedId(), GetPlayerPed(GetPlayerFromServerId(target)), 0, takeHostage.hostage.attachX, takeHostage.hostage.attachY, takeHostage.hostage.attachZ, 0.5, 0.5, 0.0, false, false, false, false, 2, false)
        takeHostage.type = 'hostage'
    end)
end)

RegisterNetEvent('TakeHostage:releaseHostage')
AddEventHandler('TakeHostage:releaseHostage', function()
    takeHostage.InProgress = false
    takeHostage.type = ''

    local playerPed = PlayerPedId()
    DetachEntity(playerPed, true, false)
    ESX.Streaming.RequestAnimDict('reaction@shove', function()
        TaskPlayAnim(playerPed, 'reaction@shove', 'shoved_back', 8.0, 8.0, -1, 0, 0, false, false, false)
        Wait(250)
        ClearPedSecondaryTask(playerPed)
    end)
end)

RegisterNetEvent('TakeHostage:killHostage')
AddEventHandler('TakeHostage:killHostage', function()
    takeHostage.InProgress = false
    takeHostage.type = ''

    local playerPed = PlayerPedId()
    DetachEntity(playerPed, true, false)
    Wait(100)
    SetEntityHealth(playerPed, 0)
end)

RegisterNetEvent('TakeHostage:stop')
AddEventHandler('TakeHostage:stop', function()
    takeHostage.InProgress = false
    takeHostage.type = ''

    local playerPed = PlayerPedId()
    ClearPedSecondaryTask(playerPed)
    DetachEntity(playerPed, true, false)
end)

CreateThread(function()
    while true do
        Wait(0)

        if takeHostage.type == 'aggressor' then
            local releaseHostageKey = Config.controls.releaseHostage
            local shootHostageKey = Config.controls.shootHostage

            helpText = string.format("%s - Release hostage | %s - Shoot hostage", releaseHostageKey:upper(), shootHostageKey:upper())

            local playerPed = PlayerPedId()

            DisableControlAction(0, 24, true) 
            DisableControlAction(0, 25, true) 
            DisableControlAction(0, 21, true)  
            DisablePlayerFiring(playerPed, true)

            if IsDisabledControlJustPressed(0, GetKeyCode(releaseHostageKey)) then
                takeHostage.type = ''
                takeHostage.InProgress = false

                ESX.Streaming.RequestAnimDict('reaction@shove', function()
                    TaskPlayAnim(playerPed, 'reaction@shove', 'shove_var_a', 8.0, 8.0, -1, 168, 0, false, false, false)
                    TriggerServerEvent('TakeHostage:releaseHostage', takeHostage.targetSrc)
                end)
            elseif IsDisabledControlJustPressed(0, GetKeyCode(shootHostageKey)) then
                takeHostage.type = ''
                takeHostage.InProgress = false

                ESX.Streaming.RequestAnimDict('anim@gangops@hostage@', function()
                    TaskPlayAnim(playerPed, 'anim@gangops@hostage@', 'perp_fail', 8.0, 8.0, -1, 168, 0, false, false, false)
                    TriggerServerEvent('TakeHostage:killHostage', takeHostage.targetSrc)
                    TriggerServerEvent('TakeHostage:stop', takeHostage.targetSrc)
                    Wait(100)
                    SetPedShootsAtCoord(playerPed, 0.0, 0.0, 0.0, 0)
                end)
            end

            if IsEntityDead(playerPed) then
                takeHostage.type = ''
                takeHostage.InProgress = false

                ESX.Streaming.RequestAnimDict('reaction@shove', function()
                    TaskPlayAnim(playerPed, 'reaction@shove', 'shove_var_a', 8.0, 8.0, -1, 168, 0, false, false, false)
                    TriggerServerEvent('TakeHostage:releaseHostage', takeHostage.targetSrc)
                end)
            end

            if takeHostage.type == 'aggressor' then
                if not IsEntityPlayingAnim(playerPed, takeHostage.aggressor.animDict, takeHostage.aggressor.anim, 3) then
                    TaskPlayAnim(playerPed, takeHostage.aggressor.animDict, takeHostage.aggressor.anim, 8.0, 8.0, 100000, takeHostage.aggressor.flag, 0, false, false, false)
                end
            end

        elseif takeHostage.type == 'hostage' then
            local playerPed = PlayerPedId()

            DisableControlAction(0, 24, true) 
            DisableControlAction(0, 25, true)  
            DisableControlAction(0, 47, true) 
            DisablePlayerFiring(playerPed, true)

            if not IsEntityPlayingAnim(playerPed, takeHostage.hostage.animDict, takeHostage.hostage.anim, 3) then
                TaskPlayAnim(playerPed, takeHostage.hostage.animDict, takeHostage.hostage.anim, 8.0, 8.0, 100000, takeHostage.hostage.flag, 0, false, false, false)
            end
        else
            Wait(300) 
        end
    end
end)


CreateThread(function()
    if Config.EnableTarget then
        exports.ox_target:addGlobalPlayer({
            {
                label = Translate("takehostage_title"),
                icon = Config.HostageTargetIcon,
                distance = 2.0,
                CanInteract = function()
                    local playerPed = PlayerPedId()
                    local currentWeapon = GetSelectedPedWeapon(playerPed)

                    return Config.allowedWeapons[currentWeapon] ~= nil
                end,				
                onSelect = function(data)
                    ExecuteCommand(Config.commandName)
                end
            }
        })
    end
end)

CreateThread(function()
    while true do
        if helpText then
            lib.showTextUI(helpText, {position = 'bottom-center', icon = 'fa-solid fa-person-rifle'}) 
            helpText = nil
            Wait(150)
		else
			lib.hideTextUI()
        end
        Wait(500)
    end
end)
