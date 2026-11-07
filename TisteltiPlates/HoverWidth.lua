-- Widen decorated player plates only while the cursor is over their name/bar.
-- Native anchors, text, font size and click handling remain owned by Blizzard.
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
    local name = uf.name
    if not name or Read(name.IsForbidden, name) or not Read(name.IsVisible, name) then return normalWidth end
    if not MouseOver(uf.HealthBarsContainer or uf) and not MouseOver(name) then return normalWidth end
    local textWidth = Read(name.GetUnboundedStringWidth, name)
    local available = Read(name.GetWidth, name)
    local current = Read(uf.GetWidth, uf)
    local nameScale = Read(name.GetEffectiveScale, name)
    local plateScale = Read(uf.GetEffectiveScale, uf)
    if not Number(textWidth) or not Number(available) or not Number(current)
        or not Number(nameScale) or not Number(plateScale) then return normalWidth end
    -- Current width minus the current name space preserves the room occupied
    -- by health text and margins, even when the plate is already expanded.
    local desired = current + (textWidth + 4 - available) * nameScale / plateScale
    if not Number(desired) then return normalWidth end
    return math.max(normalWidth, desired)
end

local function SetWidth(uf, width)
    if not Writable(uf) then return false end
    local current = Read(uf.GetWidth, uf)
    if not Number(current) then return false end
    if math.abs(current - width) <= .5 then return true end
    return pcall(uf.SetWidth, uf, width)
end

function Hover.Release(uf)
    local state = tracked[uf]
    if not state then return end
    state.released = true
    if SetWidth(uf, state.originalWidth) then tracked[uf] = nil end
end

local function Update(uf, state)
    if state.released then Hover.Release(uf); return end
    -- A reused plate must not retain the previous player's expanded width.
    local unit = uf.unit
    if issecretvalue and issecretvalue(unit) then Hover.Release(uf); return end
    if unit ~= state.unit then Hover.Release(uf); return end
    if not Writable(uf) then return end
    SetWidth(uf, DesiredWidth(uf, state.normalWidth))
end

function Hover.Track(uf, normalWidth, originalWidth)
    if not uf or not Number(normalWidth) or not Number(originalWidth) then return end
    local unit = uf.unit
    if issecretvalue and issecretvalue(unit) then return end
    if type(unit) ~= "string" then return end
    local state = tracked[uf]
    if not state or state.released then
        state = {unit=unit, normalWidth=normalWidth, originalWidth=originalWidth}
        tracked[uf] = state
    else
        state.unit, state.normalWidth, state.originalWidth = unit, normalWidth, originalWidth
    end
    Update(uf, state)
end

local driver = CreateFrame("Frame")
local elapsed = 0
driver:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < .05 then return end
    elapsed = 0
    for uf, state in pairs(tracked) do Update(uf, state) end
end)
