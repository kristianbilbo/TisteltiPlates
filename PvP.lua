-- Compact PvP. Native health values, plate geometry and aura anchors stay owned by Blizzard.
local PvP = {}
TisteltiPlatesPvP = PvP
local config, enabled
local states = {}
local pendingNames=setmetatable({}, {__mode="k"})
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
    for _,key in ipairs({"selected","recommended"}) do
        if type(config[key])~="boolean" then config[key]=config.emphasizeTargets end
    end
    if type(config.guildBothFactions)~="boolean" then config.guildBothFactions=false end
    if type(config.meritColors)~="boolean" then config.meritColors=true end
    if config.enemyColor ~= "red" and config.enemyColor ~= "class" then config.enemyColor = "class" end
    if config.friendColor ~= "blue" and config.friendColor ~= "class" then config.friendColor = "class" end
    if type(config.intensity) ~= "number" or config.intensity~=config.intensity or config.intensity < .6 or config.intensity > 1.4 then config.intensity = 1 end
    if type(config.wingSize) ~= "number" or config.wingSize~=config.wingSize or config.wingSize < .6 or config.wingSize > 1.2 then config.wingSize = .8 end
    if type(config.classIconSize) ~= "number" or config.classIconSize~=config.classIconSize or config.classIconSize < 16 or config.classIconSize > 32 then config.classIconSize = 22 end
    for key, fallback in pairs({low="bronce", middle="plata", high="oro"}) do
        if not palette[config[key] or ""] then config[key] = fallback end
    end
    enabled = config.enabled
end

function PvP.Sync()
    -- Returning from the old enlarged style requires protected geometry restoration.
    if config and not InCombatLockdown() then enabled = config.enabled end
    for frame,color in pairs(pendingNames) do
        if TisteltiPlatesCC.CanPosition(frame) then
            local ok=pcall(frame.SetTextColor,frame,unpack(color))
            if ok then pendingNames[frame]=nil end
        end
    end
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

local function Emphasize(uf,bar,unit,color,enemy,context)
    local selected=config.selected and enemy and Read(UnitIsUnit,unit,"target")
    local reason=config.recommended and enemy and TisteltiPlatesPriority and TisteltiPlatesPriority.Reason(unit)
    if context then
        selected=config.selected and enemy and context=="selected"
        local rules=TisteltiPlatesConfig.Get(TisteltiPlatesDB,"recommendation")
        reason=config.recommended and enemy and context=="recommended" and
            (rules.consensus and "FOCO DEL GRUPO" or rules.marked and "MARCA DEL GRUPO") or nil
    end
    local display=uf.TisteltiPvPEmphasis
    if not (selected or reason) then
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
    if not config.meritColors then rank=0 end
    if type(rank) ~= "number" or rank < 1 then return {r=.5,g=.58,b=.68} end
    return palette[rank <= 4 and config.low or rank <= 9 and config.middle or config.high]
end

function PvP.Paint(art, bar, color, class, faction, guild, rank, iconAnchor, borderColor)
    local showBorder=borderColor~=false
    if borderColor==false then borderColor=nil end
    for _,edge in ipairs(art.edges) do edge.texture:SetShown(showBorder) end
    for _,frame in ipairs({art.body,art.inner,art.highlight,art.shadow}) do frame:SetShown(showBorder) end
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
    art.levelFrame:SetShown(showBorder and iconAnchor~=nil)
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
    art.pvpShowLeftWing=config.wings and guild and true or false
    art.pvpShowRightWing=art.pvpShowLeftWing
    art.pvpShowClassIcon=config.classIcon and uv~=nil and classColor~=nil
    art.pvpShowFaction=emblem and true or false
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

local function RestoreName(state)
    local entry=state and state.name
    if not entry then return end
    state.nameTinting=true
    if TisteltiPlatesCC.CanPosition(entry.frame) then
        local ok=pcall(entry.frame.SetTextColor,entry.frame,unpack(entry.color))
        if not ok then pendingNames[entry.frame]=entry.color end
    else
        pendingNames[entry.frame]=entry.color
    end
    state.nameTinting=false
    state.name=nil
end

local function TintName(uf)
    local state=states[uf]
    local entry=state and state.name
    if not entry or not state.nameColor or state.nameTinting or not TisteltiPlatesCC.CanPosition(entry.frame) then return end
    state.nameTinting=true
    pcall(entry.frame.SetTextColor,entry.frame,state.nameColor[1],state.nameColor[2],state.nameColor[3],entry.color[4])
    state.nameTinting=false
end

local function ColorName(uf,state,faction)
    local frame=uf.name or uf.Name or (uf.NameContainer and uf.NameContainer.Name)
    state.nameColor=TisteltiPlatesPlayers.NameColor(uf.unit,true)
    if state.name and (state.name.frame~=frame or not state.nameColor) then RestoreName(state) end
    if not state.nameColor or not frame or not TisteltiPlatesCC.CanPosition(frame) then return end
    if not state.name then
        if type(frame.GetTextColor)~="function" or type(frame.SetTextColor)~="function" then return end
        local ok,r,g,b,a=pcall(frame.GetTextColor,frame)
        if not ok then return end
        for _,value in ipairs({r,g,b,a}) do
            if not Public(value) or type(value)~="number" then return end
        end
        if type(r)~="number" or type(g)~="number" or type(b)~="number" or type(a)~="number" then return end
        state.name={frame=frame,color=pendingNames[frame] or {r,g,b,a}}
        pendingNames[frame]=nil
        uf.TisteltiPvPNameHooks=uf.TisteltiPvPNameHooks or setmetatable({}, {__mode="k"})
        if not uf.TisteltiPvPNameHooks[frame] then
            hooksecurefunc(frame,"SetTextColor",function() TintName(uf) end)
            hooksecurefunc(frame,"SetVertexColor",function() TintName(uf) end)
            uf.TisteltiPvPNameHooks[frame]=true
        end
    end
    TintName(uf)
end

function PvP.Remove(uf)
    if uf.TisteltiPvPArt then uf.TisteltiPvPArt:Hide() end
    if uf.TisteltiPvPEmphasis then uf.TisteltiPvPEmphasis:Hide() end
    local state = states[uf]
    if not state then return end
    states[uf] = nil
    RestoreName(state)
    if CompactUnitFrame_UpdateHealthColor and type(uf.unit) == "string" and Public(uf.unit) and Read(UnitExists, uf.unit) then
        local ok = pcall(CompactUnitFrame_UpdateHealthColor, uf)
        if ok then return end
    end
    pcall(state.bar.SetStatusBarColor, state.bar, unpack(state.originalColor))
end

function PvP.Update(unit, uf)
    local relation = TisteltiPlatesPlayers.Kind(unit)
    if not TisteltiPlatesConfig.Allowed(TisteltiPlatesDB) or not relation then PvP.Remove(uf); return end
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
    -- Release the classic name hook before acquiring its native color snapshot.
    TisteltiPlatesPlayers.Remove(uf)
    ColorName(uf,state,faction)
    local art = uf.TisteltiPvPArt or Art(uf)
    uf.TisteltiPvPArt = art
    local identity = unit
    local guild = friend and (faction == "Alliance" or config.guildBothFactions) and Read(UnitIsInMyGuild, unit)
    if friend and (faction == "Alliance" or config.guildBothFactions) and not guild then
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
    local fallback=enemy and RED or color
    local rgb = TisteltiPlatesPlayers.BorderColor(unit,true,{fallback.r,fallback.g,fallback.b})
    local borderColor = rgb and {r=rgb[1],g=rgb[2],b=rgb[3]} or false
    PvP.Paint(art, bar, color, class, faction, guild, Read(TisteltiMerito, identity) or 0, iconAnchor, borderColor)
    Tint(uf)
end

-- Same painter and color resolution as live plates, without acquiring native frames.
function PvP.DrawPreview(uf,kind,faction,rank,scenario)
    local enemy=kind=="enemy"
    local class="MAGE"
    local color=enemy and config.enemyColor=="red" and RED or
        not enemy and config.friendColor=="blue" and BLUE or RAID_CLASS_COLORS[class]
    local bar=uf.healthBar
    bar:SetStatusBarColor(color.r,color.g,color.b)
    local fallback=enemy and RED or color
    local rgb=TisteltiPlatesConfig.ResolveColor(TisteltiPlatesDB,kind,"border",class,faction,true,{fallback.r,fallback.g,fallback.b})
    local name=TisteltiPlatesConfig.ResolveColor(TisteltiPlatesDB,kind,"name",class,faction,true)
    uf.name:SetTextColor(unpack(name or {1,1,1}))
    local art=uf.TisteltiPvPArt or Art(uf)
    uf.TisteltiPvPArt=art
    PvP.Paint(art,bar,color,class,faction,not enemy and (faction=="Alliance" or config.guildBothFactions),rank,nil,
        rgb and {r=rgb[1],g=rgb[2],b=rgb[3]} or false)
    local shown=TisteltiPlatesDB.enabled and (enemy and config.enemies or not enemy and config.friends)
    art:SetShown(shown)
    if not shown then
        local name=TisteltiPlatesConfig.ResolveColor(TisteltiPlatesDB,kind,"name",class,faction,false)
        uf.name:SetTextColor(unpack(name or {1,1,1}))
        bar:SetStatusBarColor(.41,.8,.94)
    else
        Emphasize(uf,bar,nil,color,enemy,scenario)
        if scenario=="control" and TisteltiPlatesDB.hideRightWingOnCC then art.wings[2]:Hide() end
    end
end
