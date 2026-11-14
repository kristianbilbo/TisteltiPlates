-- Optional faction accents on player nameplates; no native sizing or input changes.
TisteltiPlatesPlayers = {}
local Players = TisteltiPlatesPlayers
local states, borders, hooked = {}, {}, {}
local pendingNames = setmetatable({}, {__mode="k"})
local function Public(v) return not (issecretvalue and issecretvalue(v)) end
local function Read(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, v = pcall(fn, ...)
    if ok and Public(v) then return v end
end
local function CanPaint(name)
    for _, method in ipairs({"IsForbidden", "HasAccessConstraints", "HasAnyForbiddenAspects"}) do
        if type(name[method]) == "function" and Read(name[method], name) ~= false then return false end
    end
    return not (InCombatLockdown and InCombatLockdown()) or Read(name.IsProtected, name) == false
end
function Players.Kind(unit)
    if not Public(unit) or type(unit) ~= "string" or Read(UnitIsPlayer, unit) ~= true
        or Read(UnitIsUnit, unit, "player") then return end
    if Read(UnitCanAttack, "player", unit) then return "enemy" end
    if Read(UnitIsFriend, "player", unit) then return "ally" end
    local faction, ownFaction = Read(UnitFactionGroup, unit), Read(UnitFactionGroup, "player")
    if (faction == "Horde" or faction == "Alliance")
        and (ownFaction == "Horde" or ownFaction == "Alliance") then
        return faction == ownFaction and "ally" or "enemy"
    end
end
-- Shared by classic accents and compact PvP: one configured color source.
function Players.Color(unit,field,pvp,native,db)
    db=db or TisteltiPlatesDB
    if not TisteltiPlatesConfig.Allowed(db) then return end
    local class
    if UnitClass then
        local ok,_,token=pcall(UnitClass,unit)
        if ok and Public(token) then class=token end
    end
    return TisteltiPlatesConfig.ResolveColor(db,Players.Kind(unit),field,class,Read(UnitFactionGroup,unit),pvp,native)
end
function Players.BorderColor(unit,pvp,native) return Players.Color(unit,"border",pvp,native) end
function Players.NameColor(unit,pvp) return Players.Color(unit,"name",pvp) end
local function PaintName(uf, state)
    if state.painting or not state.name or not TisteltiPlatesConfig.Allowed(state.db) or not CanPaint(state.name)
        or not state.nameColor or Players.Kind(uf.unit) ~= state.kind then return end
    state.painting = true
    local rgb = state.nameColor
    pcall(state.name.SetTextColor, state.name, rgb[1], rgb[2], rgb[3], state.original[4])
    state.painting = false
end
local function RestoreName(state)
    if not state.name then return end
    state.painting = true
    if not CanPaint(state.name) or not pcall(state.name.SetTextColor, state.name, unpack(state.original)) then
        pendingNames[state.name] = state.original
    end
    state.painting = false
    state.name = nil
end
function Players.Sync()
    for name, color in pairs(pendingNames) do
        if CanPaint(name) and pcall(name.SetTextColor, name, unpack(color)) then pendingNames[name] = nil end
    end
end
function Players.Remove(uf)
    local state = states[uf]
    if state then RestoreName(state); states[uf] = nil end
    if borders[uf] then borders[uf]:Hide() end
end
function Players.Update(uf, unit, db, decorated, pvpOwnsBorder)
    if not uf or Read(uf.IsForbidden, uf) then return end
    local kind = Players.Kind(unit)
    -- PvP owns both the name and border while visible, using these same settings.
    -- Two recolor hooks on the same name would fight and corrupt restoration.
    if not TisteltiPlatesConfig.Allowed(db) or not kind or (kind == "ally" and decorated) or pvpOwnsBorder then Players.Remove(uf); return end
    local state = states[uf]
    local name = uf.name or uf.Name or (uf.NameContainer and uf.NameContainer.Name)
    if state and (state.unit ~= unit or state.kind ~= kind or state.name and state.name ~= name) then
        Players.Remove(uf); state = nil
    end
    if not state then state = {unit=unit}; states[uf] = state end
    state.db, state.kind = db, kind
    state.nameColor=Players.Color(unit,"name",false,nil,db)
    if state.nameColor and name and CanPaint(name) then
        if not state.name then
            local ok, r, g, b, a = pcall(name.GetTextColor, name)
            if ok and Public(r) and Public(g) and Public(b) and Public(a)
                and type(r)=="number" and type(g)=="number" and type(b)=="number" then
                state.name, state.original = name, pendingNames[name] or {r, g, b, a or 1}
                pendingNames[name] = nil
            end
        end
        if not hooked[name] then
            hooked[name] = true
            local function Changed(_, r, g, b, a)
                local current = states[uf]
                if not current or current.name ~= name or current.painting then return end
                if Public(r) and Public(g) and Public(b) and Public(a)
                    and type(r)=="number" and type(g)=="number" and type(b)=="number" then
                    current.original = {r, g, b, a or 1}
                end
                PaintName(uf, current)
            end
            -- Blizzard uses SetVertexColor for selection/mouseover name changes.
            hooksecurefunc(name, "SetVertexColor", Changed)
            hooksecurefunc(name, "SetTextColor", Changed)
        end
        PaintName(uf, state)
    else
        RestoreName(state)
    end
    local anchor = uf.HealthBarsContainer or uf.healthBar
    local namesOnly = TisteltiPlatesNamesOnly and TisteltiPlatesNamesOnly.IsActive(uf)
    local borderColor=Players.Color(unit,"border",false,nil,db)
    if borderColor and not namesOnly and not pvpOwnsBorder and anchor and not Read(anchor.IsForbidden, anchor)
        and Read(anchor.IsShown, anchor) then
        local border = borders[uf]
        if not border then
            border = CreateFrame("Frame", nil, uf, "BackdropTemplate")
            border:EnableMouse(false)
            border:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=14})
            borders[uf] = border
            uf.TisteltiPlayerBorder = border
        end
        border:SetBackdropBorderColor(unpack(borderColor))
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", anchor, "TOPLEFT", -5, 5)
        border:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 5, -5)
        local level = Read(anchor.GetFrameLevel, anchor)
        if type(level) == "number" then border:SetFrameLevel(level + 20) end
        border:Show()
    elseif borders[uf] then
        borders[uf]:Hide()
    end
end
