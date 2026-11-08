-- Compact PvP. Native health values, plate geometry and aura anchors stay owned by Blizzard.
local PvP = {}
TisteltiPlatesPvP = PvP
local config, enabled
local states = {}
local WHITE = "Interface\\Buttons\\WHITE8X8"
local RED, BLUE = {r=1,g=.08,b=.08}, {r=.16,g=.58,b=1}
local palette = {bronce={r=1,g=.48,b=.16}, plata={r=.82,g=.9,b=1},
    oro={r=1,g=.86,b=.08}, violeta={r=.72,g=.38,b=1}, azul=BLUE,
    verde={r=.15,g=1,b=.42}}
local coords = {WARRIOR={0,.25,0,.25}, MAGE={.25,.49609375,0,.25},
    ROGUE={.49609375,.7421875,0,.25}, DRUID={.7421875,.98828125,0,.25},
    HUNTER={0,.25,.25,.5}, SHAMAN={.25,.49609375,.25,.5},
    PRIEST={.49609375,.7421875,.25,.5}, WARLOCK={.7421875,.98828125,.25,.5},
    PALADIN={0,.25,.5,.75}}

local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end

local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and Public(value) then return value end
end

function PvP.Initialize(db)
    if type(db.pvp) ~= "table" then db.pvp = {} end
    config = db.pvp
    for _, key in ipairs({"enabled", "friends", "enemies", "emblem", "wings", "classIcon"}) do
        if type(config[key]) ~= "boolean" then config[key] = true end
    end
    if config.enemyColor ~= "red" and config.enemyColor ~= "class" then config.enemyColor = "class" end
    if config.friendColor ~= "blue" and config.friendColor ~= "class" then config.friendColor = "class" end
    if type(config.intensity) ~= "number" or config.intensity < .6 or config.intensity > 1.4 then config.intensity = 1 end
    if type(config.wingSize) ~= "number" or config.wingSize < .6 or config.wingSize > 1.2 then config.wingSize = .8 end
    for key, fallback in pairs({low="bronce", middle="plata", high="oro"}) do
        if not palette[config[key] or ""] then config[key] = fallback end
    end
    enabled = config.enabled
end

function PvP.Sync()
    -- Returning from the old enlarged style requires protected geometry restoration.
    if config and not InCombatLockdown() then enabled = config.enabled end
end

function PvP.IsActive()
    return enabled == true
end

local function Glow(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:EnableMouse(false)
    frame.edges = {}
    for ring = 0, 3 do
        for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
            local t = frame:CreateTexture(nil, "OVERLAY")
            t:SetTexture(WHITE)
            t:SetBlendMode("ADD")
            if side == "TOP" or side == "BOTTOM" then
                local y = side == "TOP" and ring or -ring
                t:SetPoint(side.."LEFT", frame, side.."LEFT", -ring, y)
                t:SetPoint(side.."RIGHT", frame, side.."RIGHT", ring, y)
                t:SetHeight(1)
            else
                local x = side == "LEFT" and -ring or ring
                t:SetPoint("TOP"..side, frame, "TOP"..side, x, ring)
                t:SetPoint("BOTTOM"..side, frame, "BOTTOM"..side, x, -ring)
                t:SetWidth(1)
            end
            frame.edges[#frame.edges+1] = {texture=t, alpha=({1,.5,.22,.08})[ring+1]}
        end
    end
    return frame
end

local function PaintGlow(frame, color)
    for _, edge in ipairs(frame.edges) do
        edge.texture:SetVertexColor(color.r, color.g, color.b, math.min(1, edge.alpha * config.intensity))
    end
end

local function Art(parent)
    local art = Glow(parent)
    art.faction = art:CreateTexture(nil, "OVERLAY")
    art.classFrame = Glow(art)
    art.classIcon = art.classFrame:CreateTexture(nil, "ARTWORK")
    art.classIcon:SetAllPoints(art.classFrame)
    art.classIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
    art.wings = {}
    -- Minimal three-feather outline: short luminous strokes, no bulky wing art.
    for _, side in ipairs({-1, 1}) do
        local wing = CreateFrame("Frame", nil, art)
        wing:EnableMouse(false)
        wing.side, wing.lines = side, {}
        for i = 1, 3 do
            for layer = 1, 2 do
                local line = wing:CreateTexture(nil, "OVERLAY")
                line:SetTexture(WHITE)
                line:SetBlendMode("ADD")
                wing.lines[#wing.lines+1] = {texture=line, feather=i, layer=layer}
            end
        end
        art.wings[#art.wings+1] = wing
    end
    art:Hide()
    return art
end

function PvP.WingColor(rank)
    if type(rank) ~= "number" or rank < 1 then return {r=.5,g=.58,b=.68} end
    return palette[rank <= 4 and config.low or rank <= 9 and config.middle or config.high]
end

function PvP.Paint(art, bar, color, class, faction, guild, rank, iconAnchor)
    art:ClearAllPoints()
    art:SetAllPoints(bar)
    art:SetFrameLevel(bar:GetFrameLevel()+10)
    PaintGlow(art, color)
    local height = math.max(6, math.min(14, bar:GetHeight()))
    local emblem = config.emblem and (faction == "Alliance" or faction == "Horde")
    art.faction:ClearAllPoints()
    art.faction:SetSize(height, height)
    art.faction:SetPoint("RIGHT", bar, "LEFT", -.5, 0)
    if emblem then
        art.faction:SetTexture("Interface\\TargetingFrame\\UI-PVP-"..faction)
        -- Native PvP textures include unused padding on the right and bottom.
        art.faction:SetTexCoord(0, .625, 0, .625)
    end
    art.faction:SetShown(emblem and true or false)
    local uv = (CLASS_ICON_TCOORDS or coords)[class or ""]
    local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class or ""]
    art.classFrame:ClearAllPoints()
    art.classFrame:SetSize(height, height)
    art.classFrame:SetPoint("LEFT", iconAnchor or bar, "RIGHT", 3, 0)
    if uv and classColor then
        art.classIcon:SetTexCoord(unpack(uv))
        PaintGlow(art.classFrame, classColor)
    end
    art.classFrame:SetShown(config.classIcon and uv ~= nil and classColor ~= nil)
    local wingColor = PvP.WingColor(rank)
    for _, wing in ipairs(art.wings) do
        local right = wing.side == 1
        wing:ClearAllPoints()
        -- Left wing touches the emblem; right wing touches the health frame.
        wing:SetPoint(right and "LEFT" or "RIGHT", right and (iconAnchor or bar) or (emblem and art.faction or bar),
            right and "RIGHT" or "LEFT", 0, 0)
        wing:SetSize(height * .75 * config.wingSize, height)
        for _, entry in ipairs(wing.lines) do
            local line, i, layer = entry.texture, entry.feather, entry.layer
            line:ClearAllPoints()
            line:SetSize(height * (.82 - i * .12) * config.wingSize, layer == 1 and 1 or 3)
            line:SetPoint("CENTER", wing, "CENTER", 0, (2-i)*height*.22)
            line:SetRotation(wing.side * (.20 + .12*i))
            line:SetVertexColor(wingColor.r, wingColor.g, wingColor.b,
                math.min(1, (layer == 1 and 1 or .18) * config.intensity))
        end
        wing:SetShown(config.wings and guild and true or false)
    end
    -- The icon sits beyond a short wing when both are present.
    if guild and config.wings then
        art.classFrame:ClearAllPoints()
        art.classFrame:SetPoint("LEFT", art.wings[2], "RIGHT", 3, 0)
    end
    art.pvpShowRightWing=config.wings and guild and true or false
    art.pvpShowClassIcon=config.classIcon and uv~=nil and classColor~=nil
    if art.pvpUnitFrame and TisteltiPlatesCC then
        TisteltiPlatesCC.UpdatePvPArt(art,art.pvpUnitFrame)
    end
    art:Show()
end

local function Tint(uf)
    local state = states[uf]
    if not state or not state.color or state.tinting then return end
    state.tinting = true
    -- A cosmetic constant color only: never read or replace health values.
    pcall(state.bar.SetStatusBarColor, state.bar, state.color.r, state.color.g, state.color.b)
    state.tinting = false
end

function PvP.Remove(uf)
    if uf.TisteltiPvPArt then uf.TisteltiPvPArt:Hide() end
    local state = states[uf]
    if not state then return end
    states[uf] = nil
    if CompactUnitFrame_UpdateHealthColor and type(uf.unit) == "string" and Public(uf.unit) and Read(UnitExists, uf.unit) then
        local ok = pcall(CompactUnitFrame_UpdateHealthColor, uf)
        if ok then return end
    end
    pcall(state.bar.SetStatusBarColor, state.bar, unpack(state.originalColor))
end

function PvP.Update(unit, uf)
    if not Read(UnitIsPlayer, unit) or Read(UnitIsUnit, unit, "player") then PvP.Remove(uf); return end
    local friend = Read(UnitIsFriend, "player", unit)
    local faction = Read(UnitFactionGroup, unit)
    local playerFaction = Read(UnitFactionGroup, "player")
    local enemy = Read(UnitCanAttack, "player", unit) or
        (faction and playerFaction and faction ~= playerFaction and not friend)
    if not ((friend and config.friends) or (enemy and config.enemies)) then PvP.Remove(uf); return end
    local bar = uf.healthBar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar)
    if not bar or Read(bar.IsForbidden, bar) or not Read(bar.IsShown, bar) then PvP.Remove(uf); return end
    local class
    if type(UnitClass) == "function" then
        local ok, _, token = pcall(UnitClass, unit)
        if ok and Public(token) then class = token end
    end
    local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class or ""]
    local color = enemy and config.enemyColor == "red" and RED or
        friend and config.friendColor == "blue" and BLUE or classColor
    -- Restricted class data: keep a useful reaction color and hide the class icon.
    color = color or (enemy and RED or BLUE)
    local state = states[uf]
    if state and state.bar ~= bar then PvP.Remove(uf); state = nil end
    if not state then
        state = {bar=bar, originalColor={bar:GetStatusBarColor()}}
        states[uf] = state
        if not bar.TisteltiPvPColorHooked then
            hooksecurefunc(bar, "SetStatusBarColor", function() Tint(uf) end)
            bar.TisteltiPvPColorHooked = true
        end
    end
    state.color = color
    local art = uf.TisteltiPvPArt or Art(uf)
    uf.TisteltiPvPArt = art
    local identity = unit
    local guild = friend and faction == "Alliance" and Read(UnitIsInMyGuild, unit)
    if friend and faction == "Alliance" and not guild then
        -- Forever can expose guild membership/merit through the roster token only.
        local raid = Read(IsInRaid)
        local count = Read(raid and GetNumGroupMembers or GetNumSubgroupMembers) or 0
        for i = 1, count do
            local candidate = (raid and "raid" or "party") .. i
            if Read(UnitIsUnit, unit, candidate) then
                identity = candidate
                guild = Read(UnitIsInMyGuild, candidate)
                break
            end
        end
    end
    local iconAnchor = uf.PlayerLevelDiffFrame
    if not iconAnchor or not Read(iconAnchor.IsShown, iconAnchor) then iconAnchor = nil end
    if TisteltiPlatesCC then TisteltiPlatesCC.AttachPvPArt(art,uf) end
    PvP.Paint(art, bar, color, class, faction, guild, Read(TisteltiMerito, identity) or 0, iconAnchor)
    Tint(uf)
end

function PvP.RegisterOptions(category, refresh)
    if not Settings.RegisterCanvasLayoutSubcategory then return end
    local panel = CreateFrame("Frame")
    local function text(value, x, y, template)
        local label = panel:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", x, y); label:SetText(value)
        return label
    end
    text("Modo PvP · Placas compactas", 20, -20, "GameFontNormalLarge")
    text("Tamaño original. Emblema pegado. Marco y neón acompañan al color de la barra.", 20, -52)
    local controls, samples = {}, {}
    local labels = {class="Clase", red="Rojo", blue="Azul", bronce="Bronce", plata="Plata",
        oro="Oro", violeta="Violeta", azul="Azul", verde="Verde"}
    local function redraw()
        for _, control in ipairs(controls) do control.draw() end
        for _, sample in ipairs(samples) do
            local color = sample.enemy and config.enemyColor == "red" and RED or
                not sample.enemy and config.friendColor == "blue" and BLUE or RAID_CLASS_COLORS[sample.class]
            sample.bar:SetStatusBarColor(color.r,color.g,color.b)
            PvP.Paint(sample.art, sample.bar, color, sample.class, sample.enemy and "Horde" or "Alliance",
                not sample.enemy, sample.rank)
        end
    end
    local function changed()
        refresh(); redraw()
    end
    local function check(key, caption, x, y)
        local button = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        button:SetSize(26,26); button:SetPoint("TOPLEFT",x,y)
        local label = button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        label:SetPoint("LEFT",button,"RIGHT",3,0); label:SetText(caption)
        controls[#controls+1] = {draw=function() button:SetChecked(config[key]) end}
        button:SetScript("OnClick",function(self) config[key]=self:GetChecked() and true or false; changed() end)
    end
    local function cycle(key, caption, values, x, y)
        local button = CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
        button:SetSize(255,26); button:SetPoint("TOPLEFT",x,y)
        controls[#controls+1] = {draw=function()
            button:SetText(caption..": "..(labels[config[key]] or tostring(config[key])))
        end}
        button:SetScript("OnClick",function()
            local nextValue = values[1]
            for i,v in ipairs(values) do if v==config[key] then nextValue=values[i % #values + 1]; break end end
            config[key]=nextValue; changed()
        end)
    end
    check("enabled","Activar modo PvP",20,-80)
    check("emblem","Emblema de facción",300,-80)
    check("friends","Jugadores aliados",20,-113)
    check("enemies","Jugadores enemigos",300,-113)
    check("wings","Alas solo tu hermandad (Alianza)",20,-146)
    check("classIcon","Icono de clase con neón de clase",300,-146)
    cycle("friendColor","Aliados · barra y marco",{"class","blue"},20,-187)
    cycle("enemyColor","Enemigos · barra y marco",{"class","red"},300,-187)
    cycle("intensity","Brillo (0.6 / 1 / 1.4)",{.6,1,1.4},20,-223)
    cycle("wingSize","Tamaño de alas",{.6,.8,1,1.2},300,-223)
    local colors = {"bronce","plata","oro","violeta","azul","verde"}
    cycle("low","Alas · mérito 1–4",colors,20,-259)
    cycle("middle","Alas · mérito 5–9",colors,300,-259)
    cycle("high","Alas · mérito 10–14",colors,20,-295)
    text("Sin datos de mérito: alas gris azulado. Se usa el mérito del addon, no un rango oficial supuesto.",20,-335)
    text("Vista previa · icono con neón por clase incluso usando barra roja",20,-364,"GameFontNormal")
    for i, data in ipairs({{"MAGE",false,4},{"WARLOCK",true,0}}) do
        local bar = CreateFrame("StatusBar",nil,panel)
        bar:SetSize(110,10); bar:SetPoint("TOPLEFT",65+(i-1)*280,-414)
        bar:SetStatusBarTexture(WHITE); bar:SetMinMaxValues(0,100); bar:SetValue(78)
        local name=bar:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        name:SetPoint("BOTTOMLEFT",bar,"TOPLEFT",0,5)
        name:SetText(i==1 and "Tu hermandad · Mago" or "Horda · Brujo")
        samples[#samples+1]={bar=bar,art=Art(bar),class=data[1],enemy=data[2],rank=data[3]}
    end
    text("Los cambios de modo durante combate se aplican al terminar. No activa placas ocultas del juego.",20,-453)
    text("Mundo abierto y campos de batalla/arenas. Las mazmorras y bandas mantienen la exclusión.",20,-477)
    panel:SetScript("OnShow",redraw)
    local subcategory = Settings.RegisterCanvasLayoutSubcategory(category,panel,"Modo PvP")
    Settings.RegisterAddOnCategory(subcategory)
    PvP.category = subcategory
    redraw()
end
