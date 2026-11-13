-- Expand the visual health/name container, never the engine-owned NamePlate
-- base or the UnitFrame anchors attached to it (restricted on Forever).
local Hover = {}
TisteltiPlatesHover = Hover
local tracked = setmetatable({}, {__mode = "k"})
local hooked = setmetatable({}, {__mode = "k"})
local unreadablePoints = setmetatable({}, {__mode = "k"})
local measure
local ANIMATION_DURATION = .18

local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end
local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    -- A successful nil (empty FontString) differs from a secret/failed read.
    if ok and Public(value) then return value, true end
end
local function Number(value)
    return Public(value) and type(value) == "number" and value > 0 and value < math.huge
end
local function Accessible(frame)
    if not frame then return false end
    for _,method in ipairs({"IsForbidden","HasAccessConstraints","HasAnyForbiddenAspects"}) do
        if type(frame[method])=="function" and Read(frame[method],frame)~=false then return false end
    end
    return true
end
local function Writable(frame)
    return Accessible(frame)
        and (not InCombatLockdown() or Read(frame.IsProtected, frame) == false)
end
local function MouseOver(region)
    if not region or Read(region.IsForbidden, region) or not Read(region.IsVisible, region) then return false end
    if Read(region.IsMouseOver, region) == true then return true end
    return Read(InputUtil and InputUtil.IsMouseOver or MouseIsOver, region) == true
end
local function Scale(region)
    local scale = Read(region.GetEffectiveScale, region)
    if Number(scale) then return scale end
    local parent = Read(region.GetParent, region)
    return parent and Read(parent.GetEffectiveScale, parent)
end

local function FullWidth(name)
    if not name or Read(name.IsForbidden, name) then return nil end
    local width = Read(name.GetUnboundedStringWidth, name)
    if width == 0 or Number(width) then return width end
    -- Native measurements can inherit secret geometry from the health text
    -- even outside combat. Measure only public text on an unanchored string.
    local text, readable = Read(name.GetText, name)
    if not readable then return nil end
    if text == nil or text == "" then return 0 end
    local font = Read(name.GetFontObject, name)
    local height = Read(name.GetFontHeight, name)
    if type(text) ~= "string" or not font or not Number(height) then return nil end
    if not measure then
        local owner = CreateFrame("Frame", nil, UIParent)
        owner:Hide()
        measure = owner:CreateFontString(nil, "OVERLAY")
        measure:SetWordWrap(false)
    end
    measure:SetFontObject(font)
    measure:SetFontHeight(height)
    local textScale = Read(name.GetTextScale, name)
    if measure.SetTextScale then measure:SetTextScale(Number(textScale) and textScale or 1) end
    measure:SetText(text)
    return Read(measure.GetUnboundedStringWidth, measure)
end

local function Points(region)
    if unreadablePoints[region] or not Accessible(region) then return nil end
    local count = Read(region.GetNumPoints, region)
    if not Number(count) then return nil end
    local points, left, right = {}, false, false
    for i = 1, count do
        local ok, point, relative, relativePoint, x, y = pcall(region.GetPoint, region, i)
        if not ok or not Public(point) or not Public(relative) or not Public(relativePoint)
            or not Public(x) or not Public(y) then unreadablePoints[region]=true return nil end
        if type(point) ~= "string" or type(relativePoint) ~= "string"
            or type(x) ~= "number" or type(y) ~= "number" then return nil end
        local side = point:find("LEFT", 1, true) and -1 or (point:find("RIGHT", 1, true) and 1 or 0)
        left, right = left or side == -1, right or side == 1
        points[#points + 1] = {point, relative, relativePoint, x, y, side = side}
    end
    return left and right and points or nil
end

local function Layout(uf)
    local bar = uf.HealthBarsContainer
    if not Accessible(bar) then return nil end
    local points = Points(bar)
    if not points then
        -- Forever's UpdateAnchors fixes the container to the cast container's
        -- top corners, reserving level-badge space at the right. Some builds
        -- restrict GetPoint; the two public widths preserve that reservation.
        local width = Read(bar.GetWidth, bar)
        if not Number(width) then return nil end
        local cast = uf.CastBarsContainer
        local castWidth = cast and Read(cast.GetWidth, cast)
        local spacing = NamePlateSetupOptions and NamePlateSetupOptions.castBarToHealthBarSpacing
        if not Number(castWidth) or not Public(spacing) or type(spacing) ~= "number" then return nil end
        points = {
            {"BOTTOMLEFT", cast, "TOPLEFT", 0, spacing, side=-1},
            {"BOTTOMRIGHT", cast, "TOPRIGHT", width-castWidth, spacing, side=1},
        }
    end
    return {bar=bar, points=points, extra=0}
end

local function Apply(layout, extra)
    if not Writable(layout.bar) then return false end
    if extra ~= 0 and not Number(extra) then return false end
    if layout.extra == extra then return true end
    -- Record partial changes as well, so a failed second anchor is restored.
    layout.extra = extra
    for _, point in ipairs(layout.points) do
        local ok = pcall(layout.bar.SetPoint, layout.bar, point[1], point[2], point[3],
            point[4] + point.side * extra / 2, point[5])
        if not ok then layout.failed = true; return false end
    end
    layout.failed = nil
    return true
end

local function Restore(state)
    local layout = state.layout
    if not layout then return true end
    layout.target = nil
    if layout.failed then layout.extra = math.huge end
    if not Apply(layout, 0) then return false end
    state.layout = nil
    return true
end

-- Reconstruct the public InsideHealthBar layout when the name inherits secret
-- geometry from its health-text anchors. Subtract the actual rendered health
-- labels, native insets and margins instead of adding an entire name's width.
local function AvailableWidth(uf, layout, nameScale, barScale)
    local available = Read(uf.name.GetWidth, uf.name)
    if Number(available) then return available * nameScale / barScale end
    local width = Read(layout.bar.GetWidth, layout.bar)
    if not Number(width) then return nil end
    if Read(uf.IsShowOnlyName, uf) == true then return width - 8 end
    local options = NamePlateSetupOptions
    local styles = NamePlateConstants and NamePlateConstants.NAME_ANCHOR_STYLES
    if not options or not styles or options.unitNameAnchorStyle ~= styles.InsideHealthBar then return nil end
    local health = layout.bar.healthBar or uf.healthBar
    if not health then return nil end
    local used = 10 -- name left + name/health gap + health right padding
    if options.useClassicHealthBar then
        if not Number(options.horizontalScale) then return nil end
        used = used + 20.75 * options.horizontalScale
    end
    for _, key in ipairs({"Text", "RightText", "LeftText"}) do
        local label = health[key]
        local labelWidth = FullWidth(label)
        if labelWidth ~= 0 then
            local labelScale = label and Scale(label)
            if not Number(labelWidth) or not Number(labelScale) then return nil end
            used = used + labelWidth * labelScale / barScale
        end
    end
    return math.max(0, width - used)
end

local function SetTarget(layout, target)
    if target ~= 0 and not Number(target) then target = 0 end
    if layout.target and math.abs(layout.target-target) < 1 then return end
    if math.abs(layout.extra-target) < .01 then
        Apply(layout, target)
        layout.target = nil
        return
    end
    layout.from, layout.target, layout.time = layout.extra, target, 0
end

local function Animate(layout, dt)
    if not layout.target then return end
    layout.time = math.min(ANIMATION_DURATION, layout.time + dt)
    local t = layout.time / ANIMATION_DURATION
    local eased = t * t * (3 - 2 * t)
    local width = layout.from + (layout.target-layout.from) * eased
    Apply(layout, layout.time == ANIMATION_DURATION and layout.target or width)
    if layout.time == ANIMATION_DURATION then layout.target = nil end
end

local function DesiredExtra(uf, layout)
    if InCombatLockdown() or Read(layout.bar.IsProtected, layout.bar) ~= false then return 0 end
    local name = uf.name
    if not name or Read(name.IsForbidden, name) or not Read(name.IsVisible, name) then return 0 end
    if Read(UnitIsUnit, uf.unit, "mouseover") ~= true and not MouseOver(layout.bar) and not MouseOver(name) then return 0 end
    local textWidth = FullWidth(name)
    local nameScale, barScale = Scale(name), Scale(layout.bar)
    if not Number(textWidth) or not Number(nameScale) or not Number(barScale) then return 0 end
    local available = AvailableWidth(uf, layout, nameScale, barScale)
    -- Do not guess a bigger size if neither the allocated width nor the public
    -- health labels can be measured. Short names must not grow on hover.
    if available == nil then return 0 end
    local normalAvailable = available - layout.extra
    local fullWidth = textWidth * nameScale / barScale
    if fullWidth <= normalAvailable then return 0 end
    return math.max(0, fullWidth + 4 * nameScale / barScale - normalAvailable)
end

function Hover.Release(uf)
    local state = tracked[uf]
    if not state then return end
    state.released = true
    if not Restore(state) then return end
    -- Core defers classic plate geometry restoration until combat ends.
    -- Names-only/removal must not attempt a root width write in the meantime.
    if state.styled and InCombatLockdown() then return end
    if state.styled and Writable(uf) then
        if not pcall(uf.SetWidth, uf, state.originalWidth) then return end
    elseif state.styled then return end
    tracked[uf] = nil
end

local function Update(uf, state)
    if state.released then Hover.Release(uf); return end
    if not Public(uf.unit) or uf.unit ~= state.unit then Hover.Release(uf); return end
    if not state.layout then state.layout = Layout(uf) end
    if not state.layout then return end
    if state.layout.failed then Restore(state); return end
    local layout = state.layout
    if InCombatLockdown() or not Read(layout.bar.IsVisible, layout.bar) then
        layout.target = nil
        Apply(layout, 0)
    else
        SetTarget(layout, DesiredExtra(uf, layout))
    end
end

function Hover.GetBaseWidth(uf)
    local state = tracked[uf]
    return state and state.originalWidth or Read(uf.GetWidth, uf)
end

local function WatchLayout(uf)
    if not hooked[uf] and type(uf.UpdateAnchors) == "function" then
        hooksecurefunc(uf, "UpdateAnchors", function()
            local current = tracked[uf]
            if current then
                -- Blizzard has just replaced our child offsets. Capture its new
                -- baseline, including changes to the level badge or UI scale.
                local extra = current.layout and current.layout.extra or 0
                current.layout = Layout(uf)
                if current.layout and not InCombatLockdown()
                    and Read(current.layout.bar.IsProtected, current.layout.bar) == false then
                    Apply(current.layout, extra)
                end
                Update(uf, current)
            end
        end)
        hooked[uf] = true
    end
end

function Hover.Track(uf, normalWidth, originalWidth)
    if not uf or not Number(normalWidth) or not Number(originalWidth) then return end
    local unit = uf.unit
    if not Public(unit) or type(unit) ~= "string" then return end
    local state = tracked[uf]
    if state and (state.released or state.unit ~= unit) then
        Hover.Release(uf)
        if tracked[uf] then return end
        state = nil
    end
    if not state then
        state = {unit=unit, originalWidth=originalWidth}
        tracked[uf] = state
    end
    if not Number(state.originalWidth) then state.originalWidth = originalWidth end
    if state.normalWidth ~= normalWidth then
        if not Restore(state) then return end
        -- Preserve Core's existing decoration width, without re-anchoring the
        -- UnitFrame to its native NamePlate parent. Hover uses only the child.
        if normalWidth ~= originalWidth and Writable(uf) then
            pcall(uf.SetWidth, uf, normalWidth)
            state.styled = true
        end
        state.normalWidth = normalWidth
    end
    WatchLayout(uf)
    Update(uf, state)
end

function Hover.TrackPlayer(uf)
    if not uf or Read(uf.IsForbidden, uf) then return end
    local unit = uf.unit
    if not Public(unit) or type(unit) ~= "string" or Read(UnitIsPlayer, unit) ~= true then Hover.Release(uf); return end
    local state = tracked[uf]
    if state and (state.unit ~= unit or state.released) then
        Hover.Release(uf)
        if tracked[uf] then return end
        state = nil
    end
    if state then Update(uf, state); return end
    -- Generic players do not need to expose the engine-owned root's size.
    state = {unit=unit, originalWidth=Read(uf.GetWidth, uf)}
    tracked[uf] = state
    WatchLayout(uf)
    Update(uf, state)
end

local driver = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UPDATE_MOUSEOVER_UNIT"}) do driver:RegisterEvent(event) end
driver:SetScript("OnEvent", function()
    for uf, state in pairs(tracked) do Update(uf, state) end
end)
local elapsed = 0
driver:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    local refresh = elapsed >= .05
    if refresh then elapsed = 0 end
    for uf, state in pairs(tracked) do
        if refresh then Update(uf, state) end
        if state.layout then Animate(state.layout, dt) end
    end
end)
