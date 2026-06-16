local MOD_ID = "cjsShortBladeTweaks"
local JAW_STAB_SLOT = "JawStab"

local warned = {}
local recentHits = setmetatable({}, { __mode = "k" })

local function warnOnce(key, message)
    if warned[key] then return end
    warned[key] = true
    print("[" .. MOD_ID .. "] " .. message)
end

local function safeCall(key, fn)
    local ok, result = pcall(fn)
    if not ok then
        warnOnce(key, key .. " failed: " .. tostring(result))
        return nil
    end
    return result
end

local function isSmallBladeWeapon(weapon)
    if not weapon then return false end

    local scriptItem = weapon.getScriptItem and weapon:getScriptItem()
    local categories = scriptItem and scriptItem.getCategories and scriptItem:getCategories()
    if categories and categories.contains and categories:contains("SmallBlade") then
        return true
    end

    categories = weapon.getCategories and weapon:getCategories()
    return categories and categories.contains and categories:contains("SmallBlade") or false
end

local function detachJawStabItem(zombie)
    if not zombie then return nil end

    local hadJawStabAttach = zombie.isJawStabAttach
        and safeCall("isJawStabAttach", function()
            return zombie:isJawStabAttach()
        end) == true

    local attachedItem = zombie.getAttachedItem
        and safeCall("getAttachedItem", function()
            return zombie:getAttachedItem(JAW_STAB_SLOT)
        end)

    if not attachedItem and not hadJawStabAttach then
        return nil, false
    end

    if attachedItem and zombie.removeAttachedItem then
        safeCall("removeAttachedItem", function()
            zombie:removeAttachedItem(attachedItem)
        end)
    end

    if zombie.setAttachedItem then
        safeCall("clearJawStabAttachedItem", function()
            zombie:setAttachedItem(JAW_STAB_SLOT, nil)
        end)
    end

    if zombie.setJawStabAttach then
        safeCall("setJawStabAttach", function()
            zombie:setJawStabAttach(false)
        end)
    end

    return attachedItem, true
end

local function restorePlayerWeapon(attacker, weapon)
    if not attacker or not weapon then return end

    local inventory = attacker.getInventory and attacker:getInventory()
    if inventory and weapon.getContainer then
        local container = safeCall("getWeaponContainer", function()
            return weapon:getContainer()
        end)

        if container ~= inventory and inventory.AddItem then
            safeCall("returnJawStabWeaponToInventory", function()
                inventory:AddItem(weapon)
            end)
        end
    end

    if attacker.getPrimaryHandItem and attacker.setPrimaryHandItem then
        local primary = safeCall("getPrimaryHandItem", function()
            return attacker:getPrimaryHandItem()
        end)

        if primary ~= weapon then
            safeCall("restorePrimaryHandItem", function()
                attacker:setPrimaryHandItem(weapon)
            end)
        end
    end
end

local function cleanJawStab(attacker, target, weapon)
    if not target or not weapon or not isSmallBladeWeapon(weapon) then return end
    if target.isZombie and not target:isZombie() then return end

    recentHits[target] = { attacker = attacker, weapon = weapon }
    local _attachedItem, cleaned = detachJawStabItem(target)
    if cleaned then
        restorePlayerWeapon(attacker, weapon)
    end
end

local function onWeaponHitCharacter(attacker, target, weapon)
    cleanJawStab(attacker, target, weapon)
end

local function onWeaponHitXp(attacker, weapon, target)
    cleanJawStab(attacker, target, weapon)
end

local function onHitZombie(zombie, attacker, _bodyPartType, weapon)
    cleanJawStab(attacker, zombie, weapon)
end

local function onZombieDead(zombie)
    local hit = zombie and recentHits[zombie]
    if hit then
        cleanJawStab(hit.attacker, zombie, hit.weapon)
        recentHits[zombie] = nil
    else
        detachJawStabItem(zombie)
    end
end

local function onCharacterDeath(character)
    if character and character.isZombie and character:isZombie() then
        onZombieDead(character)
    end
end

if Events and Events.OnWeaponHitCharacter then
    Events.OnWeaponHitCharacter.Add(onWeaponHitCharacter)
else
    warnOnce("missingOnWeaponHitCharacter", "Events.OnWeaponHitCharacter is not available")
end

if Events and Events.OnWeaponHitXp then
    Events.OnWeaponHitXp.Add(onWeaponHitXp)
end

if Events and Events.OnHitZombie then
    Events.OnHitZombie.Add(onHitZombie)
end

if Events and Events.OnZombieDead then
    Events.OnZombieDead.Add(onZombieDead)
end

if Events and Events.OnCharacterDeath then
    Events.OnCharacterDeath.Add(onCharacterDeath)
end
