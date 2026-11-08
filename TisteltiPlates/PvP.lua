-- Compact PvP. Native health values, plate geometry and aura anchors stay owned by Blizzard.
local PvP = {}
TisteltiPlatesPvP = PvP
local config, enabled
local states = {}
local WHITE = "Interface\\Buttons\\WHITE8X8"
local WINGS = "Interface\\AddOns\\TisteltiPlates\\Media\\Wings.tga"
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
        display=CreateFrame("Frame",nil,uf)
        display:EnableMouse(false)
        display.outline=Glow(display)
        display.outline:SetAllPoints(display)
        display.marker=display:CreateTexture(nil,"OVERLAY")
        display.marker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
        display.marker:SetSize(14,14)
        display.reason=display:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        display.reason:SetFont(STANDARD_TEXT_FONT,9,"OUTLINE")
        display.marker:SetPoint("RIGHT",display.reason,"LEFT",-3,0)
        uf.TisteltiPvPEmphasis=display
    end
    -- Outline only: never cover the real health bar, its name or its texture.
    display:ClearAllPoints()
    display:SetPoint("TOPLEFT",bar,"TOPLEFT",-6,6)
    display:SetPoint("BOTTOMRIGHT",bar,"BOTTOMRIGHT",6,-6)
    display:SetFrameLevel(bar:GetFrameLevel()+9)
    display.reason:ClearAllPoints()
    local captionAnchor=uf.castBar or uf.CastBar
    if not captionAnchor or not Read(captionAnchor.IsShown,captionAnchor) then captionAnchor=bar end
    display.reason:SetPoint("TOP",captionAnchor,"BOTTOM",0,-7)
    display.reason:SetWidth(math.max(80,bar:GetWidth()))
    display.reason:SetWordWrap(false)
    display.reason:SetJustifyH("CENTER")
    PaintGlow(display.outline,selected and {r=1,g=1,b=1} or {r=1,g=.8,b=.05})
    display.marker:SetShown(reason~=nil and reason~=false)
    display.reason:SetText(reason or "")
    display.reason:SetShown(reason~=nil and reason~=false)
    display:Show()
    return bar
end

local function Metal(parent, edge)
    local frame=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    frame:EnableMouse(false)
    frame:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=edge or 10})
    return frame
end

local function Art(parent)
    local art = Glow(parent)
    art.body=Metal(art,12)
    art.inner=Metal(art,8)
    art.highlight=art:CreateTexture(nil,"OVERLAY")
    art.highlight:SetPoint("TOPLEFT",art,"TOPLEFT",3,-1)
    art.highlight:SetPoint("TOPRIGHT",art,"TOPRIGHT",-3,-1)
    art.highlight:SetHeight(1)
    art.shadow=art:CreateTexture(nil,"OVERLAY")
    art.shadow:SetPoint("BOTTOMLEFT",art,"BOTTOMLEFT",2,1)
    art.shadow:SetPoint("BOTTOMRIGHT",art,"BOTTOMRIGHT",-2,1)
    art.shadow:SetHeight(1)
    art.levelFrame=Metal(art,10)
    art.classFrame = Glow(art)
    art.classFrame.metal=Metal(art.classFrame,10)
    art.classFrame.metal:SetPoint("TOPLEFT",-4,4)
    art.classFrame.metal:SetPoint("BOTTOMRIGHT",4,-4)
    art.classIcon = art.classFrame:CreateTexture(nil, "ARTWORK")
    art.classIcon:SetAllPoints(art.classFrame)
    art.classIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
    art.factionFrame=Metal(art,8)
    art.faction = art.factionFrame:CreateTexture(nil, "OVERLAY")
    art.faction:SetAllPoints(art.factionFrame)
    art.wings = {}
    -- Same feather artwork as the guild design, scaled for the native plate.
    for _, side in ipairs({-1, 1}) do
        local wing = CreateFrame("Frame", nil, art)
        wing:EnableMouse(false)
        wing.side = side
        wing.texture=wing:CreateTexture(nil,"ARTWORK")
        wing.texture:SetAllPoints(wing)
        wing.texture:SetTexture(WINGS)
        if side==-1 then wing.texture:SetTexCoord(0,.40,0,1)
        else wing.texture:SetTexCoord(.60,1,0,1) end
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
    -- Metal catches the light; the reaction/class colour is a narrow inset.
    for _, edge in ipairs(art.edges) do
        edge.texture:SetAlpha(.22)
    end
    local metal=guild and {r=1,g=.78,b=.34} or {r=.75,g=.79,b=.85}
    art.body:ClearAllPoints()
    art.body:SetPoint("TOPLEFT",bar,"TOPLEFT",-5,5)
    art.body:SetPoint("BOTTOMRIGHT",bar,"BOTTOMRIGHT",5,-5)
    art.body:SetBackdropBorderColor(metal.r,metal.g,metal.b,1)
    art.inner:ClearAllPoints()
    art.inner:SetPoint("TOPLEFT",bar,"TOPLEFT",-1.5,1.5)
    art.inner:SetPoint("BOTTOMRIGHT",bar,"BOTTOMRIGHT",1.5,-1.5)
    local inset=borderColor or color
    art.inner:SetBackdropBorderColor(inset.r,inset.g,inset.b,.85)
    art.highlight:SetColorTexture(.5+.45*metal.r,.5+.45*metal.g,.5+.45*metal.b,.85)
    art.shadow:SetColorTexture(.04,.05,.08,.85)
    art.body:SetFrameLevel(art:GetFrameLevel()+1)
    art.inner:SetFrameLevel(art:GetFrameLevel()+2)
    art.levelFrame:ClearAllPoints()
    if iconAnchor then
        art.levelFrame:SetPoint("TOPLEFT",iconAnchor,"TOPLEFT",-2,2)
        art.levelFrame:SetPoint("BOTTOMRIGHT",iconAnchor,"BOTTOMRIGHT",2,-2)
        art.levelFrame:SetBackdropBorderColor(metal.r,metal.g,metal.b,1)
    end
    art.levelFrame:SetShown(iconAnchor~=nil)
    local height = math.max(18, math.min(26, bar:GetHeight()+10))
    local emblem = config.emblem and (faction == "Alliance" or faction == "Horde")
    local uv = (CLASS_ICON_TCOORDS or coords)[class or ""]
    local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class or ""]
    local showClass=config.classIcon and uv~=nil and classColor~=nil
    art.factionFrame:ClearAllPoints()
    art.factionFrame:SetSize(12,12)
    art.factionFrame:SetPoint("CENTER",showClass and art.classFrame or art.body,
        showClass and "BOTTOMRIGHT" or "LEFT",showClass and 0 or -8,showClass and 1 or 0)
    art.factionFrame:SetBackdropBorderColor(metal.r,metal.g,metal.b,1)
    art.factionFrame:SetFrameLevel(art:GetFrameLevel()+5)
    if emblem then
        art.faction:SetTexture("Interface\\TargetingFrame\\UI-PVP-"..faction)
        -- Native PvP textures include unused padding on the right and bottom.
        art.faction:SetTexCoord(0, .625, 0, .625)
    end
    art.faction:SetShown(emblem and true or false)
    art.factionFrame:SetShown(emblem and true or false)
    art.classFrame:ClearAllPoints()
    art.classFrame:SetSize(config.classIconSize, config.classIconSize)
    art.classFrame:SetPoint("RIGHT",art.body,"LEFT",-4,0)
    art.classFrame.metal:SetBackdropBorderColor(metal.r,metal.g,metal.b,1)
    if uv and classColor then
        art.classIcon:SetTexCoord(unpack(uv))
        PaintGlow(art.classFrame, classColor)
        for _,edge in ipairs(art.classFrame.edges) do edge.texture:SetAlpha(.35) end
    end
    art.classFrame:SetShown(showClass)
    local wingColor = PvP.WingColor(rank)
    for _, wing in ipairs(art.wings) do
        local right = wing.side == 1
        wing:ClearAllPoints()
        -- The left wing joins the class tile; the right joins the level.
        wing:SetPoint(right and "LEFT" or "RIGHT", right and (iconAnchor or bar) or art.body,
            right and "RIGHT" or "LEFT",right and -1 or 1,0)
        wing:SetSize(height*1.5*config.wingSize,height*1.5*config.wingSize)
        wing.texture:SetVertexColor(.55+.45*wingColor.r,.55+.45*wingColor.g,.55+.45*wingColor.b,
            math.min(1,.85*config.intensity))
        wing:SetShown(config.wings and guild and true or false)
    end
    -- Both ornaments form a single silhouette; native skills stay on the right.
    if guild and config.wings then
        art.wings[1]:ClearAllPoints()
        art.wings[1]:SetPoint("RIGHT",showClass and art.classFrame or art.body,"LEFT",2,0)
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
    Emphasize(uf,bar,unit,color,enemy)
    PvP.Paint(art, bar, color, class, faction, guild, Read(TisteltiMerito, identity) or 0, iconAnchor, enemy and RED or color)
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
    text("Modo PvP · Marco heráldico", 20, -20, "GameFontNormalLarge")
    text("Doble marco metálico, clase integrada y alas de hermandad. Conserva la barra y el nombre reales.", 20, -52)
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
    check("emphasizeTargets","Destacar objetivo y recomendado",20,-329)
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
    text("Vista previa · acabado metálico y acento de clase, también con barra roja",20,-395,"GameFontNormal")
    for i, data in ipairs({{"MAGE",false,4},{"WARLOCK",true,0}}) do
        local bar = CreateFrame("StatusBar",nil,panel)
        bar:SetSize(150,16); bar:SetPoint("TOPLEFT",65+(i-1)*280,-440)
        bar:SetStatusBarTexture(WHITE); bar:SetMinMaxValues(0,100); bar:SetValue(78)
        local name=bar:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        name:SetPoint("CENTER",bar,"CENTER",0,0)
        name:SetText(i==1 and "Hermandad · Mago" or "Enemigo · Brujo")
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
