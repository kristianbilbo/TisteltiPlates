-- Small, addon-owned ornaments for Blizzard's native names-only mode.
-- Never enable nameplates, change CVars, or resize the native name/plate.
TisteltiPlatesNamesOnly = {}
local Names = TisteltiPlatesNamesOnly
local function Read(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, ...)
    if ok and not (issecretvalue and issecretvalue(value)) then return value end
end
function Names.IsActive(uf)
    return uf and not Read(uf.IsForbidden, uf) and Read(uf.IsShowOnlyName, uf) == true
end
function Names.Remove(uf)
    if uf and uf.TisteltiNameWings then uf.TisteltiNameWings:Hide() end
end
local textures = {
    guild = "Interface\\AddOns\\TisteltiPlates\\Media\\Wings.tga",
    group = "Interface\\AddOns\\TisteltiPlates\\Media\\Wings-Grupo-v1.tga",
    raid = "Interface\\AddOns\\TisteltiPlates\\Media\\Wings-Banda-v1.tga",
}
function Names.Paint(parent, name, style, db)
    local settings=TisteltiPlatesConfig.Get(db or TisteltiPlatesDB,"mini")
    if settings[style]==false then Names.Remove(parent); return end
    if not name or Read(name.IsForbidden, name) or Read(name.IsShown, name) ~= true then
        Names.Remove(parent); return
    end
    -- The FontString rectangle can be much wider than its centered text.
    -- Measure only public dimensions and keep the ornaments beside the visible text.
    local width, textWidth = Read(name.GetWidth, name), Read(name.GetStringWidth, name)
    if type(width) ~= "number" or type(textWidth) ~= "number"
        or width <= 0 or textWidth <= 0 or width ~= width or textWidth ~= textWidth
        or width == math.huge or textWidth == math.huge or not textures[style] then
        Names.Remove(parent); return
    end
    local visibleWidth = math.min(width, textWidth)
    local justify = Read(name.GetJustifyH, name)
    local center = justify == "LEFT" and (visibleWidth-width)/2
        or justify == "RIGHT" and (width-visibleWidth)/2 or 0
    local art = parent.TisteltiNameWings
    if not art then
        art = CreateFrame("Frame", nil, parent)
        art:EnableMouse(false)
        art.left = art:CreateTexture(nil, "OVERLAY")
        art.right = art:CreateTexture(nil, "OVERLAY")
        art.left:SetTexCoord(0, .40, 0, 1)
        art.right:SetTexCoord(.60, 1, 0, 1)
        parent.TisteltiNameWings = art
    end
    art:ClearAllPoints()
    art:SetPoint("CENTER", name, "CENTER", center, 0)
    art:SetSize(visibleWidth, settings.size)
    for _, wing in ipairs({art.left, art.right}) do
        wing:SetTexture(textures[style]); wing:SetSize(settings.size, settings.size)
        wing:ClearAllPoints()
    end
    art.left:SetPoint("RIGHT", art, "LEFT", -settings.gap, 0)
    art.right:SetPoint("LEFT", art, "RIGHT", settings.gap, 0)
    art:Show()
    return art
end
function Names.Update(uf, style, db)
    if not TisteltiPlatesConfig.Allowed(db) or not db.namesOnlyWings or not style or not Names.IsActive(uf) then
        Names.Remove(uf); return
    end
    Names.Paint(uf, uf.name, style, db)
end
