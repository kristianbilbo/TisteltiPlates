-- Optional faction accents on player nameplates; no native sizing or input changes.
TisteltiPlatesPlayers = {}
local Players = TisteltiPlatesPlayers
local states, borders, hooked = {}, {}, {}
local function Public(v) return not (issecretvalue and issecretvalue(v)) end
local function Read(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, v = pcall(fn, ...)
    if ok and Public(v) then return v end
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
local function PaintName(uf, state)
    if state.painting or not state.name or not state.db.enabled
        or not state.config.name or Players.Kind(uf.unit) ~= state.kind then return end
    state.painting = true
    state.name:SetTextColor(unpack(state.config.nameColor))
    state.painting = false
end
local function RestoreName(state)
    if not state.name then return end
    state.painting = true
    state.name:SetTextColor(unpack(state.original))
    state.painting = false
    state.name = nil
end
function Players.Remove(uf)
    local state = states[uf]
    if state then RestoreName(state); states[uf] = nil end
    if borders[uf] then borders[uf]:Hide() end
end
function Players.Update(uf, unit, db, decorated)
    if not uf or Read(uf.IsForbidden, uf) then return end
    local kind = Players.Kind(unit)
    if not db.enabled or not kind or (kind == "ally" and decorated) then Players.Remove(uf); return end
    local config = db.playerColors[kind]
    local state = states[uf]
    if state and (state.unit ~= unit or state.kind ~= kind or state.name and state.name ~= uf.name) then
        Players.Remove(uf); state = nil
    end
    if not state then state = {unit=unit}; states[uf] = state end
    state.config, state.db, state.kind = config, db, kind
    if config.name and uf.name and not Read(uf.name.IsForbidden, uf.name) then
        local name = uf.name
        if not state.name then
            local r, g, b, a = name:GetTextColor()
            if Public(r) and Public(g) and Public(b) and Public(a) then
                state.name, state.original = name, {r, g, b, a or 1}
            end
        end
        if not hooked[name] then
            hooked[name] = true
            local function Changed(_, r, g, b, a)
                local current = states[uf]
                if not current or current.name ~= name or current.painting then return end
                if Public(r) and Public(g) and Public(b) and Public(a) then
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
    if config.border and anchor and not Read(anchor.IsForbidden, anchor)
        and Read(anchor.IsShown, anchor) then
        local border = borders[uf]
        if not border then
            border = CreateFrame("Frame", nil, uf, "BackdropTemplate")
            border:EnableMouse(false)
            border:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=14})
            borders[uf] = border
        end
        border:SetBackdropBorderColor(unpack(config.borderColor))
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
