-- Based on https://github.com/ivanlod3/ForeverCCPosition (MIT).
-- See LICENSE-ForeverCCPosition.txt for the original license.
-- Integrated ForeverCCPosition. Blizzard still owns aura filtering and timers.
local CC = {}
TisteltiPlatesCC = CC
local hooked = setmetatable({}, {__mode = "k"})
local originalLevels = setmetatable({}, {__mode = "k"})
local keys = {"CrowdControlListFrame", "LossOfControlFrame"}

local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and not (issecretvalue and issecretvalue(value)) then return value end
end

local function Visible(frame)
    if not frame or Read(frame.IsForbidden, frame) then return false end
    if not Read(frame.IsVisible, frame) then return false end
    local alpha = Read(frame.GetEffectiveAlpha, frame)
    return type(alpha) == "number" and alpha > 0
end

local function VisibleChildren(...)
    for i = 1, select("#", ...) do
        local child = select(i, ...)
        if Visible(child) and child.Icon and child.Cooldown then return true end
    end
    return false
end

local function HasControlIcon(uf)
    local auras = uf and uf.AurasFrame
    if not Visible(auras) then return false end
    for _, key in ipairs(keys) do
        local list = auras[key]
        if Visible(list) then
            -- A visible container can be empty. Inspect the actual icon only.
            if Visible(list.AuraItemFrame) then return true end
            if list.GetChildren then
                local ok, visible = pcall(function()
                    return VisibleChildren(list:GetChildren())
                end)
                if ok and visible then return true end
            end
        end
    end
    return false
end

local function UpdateWing(art, uf)
    local hide = HasControlIcon(uf)
    art.rightWing:SetShown(not hide)
    art.rightWingLight:SetShown(not hide)
end

function CC.Position(uf)
    if not uf or Read(uf.IsForbidden, uf) then return end
    local auras = uf.AurasFrame
    if not auras or Read(auras.IsForbidden, auras) then return end
    local art = Visible(uf.TisteltiArt) and uf.TisteltiArt
        or Visible(uf.TisteltiCombatArt) and uf.TisteltiCombatArt
    local anchor = art and art.badge
        or Visible(uf.PlayerLevelDiffFrame) and uf.PlayerLevelDiffFrame
        or uf.HealthBarsContainer
    if not anchor then return end
    for _, key in ipairs(keys) do
        local frame = auras[key]
        -- Preserve the old positioner's combat behavior for unprotected lists.
        -- Protected lists wait for PLAYER_REGEN_ENABLED; wings still update.
        if frame and not Read(frame.IsForbidden, frame)
            and (not InCombatLockdown() or Read(frame.IsProtected, frame) == false) then
            frame:ClearAllPoints()
            frame:SetPoint("LEFT", anchor, "RIGHT", 8, 0)
            if art then
                if originalLevels[frame] == nil then originalLevels[frame] = frame:GetFrameLevel() end
                frame:SetFrameLevel(art.badge:GetFrameLevel() + 10)
            elseif originalLevels[frame] then
                frame:SetFrameLevel(originalLevels[frame])
                originalLevels[frame] = nil
            end
        end
    end
end

function CC.AttachArt(art, uf)
    -- Preview samples have no live unit or aura frame.
    if not uf.AurasFrame then return end
    local elapsed = 0
    art:SetScript("OnShow", function()
        UpdateWing(art, uf)
        CC.Position(uf)
    end)
    art:SetScript("OnHide", function()
        art.rightWing:Show()
        art.rightWingLight:Show()
        CC.Position(uf)
    end)
    art:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < .05 then return end
        elapsed = 0
        UpdateWing(art, uf)
    end)
end

local function Attach(plate)
    local uf = plate and plate.UnitFrame
    if not uf or Read(uf.IsForbidden, uf) then return end
    if not hooked[uf] and type(uf.UpdateAnchors) == "function" then
        hooked[uf] = true
        hooksecurefunc(uf, "UpdateAnchors", CC.Position)
    end
    CC.Position(uf)
end

local events = CreateFrame("Frame")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        Attach(C_NamePlate.GetNamePlateForUnit(unit))
    else
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do Attach(plate) end
    end
end)

function CC.Report()
    local enum = Enum and Enum.NamePlateFriendlyPlayerAuraDisplay
    local index = enum and enum.LossOfControl or 3
    local enabled = Read(C_CVar and C_CVar.GetCVarBitfield or GetCVarBitfield,
        "nameplateFriendlyPlayerAuraDisplay", index)
    local plates = Read(C_CVar and C_CVar.GetCVarBool or GetCVarBool, "nameplateShowFriendlyPlayers")
    local function status(value)
        if value == nil then return "no disponible" end
        return value and "activado" or "desactivado"
    end
    print("|cffffcd62Tistelti|r: placas amistosas: " .. status(plates)
        .. "; control/stuns en amigos: " .. status(enabled) .. ".")
end
