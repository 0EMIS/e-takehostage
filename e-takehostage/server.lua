local takingHostage = {}
local takenHostage = {}

RegisterServerEvent("TakeHostage:sync")
AddEventHandler("TakeHostage:sync", function(targetSrc)
    local source = source

    TriggerClientEvent("TakeHostage:syncTarget", targetSrc, source)
    takingHostage[source] = targetSrc
    takenHostage[targetSrc] = source
end)

RegisterServerEvent("TakeHostage:releaseHostage")
AddEventHandler("TakeHostage:releaseHostage", function(targetSrc)
    local source = source
    TriggerClientEvent("TakeHostage:releaseHostage", targetSrc, source)
    takingHostage[source] = nil
    takenHostage[targetSrc] = nil
end)

RegisterServerEvent("TakeHostage:killHostage")
AddEventHandler("TakeHostage:killHostage", function(targetSrc)
    local source = source
    TriggerClientEvent("TakeHostage:killHostage", targetSrc, source)
    takingHostage[source] = nil
    takenHostage[targetSrc] = nil
end)

RegisterServerEvent("TakeHostage:stop")
AddEventHandler("TakeHostage:stop", function(targetSrc)
    local source = source

    if takingHostage[source] then
        TriggerClientEvent("TakeHostage:stop", targetSrc)
        takenHostage[takingHostage[source]] = nil
        takingHostage[source] = nil
    elseif takenHostage[source] then
        TriggerClientEvent("TakeHostage:stop", targetSrc)
        takenHostage[source] = nil
        takingHostage[targetSrc] = nil
    end
end)

AddEventHandler('playerDropped', function(reason)
    local source = source
    
    if takingHostage[source] then
        TriggerClientEvent("TakeHostage:stop", takingHostage[source])
        takenHostage[takingHostage[source]] = nil
        takingHostage[source] = nil
    end

    if takenHostage[source] then
        TriggerClientEvent("TakeHostage:stop", takenHostage[source])
        takingHostage[takenHostage[source]] = nil
        takenHostage[source] = nil
    end
end)
