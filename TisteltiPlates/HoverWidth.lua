-- Widen every player plate while the cursor is over its name/bar.
-- Do not change native text, font size or click handling.
local Hover = {}
TisteltiPlatesHover = Hover
local tracked = setmetatable({}, {__mode = "k"})

local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and not (issecretvalue and issecretvalue(value)) then return value end
end

local function Number(value)
    if issecretvalue and issecretvalue(value) then return false end
    return type(value) == "number" and value > 0 and value < math.huge
end

local function Writable(uf)
    return not Read(uf.IsForbidden, uf)
        and (not InCombatLockdown() or Read(uf.IsProtected, uf) == false)
end

local function MouseOver(region)
    if not region or Read(region.IsForbidden, region) or not Read(region.IsVisible, region) then return false end
    if region.IsMouseOver then return Read(region.IsMouseOver, region) == true end
    local mouseOver = InputUtil and InputUtil.IsMouseOver or MouseIsOver
    return Read(mouseOver, region) == true
end

local function DesiredWidth(uf, normalWidth)
    -- Protected frames cannot reliably shrink when combat starts. Never expand
    -- them on hover, so entering combat cannot strand an enlarged plate.
    if InCombatLockdown() or Read(uf.IsProtected, uf) ~= false then return normalWidth end
    local name = uf.name
    if not name or Read(name.IsForbidden, name) or not Read(name.IsVisible, name) then return normalWidth end
    local mouseUnit = Read(UnitIsUnit, uf.unit, "mouseover") == true
    if not mouseUnit and not MouseOver(uf.HealthBarsContainer or uf) and not MouseOver(name) then return normalWidth end
    local textWidth = Read(name.GetUnboundedStringWidth, name)
    local available = Read(name.GetWidth, name)
    local current = Read(uf.GetWidth, uf)
    local nameScale = Read(name.GetEffectiveScale, name)
    if not Number(nameScale) then
        local parent = Read(name.GetParent, name)
        nameScale = parent and Read(parent.GetEffectiveScale, parent)
    end
    local plateScale = Read(uf.GetEffectiveScale, uf)
    if not Number(textWidth) or not Number(available) or not Number(current)
        or not Number(nameScale) or not Number(plateScale) then return normalWidth end
    -- Current width minus the current name space preserves the room occupied
    -- by health text and margins, even when the plate is already expanded.
    local desired = current + (textWidth + 4 - available) * nameScale / plateScale
    if not Number(desired) then return normalWidth end
    return math.max(normalWidth, desired)
end

-- SetWidth alone does nothing on native frames anchored at both left and
-- right. Keep those anchors and move their horizontal offsets symmetrically.
local function Anchors(uf)
    local count = Read(uf.GetNumPoints, uf)
    if not Number(count) then return nil end
    local points, left, right = {}, false, false
    for i = 1, count do
        local ok, point, relative, relativePoint, x, y = pcall(uf.GetPoint, uf, i)
        for _, value in pairs({point, relative, relativePoint, x, y}) do
            if issecretvalue and issecretvalue(value) then return nil end
        end
        if not ok or type(point) ~= "string" or type(relativePoint) ~= "string"
            or type(x) ~= "number" or type(y) ~= "number" then return nil end
        local side = point:find("LEFT", 1, true) and -1 or (point:find("RIGHT", 1, true) and 1 or 0)
        left, right = left or side == -1, right or side == 1
        points[#points + 1] = {point, relative, relativePoint, x, y, side = side}
    end
    return left and right and points or nil
end

local function SetWidth(uf, width, state)
    if not Writable(uf) then return false end
    local current = Read(uf.GetWidth, uf)
    if not Number(current) then return false end
    if math.abs(current - width) <= .5 then return true end
    if state and state.points then
        local delta = (width - state.originalWidth) / 2
        for _, point in ipairs(state.points) do
            local ok = pcall(uf.SetPoint, uf, point[1], point[2], point[3], point[4] + point.side * delta, point[5])
            if not ok then return false end
        end
        state.anchorsChanged = true
    end
    return pcall(uf.SetWidth, uf, width)
end

function Hover.Release(uf)
    local state = tracked[uf]
    if not state then return end
    state.released = true
    if not Writable(uf) then return end
    if state.anchorsChanged then
        for _, point in ipairs(state.points) do
            if not pcall(uf.SetPoint, uf, point[1], point[2], point[3], point[4], point[5]) then return end
        end
        state.anchorsChanged = false
    end
    if SetWidth(uf, state.originalWidth) then tracked[uf] = nil end
end

local function Update(uf, state)
    if state.released then Hover.Release(uf); return end
    -- A reused plate must not retain the previous player's expanded width.
    local unit = uf.unit
    if issecretvalue and issecretvalue(unit) then Hover.Release(uf); return end
    if unit ~= state.unit then Hover.Release(uf); return end
    if not Writable(uf) then return end
    SetWidth(uf, DesiredWidth(uf, state.normalWidth), state)
end

function Hover.Track(uf, normalWidth, originalWidth)
    if not uf or not Number(normalWidth) or not Number(originalWidth) then return end
    local unit = uf.unit
    if issecretvalue and issecretvalue(unit) then return end
    if type(unit) ~= "string" then return end
    local state = tracked[uf]
    if not state or state.released then
        state = {unit=unit, normalWidth=normalWidth, originalWidth=originalWidth, points=Anchors(uf)}
        tracked[uf] = state
    else
        state.unit, state.normalWidth, state.originalWidth = unit, normalWidth, originalWidth
    end
    Update(uf, state)
end

function Hover.GetBaseWidth(uf)
    local state = tracked[uf]
    return state and state.originalWidth or Read(uf.GetWidth, uf)
end

-- Enrollment is independent of group/guild membership, faction and artwork.
-- Preserve an existing decorated baseline instead of capturing an expanded width.
function Hover.TrackPlayer(uf)
    if not uf or Read(uf.IsForbidden, uf) then return end
    local unit = uf.unit
    if (issecretvalue and issecretvalue(unit)) or type(unit) ~= "string"
        or Read(UnitIsPlayer, unit) ~= true then Hover.Release(uf); return end
    local state = tracked[uf]
    if state and (state.unit ~= unit or state.released) then
        Hover.Release(uf)
        if tracked[uf] then return end
        state = nil
    end
    if state then Update(uf, state); return end
    local width = Read(uf.GetWidth, uf)
    Hover.Track(uf, width, width)
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_REGEN_DISABLED")
driver:SetScript("OnEvent", function()
    for uf, state in pairs(tracked) do Update(uf, state) end
end)
local elapsed = 0
driver:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < .05 then return end
    elapsed = 0
    for uf, state in pairs(tracked) do Update(uf, state) end
end)
