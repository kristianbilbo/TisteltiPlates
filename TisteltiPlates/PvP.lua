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
    if type(config.enabled) ~= "boolean" then config.enabled = false end
    for _, key in ipairs({"friends", "enemies", "emblem", "wings", "classIcon", "emphasizeTargets"}) do
        if type(config[key]) ~= "boolean" then config[key] = true end
    end
    if config.enemyColor ~= "red" and config.enemyColor ~= "class" then config.enemyColor = "class" end
    if config.friendColor ~= "blue" and config.friendColor ~= "class" then config.friendColor = "class" end
    if type(config.intensity) ~= "number" or config.intensity < .6 or config.intensity > 1.4 then config.intensity = 1 end
    if type(config.wingSize) ~= "number" or config.wingSize < .6 or config.wingSize > 1.2 then config.wingSize = .8 end
    if type(config.classIconSize) ~= "number" or config.classIconSize < 16 or config.classIconSize > 32 then config.classIconSize = 22 end
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

local function Emphasize(uf,bar,unit,color,enemy)
    local selected=enemy and Read(UnitIsUnit,unit,"target")
    local reason=enemy and TisteltiPlatesPriority and TisteltiPlatesPriority.Reason(unit)
    local display=uf.TisteltiPvPEmphasis
    if not config.emphasizeTargets or not (selected or reason) then
        if display then display:Hide() end
        return bar
    end
    if not display then
        display=CreateFrame("StatusBar",nil,uf)
        display:EnableMouse(false)
        display:SetStatusBarTexture(WHITE)
        display.background=display:CreateTexture(nil,"BACKGROUND")
        display.background:SetAllPoints() display.background:SetColorTexture(.025,.025,.035,.95)
        display.outline=Glow(display)
        display.outline:SetPoint("TOPLEFT",-2,2) display.outline:SetPoint("BOTTOMRIGHT",2,-2)
        display.marker=display:CreateTexture(nil,"OVERLAY")
        display.marker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
        display.marker:SetSize(24,24) display.marker:SetPoint("RIGHT",display,"LEFT",-42,0)
        display.reason=display:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        display.reason:SetPoint("RIGHT",display.marker,"LEFT",-4,0)
        uf.TisteltiPvPEmphasis=display
    end
    -- Crece hacia la izquierda; el nivel y los controles conservan su lateral.
    display:ClearAllPoints() display:SetPoint("RIGHT",bar,"RIGHT",0,0)
    display:SetSize(bar:GetWidth()*1.35,math.max(14,bar:GetHeight()*1.5))
    display:SetFrameLevel(bar:GetFrameLevel()+2)
    display:SetStatusBarColor(color.r,color.g,color.b)
    if display.sourceBar~=bar then
        display.sourceBar=bar
        if type(bar.SetValue)=="function" then
            hooksecurefunc(bar,"SetValue",function(_,value)
                if display.sourceBar==bar and display:IsShown() then pcall(display.SetValue,display,value) end
            end)
        end
        if type(bar.SetMinMaxValues)=="function" then
            hooksecurefunc(bar,"SetMinMaxValues",function(_,minimum,maximum)
                if display.sourceBar==bar and display:IsShown() then pcall(display.SetMinMaxValues,display,minimum,maximum) end
            end)
        end
    end
    -- Los valores nativos se reenvían al widget sin compararlos ni operar
    -- con ellos: los datos restringidos no se usan para decidir prioridades.
    local ok=false
    if type(bar.GetMinMaxValues)=="function" and type(bar.GetValue)=="function" then
        ok=pcall(function()
            display:SetMinMaxValues(bar:GetMinMaxValues())
            display:SetValue(bar:GetValue())
        end)
    end
    if not ok then display:Hide() return bar end
    PaintGlow(display.outline,selected and {r=1,g=1,b=1} or {r=1,g=.8,b=.05})
    display.marker:SetShown(reason~=nil and reason~=false)
    display.reason:SetText(reason or "TU OBJETIVO")
    display:Show()
    return display
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

function PvP.Paint(art, bar, color, class, faction, guild, rank, iconAnchor, borderColor)
    art:ClearAllPoints()
    art:SetAllPoints(bar)
    art:SetFrameLevel(bar:GetFrameLevel()+10)
    PaintGlow(art, borderColor or color)
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
    art.classFrame:SetSize(config.classIconSize, config.classIconSize)
    art.classFrame:SetPoint("RIGHT", emblem and art.faction or bar, "LEFT", -6, 0)
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
    -- El icono de clase queda fuera del lateral izquierdo, separado del
    -- emblema/ala. Los bufos superiores y los controles a la derecha son nativos.
    if guild and config.wings then
        art.classFrame:ClearAllPoints()
        art.classFrame:SetPoint("RIGHT", art.wings[1], "LEFT", -6, 0)
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
    if uf.TisteltiPvPEmphasis then uf.TisteltiPvPEmphasis:Hide() end
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
    local relation = TisteltiPlatesPlayers.Kind(unit)
    if not relation then PvP.Remove(uf); return end
    local friend, enemy = relation == "ally", relation == "enemy"
    local faction = Read(UnitFactionGroup, unit)
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
    local display=Emphasize(uf,bar,unit,color,enemy)
    local rgb = TisteltiPlatesPlayers.BorderColor(unit)
    local borderColor = rgb and {r=rgb[1],g=rgb[2],b=rgb[3]} or (enemy and RED or color)
    PvP.Paint(art, display, color, class, faction, guild, Read(TisteltiMerito, identity) or 0, iconAnchor, borderColor)
    if display~=bar then
        display.marker:ClearAllPoints()
        display.marker:SetPoint("RIGHT",art.classFrame,"LEFT",-6,0)
    end
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
    text("Enemigos con borde rojo y barra por clase. Objetivo y recomendado destacados.", 20, -52)
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
                not sample.enemy, sample.rank,nil,sample.enemy and RED or color)
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
    check("emphasizeTargets","Ampliar objetivo y recomendado",20,-329)
    cycle("friendColor","Aliados · barra y marco",{"class","blue"},20,-187)
    cycle("enemyColor","Enemigos · barra",{"class","red"},300,-187)
    cycle("intensity","Brillo (0.6 / 1 / 1.4)",{.6,1,1.4},20,-223)
    cycle("wingSize","Tamaño de alas",{.6,.8,1,1.2},300,-223)
    local colors = {"bronce","plata","oro","violeta","azul","verde"}
    cycle("low","Alas · mérito 1–4",colors,20,-259)
    cycle("middle","Alas · mérito 5–9",colors,300,-259)
    cycle("high","Alas · mérito 10–14",colors,20,-295)
    cycle("classIconSize","Tamaño de icono de clase",{18,22,26,30},300,-295)
    text("Sin datos de mérito: alas gris azulado. Se usa el mérito del addon, no un rango oficial supuesto.",20,-365)
    text("Vista previa · icono con neón por clase incluso usando barra roja",20,-395,"GameFontNormal")
    for i, data in ipairs({{"MAGE",false,4},{"WARLOCK",true,0}}) do
        local bar = CreateFrame("StatusBar",nil,panel)
        bar:SetSize(110,10); bar:SetPoint("TOPLEFT",65+(i-1)*280,-440)
        bar:SetStatusBarTexture(WHITE); bar:SetMinMaxValues(0,100); bar:SetValue(78)
        local name=bar:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        name:SetPoint("BOTTOMLEFT",bar,"TOPLEFT",0,5)
        name:SetText(i==1 and "Tu hermandad · Mago" or "Horda · Brujo")
        samples[#samples+1]={bar=bar,art=Art(bar),class=data[1],enemy=data[2],rank=data[3]}
    end
    text("Los cambios de modo durante combate se aplican al terminar. No activa placas ocultas del juego.",20,-480)
    text("Mundo abierto y campos de batalla/arenas. Las mazmorras y bandas mantienen la exclusión.",20,-504)
    panel:SetScript("OnShow",redraw)
    local subcategory = Settings.RegisterCanvasLayoutSubcategory(category,panel,"Modo PvP")
    Settings.RegisterAddOnCategory(subcategory)
    PvP.category = subcategory
    redraw()
end
