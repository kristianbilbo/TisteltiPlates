-- Based on https://github.com/ivanlod3/ForeverCCPosition (MIT).
-- See LICENSE-ForeverCCPosition.txt for the original license.
-- Integrated ForeverCCPosition. Blizzard still owns aura filtering and timers.
local CC = {}
TisteltiPlatesCC = CC
local hooked = setmetatable({}, {__mode = "k"})
local originalLevels = setmetatable({}, {__mode = "k"})
local originalPoints = setmetatable({}, {__mode = "k"})
local unreadable = setmetatable({}, {__mode = "k"})
local keys = {"CrowdControlListFrame", "LossOfControlFrame"}

function CC.OriginalPlacement(frame)
    return originalPoints[frame], originalLevels[frame]
end

local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and not (issecretvalue and issecretvalue(value)) then return value end
end

function CC.CanPosition(frame)
    if not frame or unreadable[frame] then return false end
    -- IsForbidden no cubre restricciones parciales como FrameMeasurement.
    -- Una respuesta secreta o no disponible tampoco autoriza medir el marco.
    for _,method in ipairs({"IsForbidden","HasAccessConstraints","HasAnyForbiddenAspects"}) do
        if type(frame[method])=="function" and Read(frame[method],frame)~=false then return false end
    end
    return not InCombatLockdown() or Read(frame.IsProtected,frame)==false
end

function CC.CapturePlacement(frame)
    if not CC.CanPosition(frame) then return end
    local count=Read(frame.GetNumPoints,frame)
    local level=Read(frame.GetFrameLevel,frame)
    if type(count)~="number" or type(level)~="number" or type(frame.GetPoint)~="function" then return end
    local points={}
    for i=1,count do
        local ok,point,relative,relativePoint,x,y=pcall(frame.GetPoint,frame,i)
        if not ok or (issecretvalue and (issecretvalue(point) or issecretvalue(relative)
            or issecretvalue(relativePoint) or issecretvalue(x) or issecretvalue(y))) or not point then
            unreadable[frame]=true
            return -- Sin copia completa no se cambia ni se intenta recolocar.
        end
        points[i]={point,relative,relativePoint,x,y}
    end
    return points,level
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

function CC.UpdatePvPArt(art, uf)
    -- En compacto el nivel y los controles conservan sus anclajes nativos.
    -- El ala derecha cede espacio mientras dure un control visible. El icono
    -- de clase tiene su propio espacio al otro lado y permanece legible.
    local hide=HasControlIcon(uf)
    art.wings[2]:SetShown(art.pvpShowRightWing and not hide or false)
    art.classFrame:SetShown(art.pvpShowClassIcon and true or false)
end

function CC.AttachPvPArt(art, uf)
    if not uf.AurasFrame or art.pvpControlHooks then return end
    art.pvpControlHooks=true
    art.pvpUnitFrame=uf
    local elapsed=0
    art:SetScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt
        if elapsed<.05 then return end
        elapsed=0
        CC.UpdatePvPArt(art,uf)
    end)
end

local function UpdateWing(art, uf)
    local enabled = not TisteltiPlatesDB or TisteltiPlatesDB.hideRightWingOnCC ~= false
    local hide = enabled and HasControlIcon(uf)
    art.rightWing:SetShown(not hide)
    art.rightWingLight:SetShown(not hide)
end

function CC.Position(uf)
    if not uf or Read(uf.IsForbidden, uf) then return end
    local auras = uf.AurasFrame
    if not auras or Read(auras.IsForbidden, auras) then return end
    if TisteltiPlatesPvP and TisteltiPlatesPvP.IsActive() then
        for _, key in ipairs(keys) do
            local frame = auras[key]
            if frame and originalPoints[frame] and CC.CanPosition(frame) then
                frame:ClearAllPoints()
                for _, point in ipairs(originalPoints[frame]) do frame:SetPoint(unpack(point)) end
                if originalLevels[frame] then frame:SetFrameLevel(originalLevels[frame]) end
                originalPoints[frame], originalLevels[frame] = nil, nil
            end
        end
        return -- Compact mode leaves the native CC layout intact.
    end
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
        if frame and CC.CanPosition(frame) then
            if not originalPoints[frame] then
                local points=CC.CapturePlacement(frame)
                originalPoints[frame] = points
            end
            if originalPoints[frame] then
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
