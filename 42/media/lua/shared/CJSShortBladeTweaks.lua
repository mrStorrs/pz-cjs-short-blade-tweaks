local MOD_ID = "cjsShortBladeTweaks"
local JAW_STAB_SLOT = "JawStab"
local GROUND_ATTACK_SPEED_VARIABLE = "CJSShortBladeGroundAttackSpeed"
local JAW_STAB_SPEED_VARIABLE = "CJSShortBladeJawStabSpeed"
local FLOOR_ANIM_VARIABLE = "CJSShortBladeAimFloorAnim"
local VANILLA_JAW_STAB_SPEED = 0.80

local DEFAULTS = {
    GroundAttackSpeedPercent = 150,
    JawStabSpeedPercent = 150,
    PreventJawStabStuck = true,
}

local warned = {}
local recentHits = setmetatable({}, { __mode = "k" })
local javaFields = {}
local isSmallBladeWeapon

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

local function sandboxOption(key)
    local vars = SandboxVars and SandboxVars.CJSShortBladeTweaks
    if vars and vars[key] ~= nil then
        return vars[key]
    end

    return DEFAULTS[key]
end

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function speedPercent(key)
    local value = tonumber(sandboxOption(key)) or DEFAULTS[key]
    return clamp(math.floor(value), 50, 300)
end

local function groundAttackSpeed()
    return speedPercent("GroundAttackSpeedPercent") / 100
end

local function jawStabSpeed()
    return VANILLA_JAW_STAB_SPEED * speedPercent("JawStabSpeedPercent") / 100
end

local function shouldPreventJawStabStuck()
    return sandboxOption("PreventJawStabStuck") == true
end

local function findJavaField(object, fieldName)
    if javaFields[fieldName] ~= nil then
        return javaFields[fieldName] or nil
    end

    if not object or not getNumClassFields or not getClassField then return nil end

    local fieldCount = safeCall("getNumClassFields." .. fieldName, function()
        return getNumClassFields(object)
    end)
    if not fieldCount then return nil end

    for index = 0, fieldCount - 1 do
        local field = safeCall("getClassField." .. fieldName .. "." .. tostring(index), function()
            return getClassField(object, index)
        end)
        if tostring(field):match("%." .. fieldName .. "$") then
            javaFields[fieldName] = field
            return field
        end
    end

    javaFields[fieldName] = false
    return nil
end

local function readJavaField(object, fieldName)
    if not getClassFieldVal then return nil end

    local field = findJavaField(object, fieldName)
    if not field then return nil end

    return safeCall("readJavaField" .. fieldName, function()
        return getClassFieldVal(object, field)
    end)
end

local function getEquippedWeapon(player)
    if not player then return nil end

    local weapon = safeCall("getPrimaryHandItem", function()
        return player:getPrimaryHandItem()
    end)

    if weapon then return weapon end

    return safeCall("getUseHandWeapon", function()
        return player:getUseHandWeapon()
    end)
end

local function isPlayerAimAtFloor(player)
    if not player then return false end

    return safeCall("isAimAtFloor", function()
        return player:isAimAtFloor()
    end) == true
end

local function isManualFloorAttackDown(player)
    if not player then return false end

    local buttonDown = safeCall("isManualFloorAtkButtonDown", function()
        return player:isManualFloorAtkButtonDown()
    end)
    if buttonDown ~= nil then return buttonDown == true end

    if not GameKeyboard or not GameKeyboard.isKeyDown then return false end
    return safeCall("isKeyDownManualFloorAtk", function()
        return GameKeyboard.isKeyDown("ManualFloorAtk")
    end) == true
end

local function isAttackVarsAimAtFloor(player)
    if not player then return false end

    local attackVars = safeCall("getAttackVars", function()
        return player:getAttackVars()
    end)

    return readJavaField(attackVars, "aimAtFloor") == true
end

local function shouldUseFloorAnimation(player, weapon, includeAttackVars)
    local equippedWeapon = weapon or getEquippedWeapon(player)
    if not isSmallBladeWeapon(equippedWeapon) then return false end

    return isPlayerAimAtFloor(player)
        or isManualFloorAttackDown(player)
        or (includeAttackVars and isAttackVarsAimAtFloor(player))
end

local function applyFloorAnimationVariable(player, weapon, includeAttackVars)
    if not player then return end

    safeCall("setFloorAnimationVariable", function()
        player:setVariable(FLOOR_ANIM_VARIABLE, shouldUseFloorAnimation(player, weapon, includeAttackVars))
    end)
end

local function applyAnimationVariables(player)
    if not player then return end

    safeCall("setGroundAttackSpeed", function()
        player:setVariable(GROUND_ATTACK_SPEED_VARIABLE, groundAttackSpeed())
    end)

    safeCall("setJawStabSpeed", function()
        player:setVariable(JAW_STAB_SPEED_VARIABLE, jawStabSpeed())
    end)

    applyFloorAnimationVariable(player)
end

local function applyAnimationVariablesToPlayers()
    if not getSpecificPlayer then return end
    if not getNumActivePlayers then
        applyAnimationVariables(getSpecificPlayer(0))
        return
    end

    for playerIndex = 0, getNumActivePlayers() - 1 do
        applyAnimationVariables(getSpecificPlayer(playerIndex))
    end
end

function isSmallBladeWeapon(weapon)
    if not weapon then return false end

    local scriptItem = weapon.getScriptItem and weapon:getScriptItem()
    local categories = scriptItem and scriptItem.getCategories and scriptItem:getCategories()
    if categories and categories.contains and categories:contains("SmallBlade") then
        return true
    end

    categories = weapon.getCategories and weapon:getCategories()
    return categories and categories.contains and categories:contains("SmallBlade") or false
end

local function updateFloorAnimation(player, weapon, includeAttackVars)
    applyFloorAnimationVariable(player, weapon, includeAttackVars)
end

local function updateFloorAnimationVariablesForPlayers()
    if not getSpecificPlayer then return end
    if not getNumActivePlayers then
        updateFloorAnimation(getSpecificPlayer(0), nil, false)
        return
    end

    for playerIndex = 0, getNumActivePlayers() - 1 do
        updateFloorAnimation(getSpecificPlayer(playerIndex), nil, false)
    end
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
    applyAnimationVariables(attacker)
    if not shouldPreventJawStabStuck() then return end
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

local function onWeaponSwing(player, weapon)
    updateFloorAnimation(player, weapon, true)
end

local function onHitZombie(zombie, attacker, _bodyPartType, weapon)
    cleanJawStab(attacker, zombie, weapon)
end

local function onZombieDead(zombie)
    if not shouldPreventJawStabStuck() then return end

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

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(applyAnimationVariablesToPlayers)
end

if Events and Events.OnCreatePlayer then
    Events.OnCreatePlayer.Add(function(_playerIndex, player)
        applyAnimationVariables(player)
    end)
end

if Events and Events.OnTick then
    Events.OnTick.Add(updateFloorAnimationVariablesForPlayers)
end

if Events and Events.OnWeaponSwing then
    Events.OnWeaponSwing.Add(onWeaponSwing)
else
    warnOnce("missingOnWeaponSwing", "Events.OnWeaponSwing is not available")
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
