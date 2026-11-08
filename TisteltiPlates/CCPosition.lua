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
local auraKeys = {"BuffListFrame", "DebuffListFrame", "CrowdControlListFrame", "LossOfControlFrame"}
local moved = setmetatable({}, {__mode = "k"})
local rectUnreadable = setmetatable({}, {__mode = "k"})

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

local function Rect(frame)
    if not frame or rectUnreadable[frame] then return end
    for _, method in ipairs({"IsForbidden", "HasAccessConstraints", "HasAnyForbiddenAspects"}) do
        if type(frame[method])=="function" and Read(frame[method],frame)~=false then return end
    end
    if type(frame.GetRect)~="function" then return end
    local ok,x,y,w,h=pcall(frame.GetRect,frame)
    if not ok then rectUnreadable[frame]=true return end
    for _,value in ipairs({x,y,w,h}) do
        if (issecretvalue and issecretvalue(value)) or type(value)~="number" then return end
    end
    if type(x)~="number" or type(y)~="number" or type(w)~="number" or type(h)~="number" or w<=0 or h<=0 then return end
    local scale=Read(frame.GetEffectiveScale,frame)
    if type(scale)~="number" or scale<=0 then return end
    return {x*scale,y*scale,(x+w)*scale,(y+h)*scale}
end

local function AuraObstacles(uf)
    local obstacles,unknown={},false
    local auras=uf and uf.AurasFrame
    if not Visible(auras) then return obstacles,unknown end
    local seen={}
    local function add(icon)
        if not icon or seen[icon] or not Visible(icon) then return end
        seen[icon]=true
        local rect=Rect(icon)
        if rect then obstacles[#obstacles+1]=rect else unknown=true end
    end
    for _,key in ipairs(auraKeys) do
        local list=auras[key]
        if Visible(list) then
            add(list.AuraItemFrame)
            if type(list.GetChildren)=="function" then
                local ok=pcall(function()
                    for _,child in ipairs({list:GetChildren()}) do
                        if child.Icon and child.Cooldown then add(child) end
                    end
                end)
                if not ok then unknown=true end
            end
        end
    end
    return obstacles,unknown
end

function CC.UpdatePvPArt(art, uf)
    local obstacles,unknown=AuraObstacles(uf)
    local function blocked(frame)
        if unknown then return true end
        if #obstacles==0 then return false end
        -- Test hidden ornaments too, so they can reappear without moving auras.
        local rect=Rect(frame)
        if not rect then return true end
        for _,other in ipairs(obstacles) do
            if rect[1]<other[3]+4 and rect[3]>other[1]-4
                and rect[2]<other[4]+4 and rect[4]>other[2]-4 then return true end
        end
        return false
    end
    art.wings[1]:SetShown(art.pvpShowLeftWing and not blocked(art.wings[1]) or false)
    art.wings[2]:SetShown(art.pvpShowRightWing and not HasControlIcon(uf) and not blocked(art.wings[2]) or false)
    local showClass=art.pvpShowClassIcon and not blocked(art.classFrame)
    art.classFrame:SetShown(showClass and true or false)
    if art.factionFrame then
        art.factionFrame:SetShown(art.pvpShowFaction and (not art.pvpShowClassIcon or showClass)
            and not blocked(art.factionFrame) or false)
    end
end

function CC.AttachPvPArt(art, uf)
    if art.pvpControlHooks then return end
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
    local art = Visible(uf.TisteltiArt) and uf.TisteltiArt
        or Visible(uf.TisteltiCombatArt) and uf.TisteltiCombatArt
    if not art or (TisteltiPlatesPvP and TisteltiPlatesPvP.IsActive()) then
        for frame in pairs(moved[uf] or {}) do
            if originalPoints[frame] and CC.CanPosition(frame) then
                frame:ClearAllPoints()
                for _, point in ipairs(originalPoints[frame]) do frame:SetPoint(unpack(point)) end
                if originalLevels[frame] then frame:SetFrameLevel(originalLevels[frame]) end
                originalPoints[frame], originalLevels[frame] = nil, nil
                moved[uf][frame] = nil
            end
        end
        return -- Undecorated plates and compact mode keep their own layout.
    end
    local anchor = art.badge
    if not anchor then return end
    local previous
    for index, key in ipairs(auraKeys) do
        local frame = auras[key]
        -- Preserve the old positioner's combat behavior for unprotected lists.
        -- Protected lists wait for PLAYER_REGEN_ENABLED; wings still update.
        if frame and CC.CanPosition(frame) then
            if not originalPoints[frame] then
                local points, level=CC.CapturePlacement(frame)
                originalPoints[frame] = points
                originalLevels[frame] = level
            end
            if originalPoints[frame] then
                moved[uf] = moved[uf] or setmetatable({}, {__mode = "k"})
                moved[uf][frame] = true
                frame:ClearAllPoints()
                if index <= 2 then
                    frame:SetPoint("BOTTOMLEFT", previous or art.ccAnchor, "TOPLEFT", 0, previous and 6 or 0)
                    if Visible(frame) then previous = frame end
                else
                    frame:SetPoint("LEFT", anchor, "RIGHT", 8, 0)
                end
                frame:SetFrameLevel(art.badge:GetFrameLevel() + 10)
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
        CC.Position(uf)
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
