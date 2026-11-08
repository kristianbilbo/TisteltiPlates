-- Forever 1.60.1. Decoration only; Blizzard owns health values and clicks.
local ADDON = ...
local driver = CreateFrame("Frame")
local tracked, active = {}, {}
local guildLabels = {}
local combatArt = {}
local db, preview
local GOLD = {1, .73, .22}
local WHITE = "Interface\\Buttons\\WHITE8X8"
local WINGS = "Interface\\AddOns\\TisteltiPlates\\Media\\Wings.tga"
local PARTY_WINGS = "Interface\\AddOns\\TisteltiPlates\\Media\\Wings-Grupo-v1.tga"
local RAID_WINGS = "Interface\\AddOns\\TisteltiPlates\\Media\\Wings-Banda-v1.tga"
local ASSASSIN = "Interface\\AddOns\\TisteltiPlates\\Media\\Assassin.tga"
local SILVER = {.78, .85, .94}
local BLUE = {.12, .36, .82}
local Refresh

local metals = {cobre={.96,.48,.27}, bronce={.78,.54,.28}, platino={.87,.96,1},
    zafiro={.22,.55,1}, esmeralda={.18,.88,.59}, amatista={.76,.43,1}, rubi={1,.25,.37}}
local function BorderColor(style, color, tier)
    local config = db.appearance[style]
    if metals[config.border] then return metals[config.border] end
    if config.border == "plata" then return SILVER end
    if config.border == "clase" then return {color.r, color.g, color.b} end
    if config.border == "color" then return config.color end
    if config.border == "rango" then
        return ({SILVER, {.55, .75, 1}, GOLD, {1, .88, .48}})[tier + 1]
    end
    return GOLD
end

local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end

local function Safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and Public(value) then return value end
end

local function Message(text)
    print("|cffffcd62Tistelti|r: " .. text)
end

local function Allowed()
    if not db or not db.enabled then return false end
    local inside, kind = IsInInstance()
    return not inside or (TisteltiPlatesPvP and TisteltiPlatesPvP.IsActive() and (kind == "pvp" or kind == "arena"))
end

local function Color(unit)
    local _, class = UnitClass(unit)
    if not Public(class) then return nil end
    return RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
end

local function PreferredStyle(groupStyle, sameGuild)
    local guildStyle = db.guild and sameGuild and "guild" or nil
    if db.priority == "group" then return groupStyle or guildStyle end
    return guildStyle or groupStyle
end

local function Membership(unit)
    if not Safe(UnitIsPlayer, unit) or Safe(UnitIsUnit, unit, "player") then return nil end
    if not Safe(UnitIsFriend, "player", unit) then return nil end
    local groupStyle
    if Safe(IsInRaid) then
        if db.raid and Safe(UnitInRaid, unit) then groupStyle = "raid" end
    elseif db.group and Safe(UnitInParty, unit) then
        groupStyle = "group"
    end
    return PreferredStyle(groupStyle, Safe(UnitIsInMyGuild, unit))
end

local function RosterMembership(unit, roster, rosterStyle)
    if roster then
        -- Forever can expose guild membership through either unit token.
        return PreferredStyle(rosterStyle, Safe(UnitIsInMyGuild, roster) or Safe(UnitIsInMyGuild, unit))
    end
    return Membership(unit)
end

local function Rank(unit)
    return Safe(TisteltiMerito, unit) or 0
end

local function ArtCell(t,index)
    t:SetTexture("Interface\\AddOns\\TisteltiPlates\\Media\\Heraldica.tga")
    local x,y=(index%4)/4,math.floor(index/4)/2
    t:SetTexCoord(x,x+.25,y,y+.5)
end
-- Source atlas (0 = existing, 1 = additions), cell. Fixed progression.
local meritBadges = {
    {0,0}, {0,0}, {1,2}, {0,1}, {0,2}, {1,3}, {1,1},
    {1,0}, {1,0}, {1,4}, {0,4}, {0,4}, {0,5}, {0,5},
}
local function AnimalCell(t, rank)
    local badge = meritBadges[rank]
    local index = badge[2]
    t:SetTexture(badge[1] == 1
        and "Interface\\AddOns\\TisteltiPlates\\Media\\EscudosExtra-v4.tga"
        or "Interface\\AddOns\\TisteltiPlates\\Media\\EscudosAlianza-v3.tga")
    local x, y = (index % 3) / 3, math.floor(index / 3) / 2
    t:SetTexCoord(x, x + 1/3, y, y + .5)
end
local function Tier(rank)
    if rank >= 12 then return 3 end
    if rank >= 8 then return 2 end
    if rank >= 4 then return 1 end
    return 0
end

local function FrameBorder(parent, edge, fill)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:EnableMouse(false)
    f:SetBackdrop({bgFile = fill and WHITE or nil,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = edge,
        insets = {left = 3, right = 3, top = 3, bottom = 3}})
    f:SetBackdropBorderColor(unpack(GOLD))
    if fill then f:SetBackdropColor(.015, .025, .065, .98) end
    return f
end

local function Diamond(parent, size, layer)
    local t = parent:CreateTexture(nil, layer or "OVERLAY")
    t:SetTexture(WHITE)
    t:SetSize(size, size)
    t:SetRotation(math.pi / 4)
    return t
end

local function Ornament(parent)
    local o = CreateFrame("Frame", nil, parent)
    o:EnableMouse(false)
    o.body = FrameBorder(o, 12, false)
    o.inner = FrameBorder(o, 8, false)
    o.ccAnchor = CreateFrame("Frame", nil, o)
    o.ccAnchor:SetSize(1, 1)
    o.ccAnchor:EnableMouse(false)
    o.wings = o:CreateTexture(nil, "ARTWORK")
    o.wings:SetTexture(WINGS)
    o.wings:SetTexCoord(0, .40, 0, 1)
    o.rightWing = o:CreateTexture(nil, "ARTWORK")
    o.rightWing:SetTexture(WINGS)
    o.rightWing:SetTexCoord(.60, 1, 0, 1)
    local function illuminateWing(wing, left, right)
        local light = o:CreateTexture(nil, "ARTWORK", nil, 1)
        light:SetTexture(WINGS)
        light:SetTexCoord(left, right, 0, 1)
        light:SetAllPoints(wing)
        light:SetBlendMode("ADD")
        light:SetAlpha(.62)
        return light
    end
    o.leftWingLight = illuminateWing(o.wings, 0, .40)
    o.rightWingLight = illuminateWing(o.rightWing, .60, 1)
    o.halo = FrameBorder(o, 12, false)
    o.halo:SetPoint("TOPLEFT",o.body,"TOPLEFT",-1.5,1.5)
    o.halo:SetPoint("BOTTOMRIGHT",o.body,"BOTTOMRIGHT",1.5,-1.5)
    o.halo:SetAlpha(.76)
    o.shade = o.body:CreateTexture(nil, "OVERLAY")
    o.shade:SetPoint("BOTTOMLEFT", o.body, "BOTTOMLEFT", 5, 2)
    o.shade:SetPoint("BOTTOMRIGHT", o.body, "BOTTOMRIGHT", -5, 2)
    o.shade:SetHeight(1)
    o.lustre = o.body:CreateTexture(nil, "OVERLAY")
    o.lustre:SetPoint("TOPLEFT", o.body, "TOPLEFT", 5, -2)
    o.lustre:SetPoint("TOPRIGHT", o.body, "TOPRIGHT", -5, -2)
    o.lustre:SetHeight(2)
    o.lustre:SetBlendMode("ADD")
    o.guildName = o:CreateFontString(nil, "OVERLAY")
    o.guildName:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    o.guildName:SetPoint("TOP", o.body, "BOTTOM", 0, -1)
    o.guildName:SetTextColor(.83, .88, 1)
    o.badge = FrameBorder(o, 12, true)
    o.badge:SetFrameLevel(o:GetFrameLevel() + 3)
    o.level = o.badge:CreateFontString(nil, "OVERLAY")
    o.level:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    o.level:SetPoint("CENTER", 0, .5)
    o.level:SetTextColor(1, .95, .77)
    o.level:SetShadowColor(1, .65, .12, .9)
    o.level:SetShadowOffset(0, 0)
    o.badgeGlow = FrameBorder(o.badge, 12, false)
    o.badgeGlow:SetPoint("TOPLEFT", o.badge, "TOPLEFT", -1, 1)
    o.badgeGlow:SetPoint("BOTTOMRIGHT", o.badge, "BOTTOMRIGHT", 1, -1)
    o.badgeGlow:SetAlpha(.8)
    o.honor = o.badge:CreateTexture(nil, "OVERLAY", nil, 6)
    o.honor:SetPoint("TOP", o.badge, "BOTTOM", 0, 2)
    o.lionEmblem = o.badge:CreateTexture(nil, "OVERLAY", nil, 7)
    -- Use the user's actual attachment, not a regenerated or older lion atlas.
    o.lionEmblem:SetTexture("Interface\\AddOns\\TisteltiPlates\\Media\\LeonElegido-v5.tga")
    o.lionEmblem:SetTexCoord(0, .25, 0, .5)
    o.lionEmblem:SetPoint("CENTER", o.honor, "CENTER", 0, -1)
    o.honorBorder = FrameBorder(o.badge, 8, false)
    o.honorBorder:SetPoint("CENTER", o.honor, "CENTER")
    o.guildRole = o:CreateFontString(nil, "OVERLAY")
    o.guildRole:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    o.guildRole:SetPoint("BOTTOMLEFT", o.body, "TOPLEFT", 2, 2)
    o.guildRole:SetTextColor(1, .87, .45)
    o.levelShine = o.badge:CreateTexture(nil, "OVERLAY")
    o.levelShine:SetPoint("TOPLEFT", o.badge, "TOPLEFT", 4, -2)
    o.levelShine:SetPoint("TOPRIGHT", o.badge, "TOPRIGHT", -4, -2)
    o.levelShine:SetHeight(2)
    o.levelShine:SetBlendMode("ADD")
    o.gemGold = Diamond(o.badge, 7)
    o.gemGold:SetPoint("TOP", o.badge, "BOTTOM", 0, 2)
    o.gemGold:SetVertexColor(unpack(GOLD))
    o.gem = Diamond(o.badge, 4.5)
    o.gem:SetPoint("CENTER", o.gemGold, "CENTER")
    o.gleam = Diamond(o.badge, 1.5)
    o.gleam:SetPoint("CENTER", o.gem, "CENTER", -1, 1)
    o.gleam:SetVertexColor(1, 1, 1, .85)
    o.swords={}
    for i=1,3 do o.swords[i]=o.badge:CreateTexture(nil,"OVERLAY",nil,4) end
    o.crown=o.badge:CreateTexture(nil,"OVERLAY",nil,5)
    o.crest = {}
    for i = 1, 3 do
        local jewel = Diamond(o.badge, 3)
        o.crest[i] = jewel
    end
    o.stars = {}
    for i = 1, 3 do
        local star = Diamond(o.badge, 3)
        star:SetVertexColor(unpack(GOLD))
        o.stars[i] = star
    end
    o:Hide()
    TisteltiPlatesCC.AttachArt(o, parent)
    return o
end

local function PaintWings(o, style)
    local texture = WINGS
    if style == "group" then
        texture = PARTY_WINGS
    elseif style == "raid" then
        texture = RAID_WINGS
    end
    if o.wingTexture == texture then return end
    for _, wing in ipairs({o.wings, o.rightWing, o.leftWingLight, o.rightWingLight}) do
        wing:SetTexture(texture)
    end
    -- The original blue/gold art keeps its existing additive illumination.
    local lightAlpha = texture == WINGS and .62 or .18
    o.leftWingLight:SetAlpha(lightAlpha)
    o.rightWingLight:SetAlpha(lightAlpha)
    o.wingTexture = texture
end

local function SetGuildName(label, guild)
    -- Follow the plate's native scale. Inverting a transient near-zero parent
    -- scale leaves a huge multiplier behind when combat/recycling interrupts.
    label:SetScale(1)
    label:SetText(guild and ("<" .. guild .. ">") or "")
    label:SetShown(guild ~= nil)
end

local function Paint(o, anchor, style, color, level, rank, scale, guildName)
    PaintWings(o, style)
    local tier = Tier(rank)
    local border = BorderColor(style, color, tier)
    local icon = "ninguno" -- One heraldic merit emblem below the level.
    -- Nameplate children have different frame levels; the base UnitFrame level
    -- is not high enough to draw a border over HealthBarsContainer.
    local anchorLevel = anchor.GetFrameLevel and anchor:GetFrameLevel() or 0
    o:SetFrameLevel(anchorLevel + 10)
    o.halo:SetFrameLevel(anchorLevel + 10)
    o.halo:SetBackdropBorderColor(.20+.80*border[1],.20+.80*border[2],.20+.80*border[3],1)
    o.body:SetFrameLevel(anchorLevel + 11)
    o.inner:SetFrameLevel(anchorLevel + 12)
    o.badge:SetFrameLevel(anchorLevel + 14)
    o:ClearAllPoints()
    o:SetAllPoints(anchor)
    o.body:ClearAllPoints()
    o.body:SetPoint("TOPLEFT", anchor, "TOPLEFT", -5, 5)
    o.body:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 5, -5)
    o.body:SetBackdropBorderColor(border[1], border[2], border[3], 1)
    o.inner:ClearAllPoints()
    o.inner:SetPoint("TOPLEFT", anchor, "TOPLEFT", -1, 1)
    o.inner:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 1, -1)
    if db.appearance[style].border == "oroazul" then
        o.inner:SetBackdropBorderColor(BLUE[1], BLUE[2], BLUE[3], 1)
    else
        o.inner:SetBackdropBorderColor(border[1], border[2], border[3], .8)
    end
    o.inner:SetShown(true)
    o.badge:ClearAllPoints()
    local frameHeight = anchor:GetHeight() + 10
    o.badge:SetSize(math.max(20,frameHeight), frameHeight)
    o.badge:SetBackdropBorderColor(.25+.75*border[1], .25+.75*border[2], .25+.75*border[3], 1)
    o.badgeGlow:SetBackdropBorderColor(1, .86, .48, 1)
    o.level:SetTextColor(1, .97, .83)
    o.levelShine:SetColorTexture(.5+.5*border[1], .5+.5*border[2], .5+.5*border[3], 1)
    o.gemGold:SetVertexColor(unpack(border))
    -- Leave room for the left wing so it does not cover the player's name.
    o.badge:SetPoint("LEFT", o.body, "RIGHT", -1, 0)
    o.level:SetFont(STANDARD_TEXT_FONT, math.min(14 * scale, frameHeight * .70), "OUTLINE")
    o.level:SetText(level)
    o.wings:ClearAllPoints()
    local wingWidth = frameHeight * (1.34 + .10*tier) * 1.30
    o.wings:SetSize(wingWidth, frameHeight * 1.742)
    o.wings:SetPoint("RIGHT", o.body, "LEFT", 3, 1)
    o.rightWing:ClearAllPoints()
    o.rightWing:SetSize(wingWidth, frameHeight * 1.742)
    o.rightWing:SetPoint("LEFT", o.badge, "RIGHT", -3, 1)
    o.shade:SetColorTexture(.40 * border[1], .40 * border[2], .40 * border[3], 1)
    o.lustre:SetColorTexture(.4 + .6 * border[1], .4 + .6 * border[2], .4 + .6 * border[3], .95)
    SetGuildName(o.guildName, guildName)
    o.gem:SetVertexColor(color.r, color.g, color.b)
    -- The honor badge replaces the class diamond, including its gold rim.
    o.gemGold:Hide()
    o.gem:Hide()
    o.gleam:Hide()
    o.honor:SetShown(rank > 0)
    o.lionEmblem:SetShown(rank == 8 or rank == 9)
    o.lionEmblem:SetSize(19 * scale, 19 * scale)
    -- Metal rim and crossed swords are painted into the badge itself.
    o.honorBorder:Hide()
    if rank > 0 then
        AnimalCell(o.honor, rank)
        o.honor:SetVertexColor(1, 1, 1)
        o.honor:SetDesaturated(false)
        o.honor:SetSize(30 * scale, 30 * scale)
    end
    for i, star in ipairs(o.stars) do
        star:ClearAllPoints()
        star:SetTexCoord(0, 1, 0, 1)
        star:SetRotation(0)
        if icon == "alianza" or icon == "animales" then
            local animal = rank>=12 and 5 or rank>=10 and 4 or rank>=7 and 0 or rank>=5 and 3 or rank>=3 and 2 or 1
            ArtCell(star,icon=="alianza" and 0 or animal)
            star:SetSize(23*scale,23*scale)
            star:SetVertexColor(1,1,1)
            star:SetPoint("BOTTOM",o.badge,"TOP",0,1)
            star:SetShown(i==1)
        elseif icon == "asesino" then
            -- One recognizable emblem, rather than several unreadable heads.
            star:SetTexture(ASSASSIN)
            star:SetSize((15 + tier * 2) * scale, (15 + tier * 2) * scale)
            star:SetVertexColor(1, 1, 1)
            star:SetPoint("BOTTOM", o.badge, "TOP", 0, 0)
            star:SetShown(i == 1)
        else
            local spacing = icon == "estrella" and 9 or 6
            star:SetPoint("BOTTOM", o.badge, "TOP", (i - (tier + 1) / 2) * spacing * scale, 1)
            if icon == "estrella" then
                star:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
                star:SetSize(8 * scale, 8 * scale)
                star:SetVertexColor(1, 1, 1)
            else
                star:SetTexture(WHITE)
                star:SetRotation(math.pi / 4)
                star:SetSize(3 * scale, 3 * scale)
                star:SetVertexColor(unpack(border))
            end
            star:SetShown(icon ~= "ninguno" and i <= tier)
        end
    end
    for _, sword in ipairs(o.swords) do sword:Hide() end
    o.crown:SetShown(false)
    -- Clasps on the hood progress independently of wing size and class gem.
    for i, jewel in ipairs(o.crest) do
        jewel:SetShown(icon == "asesino" and i <= tier)
        if icon == "asesino" and i <= tier then
            local metal = ({metals.bronce, SILVER, GOLD})[tier]
            jewel:SetVertexColor(unpack(metal))
            jewel:SetDrawLayer("OVERLAY", 6)
            jewel:SetSize(3.5 * scale, 3.5 * scale)
            jewel:ClearAllPoints()
            jewel:SetPoint("BOTTOM", o.stars[1], "BOTTOM", (i - (tier + 1)/2) * 5 * scale, 0)
        end
    end
    -- Buffs start above the left wing, including its full scaled height.
    o.ccAnchor:ClearAllPoints()
    o.ccAnchor:SetPoint("BOTTOMLEFT", o.wings, "TOPLEFT", 0, 6 * scale)
    o:Show()
end

local function RememberLevel(state, frame)
    if not frame or state.levelSeen[frame] or Safe(frame.IsForbidden, frame) then return end
    state.levelSeen[frame] = true
    state.levels[#state.levels + 1] = {frame = frame, alpha = frame:GetAlpha()}
end

local function Layout(state)
    if not Allowed() or InCombatLockdown() then return end
    for _, entry in ipairs(state.levels) do entry.frame:SetAlpha(0) end
    TisteltiPlatesCC.Position(state.art:GetParent())
end

local function Remove(uf)
    if TisteltiPlatesPvP then TisteltiPlatesPvP.Remove(uf) end
    if combatArt[uf] then combatArt[uf]:Hide(); combatArt[uf] = nil end
    if guildLabels[uf] then guildLabels[uf]:Hide() end
    local state = active[uf]
    if not state then return end
    if InCombatLockdown() then
        state.art:Hide()
        state.pendingRemoval = true
        return -- Restore native scale/anchors only after combat lockdown ends.
    end
    active[uf] = nil -- Hooks must see it inactive before Blizzard restores colors.
    state.art:Hide()
    if state.geometryChanged then
        uf:SetScale(state.baseScale)
        uf:SetWidth(state.baseWidth)
    end
    for _, entry in ipairs(state.levels) do entry.frame:SetAlpha(entry.alpha) end
    TisteltiPlatesCC.Position(uf)
    -- Removed plates may have no unit by the time deferred cleanup runs.
    -- Blizzard's color updater requires a live unit; otherwise restore our snapshot.
    if CompactUnitFrame_UpdateHealthColor and Public(uf.unit)
        and type(uf.unit) == "string" and Safe(UnitExists, uf.unit) then
        CompactUnitFrame_UpdateHealthColor(uf)
    elseif state.bar and state.originalColor then
        state.bar:SetStatusBarColor(unpack(state.originalColor))
    end
end

local function PlainGuildName(uf, unit)
    if not Allowed() or not Safe(UnitIsPlayer, unit) or Safe(UnitIsUnit, unit, "player") then return end
    local guild = Safe(GetGuildInfo, unit)
    if type(guild) ~= "string" or guild == "" then return end
    local label = guildLabels[uf]
    if not label then
        label = uf:CreateFontString(nil, "OVERLAY")
        label:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        label:SetTextColor(.83, .88, 1)
        guildLabels[uf] = label
    end
    label:ClearAllPoints()
    label:SetPoint("TOP", uf.HealthBarsContainer or uf.healthBar or uf, "BOTTOM", 0, -3)
    SetGuildName(label, guild)
end

local function Tint(uf)
    local state = active[uf]
    if state and not state.pendingRemoval and Allowed() and not InCombatLockdown() and not state.tinting then
        state.tinting = true
        state.bar:SetStatusBarColor(state.color.r, state.color.g, state.color.b)
        state.tinting = false
    end
end

local function Update(unit, plate)
    local uf = plate and plate.UnitFrame
    if not uf or Safe(uf.IsForbidden, uf) then return end
    if TisteltiPlatesPvP and TisteltiPlatesPvP.IsActive() then
        if active[uf] or combatArt[uf] then Remove(uf) end
        if guildLabels[uf] then guildLabels[uf]:Hide() end
        TisteltiPlatesCC.Position(uf)
        if Allowed() then TisteltiPlatesPvP.Update(unit, uf) else TisteltiPlatesPvP.Remove(uf) end
        return
    end
    if TisteltiPlatesPvP then TisteltiPlatesPvP.Remove(uf) end
    -- A party token and a nameplate token can refer to the same character.
    -- Use the roster identity when Forever exposes more data through it.
    local roster
    local rosterStyle = Safe(IsInRaid) and "raid" or "group"
    if Allowed() and (db[rosterStyle] or db.guild) then
        local prefix = rosterStyle == "raid" and "raid" or "party"
        local count = prefix == "raid" and GetNumGroupMembers() or GetNumSubgroupMembers()
        for i = 1, count do
            local candidate = prefix .. i
            if Safe(UnitIsUnit, unit, candidate) and not Safe(UnitIsUnit, candidate, "player") then
                roster = candidate
                break
            end
        end
    end
    local style = Allowed() and RosterMembership(unit, roster, db[rosterStyle] and rosterStyle)
    if not style then
        Remove(uf)
        PlainGuildName(uf, unit)
        return
    end
    if guildLabels[uf] then guildLabels[uf]:Hide() end
    local bar = uf.healthBar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar)
    if not bar or Safe(bar.IsForbidden, bar) or not bar:IsShown() then Remove(uf); return end
    local color = Color(roster or unit)
    if not color then Remove(uf); return end
    local level = Safe(UnitLevel, roster or unit)
    if type(level) ~= "number" or level < 1 then level = "?" end
    local state = active[uf]
    if not state then
        local art = uf.TisteltiArt or Ornament(uf)
        uf.TisteltiArt = art
        state = {art = art, bar = bar, baseScale = uf:GetScale(), baseWidth = uf:GetWidth(), originalColor = {bar:GetStatusBarColor()},
            levels = {}, levelSeen = {}}
        -- Both exist in Forever. PlayerLevelDiffFrame is the extra native box
        -- visible beside the custom badge in the reported screenshot.
        RememberLevel(state, uf.LevelFrame)
        RememberLevel(state, uf.PlayerLevelDiffFrame)
        if uf.HealthBarsContainer then RememberLevel(state, uf.HealthBarsContainer.LevelFrame) end
        RememberLevel(state, bar.LevelFrame)
        active[uf] = state
        if not uf.TisteltiLayoutHooked and type(uf.UpdateAnchors) == "function" then
            hooksecurefunc(uf, "UpdateAnchors", function()
                local current = active[uf]
                if current then Layout(current) end
            end)
            uf.TisteltiLayoutHooked = true
        end
        if not bar.TisteltiColorHooked then
            hooksecurefunc(bar, "SetStatusBarColor", function() Tint(uf) end)
            bar.TisteltiColorHooked = true
        end
    end
    -- EllesmereUI can host the name outside this UnitFrame. Enlarging only
    -- the native rectangle then makes that name look smaller than the bar.
    -- Leave geometry and text sizing to its nameplate module.
    local externalGeometry = Safe(C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded,
        "EllesmereUINameplates")
    if externalGeometry then
        if state.geometryChanged then
            uf:SetScale(state.baseScale)
            uf:SetWidth(state.baseWidth)
            state.geometryChanged = nil
        end
    else
        if not state.geometryChanged then
            state.baseScale, state.baseWidth = uf:GetScale(), uf:GetWidth()
            state.geometryChanged = true
        end
        local desiredScale = state.baseScale * 1.25
        if math.abs(uf:GetScale()-desiredScale) > .001 then uf:SetScale(desiredScale) end
        local desiredWidth = state.baseWidth * 1.22
        if math.abs(uf:GetWidth()-desiredWidth) > .01 then uf:SetWidth(desiredWidth) end
    end
    state.color = color
    -- Enclose the whole native name/health rectangle, not just its colored fill.
    local guildName = Safe(GetGuildInfo, roster or unit) or Safe(GetGuildInfo, unit)
    if not guildName and Safe(UnitIsInMyGuild, roster or unit) then guildName = Safe(GetGuildInfo, "player") end
    if type(guildName) ~= "string" or guildName == "" then guildName = nil end
    Paint(state.art, uf.HealthBarsContainer or bar, style, color, level, Rank(roster or unit), db.scale, guildName)
    -- Rank zero is the guild master. Other rank numbers are guild-defined;
    -- never assume that rank one or two necessarily means officer.
    local ok, guild, guildRank, guildIndex = pcall(GetGuildInfo, roster or unit)
    local role = ""
    if ok and Public(guild) and Public(guildIndex) and Public(guildRank) and guild then
        if guildIndex == 0 then role = "Maestro"
        elseif type(guildRank) == "string" and guildRank:lower() == "oficial" then role = "Oficial" end
    end
    state.art.guildRole:SetText(role)
    Layout(state)
    Tint(uf)
end

local function UpdateCombat(unit, plate)
    local uf = plate and plate.UnitFrame
    if not uf or Safe(uf.IsForbidden, uf) then return end
    if TisteltiPlatesPvP and TisteltiPlatesPvP.IsActive() then
        if active[uf] or combatArt[uf] then Remove(uf) end
        if guildLabels[uf] then guildLabels[uf]:Hide() end
        if Allowed() then TisteltiPlatesPvP.Update(unit, uf) else TisteltiPlatesPvP.Remove(uf) end
        return
    end
    if TisteltiPlatesPvP then TisteltiPlatesPvP.Remove(uf) end
    if not Allowed() then Remove(uf); return end
    local style = Membership(unit)
    if not style then
        Remove(uf)
        PlainGuildName(uf, unit)
        return
    end
    -- Existing decorated plates retain their layout. New plates get only
    -- addon-owned artwork; never resize/recolor/reanchor native regions here.
    local state = active[uf]
    if state and not state.pendingRemoval then
        PaintWings(state.art, style)
        return
    end
    if guildLabels[uf] then guildLabels[uf]:Hide() end
    local bar = uf.HealthBarsContainer or uf.healthBar
    local color = Color(unit)
    if not bar or Safe(bar.IsForbidden, bar) or not bar:IsShown() or not color then return end
    local art = uf.TisteltiCombatArt or Ornament(uf)
    uf.TisteltiCombatArt = art
    combatArt[uf] = art
    local level = Safe(UnitLevel, unit)
    if type(level) ~= "number" or level < 1 then level = "?" end
    local guild = Safe(GetGuildInfo, unit)
    if type(guild) ~= "string" or guild == "" then guild = nil end
    Paint(art, bar, style, color, level, Rank(unit), db.scale, guild)
    art.guildRole:SetText("")
end

local function RefreshOverlays()
    for unit, plate in pairs(tracked) do
        local uf = plate and plate.UnitFrame
        TisteltiPlatesCC.Position(uf)
        if TisteltiPlatesPlayers then
            local decorated = uf and ((active[uf] and not active[uf].pendingRemoval) or combatArt[uf])
            local pvpArt = uf and uf.TisteltiPvPArt
            TisteltiPlatesPlayers.Update(uf, unit, db, decorated, pvpArt and Safe(pvpArt.IsShown, pvpArt))
        end
    end
end

Refresh = function()
    if not db then return end
    if TisteltiPlatesCC.Sync then TisteltiPlatesCC.Sync() end
    if TisteltiPlatesPvP then TisteltiPlatesPvP.Sync() end
    if TisteltiPlatesPriority then
        TisteltiPlatesPriority.Update(tracked,Allowed() and TisteltiPlatesPvP and TisteltiPlatesPvP.IsActive())
    end
    if InCombatLockdown() then
        for unit, plate in pairs(tracked) do
            local ok, err = pcall(UpdateCombat, unit, plate)
            if not ok and not driver.combatReported then
                driver.combatReported = true
                Message("Error al dibujar en combate: " .. tostring(err))
            end
        end
        RefreshOverlays()
        return
    end
    for uf, art in pairs(combatArt) do art:Hide(); combatArt[uf] = nil end
    for uf, state in pairs(active) do
        if state.pendingRemoval then Remove(uf) end
    end
    if preview and preview.samples then
        for _, sample in ipairs(preview.samples) do
            Paint(sample.art, sample.bar, sample.style, sample.color, 60, sample.rank, db.scale * 1.3, Safe(GetGuildInfo, "player"))
        end
    end
    if not Allowed() then
        for _, plate in pairs(tracked) do
            if plate and plate.UnitFrame then Remove(plate.UnitFrame) end
        end
        for uf in pairs(active) do Remove(uf) end
        for _, label in pairs(guildLabels) do label:Hide() end
        RefreshOverlays()
        return
    end
    for unit, plate in pairs(tracked) do
        local ok, err = pcall(Update, unit, plate)
        if not ok and not driver.reported then
            driver.reported = true
            Message("Error al dibujar la placa: " .. tostring(err))
        end
    end
    RefreshOverlays()
end

local function Preview()
    if preview then preview:SetShown(not preview:IsShown()); return end
    preview = FrameBorder(UIParent, 16, true)
    preview:SetSize(720, 543)
    preview:SetPoint("CENTER")
    preview:SetFrameStrata("DIALOG")
    preview:EnableMouse(true)
    preview:SetMovable(true)
    preview:RegisterForDrag("LeftButton")
    preview:SetScript("OnDragStart", preview.StartMoving)
    preview:SetScript("OnDragStop", preview.StopMovingOrSizing)
    local title = preview:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("TISTELTI - Alas de grupo")
    local close = CreateFrame("Button", nil, preview, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    local samples = {
        {"GRUPO · Turquesa y violeta suave · Mago", "group", "MAGE", 0},
        {"BANDA · Naranja y grafito · Mago", "raid", "MAGE", 0},
        {"HERMANDAD · Sacerdote · sin rango", "guild", "PRIEST", 0},
        {"HERMANDAD · Druida · rango 8", "guild", "DRUID", 8},
        {"HERMANDAD · Guerrero · rango 14", "guild", "WARRIOR", 14},
    }
    preview.samples = {}
    for i, data in ipairs(samples) do
        local label = preview:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", 30, -45 - (i - 1) * 73)
        label:SetText(data[1])
        local bar = CreateFrame("StatusBar", nil, preview)
        bar:SetSize(290, 18)
        bar:SetPoint("TOPLEFT", 30, -68 - (i - 1) * 73)
        bar:SetStatusBarTexture(WHITE)
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(73)
        local color = RAID_CLASS_COLORS[data[3]]
        bar:SetStatusBarColor(color.r, color.g, color.b)
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetColorTexture(.025, .035, .07, 1)
        local name = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        name:SetPoint("LEFT", 5, 0); name:SetText("Tistelti · " .. data[3])
        local art = Ornament(bar)
        Paint(art, bar, data[2], color, 60, data[4], db.scale * 1.3, Safe(GetGuildInfo, "player"))
        preview.samples[#preview.samples + 1] = {art=art, bar=bar, style=data[2], color=color, rank=data[4]}
    end
    local function Cycle(current, options)
        for i, v in ipairs(options) do if v == current then return options[i % #options + 1] end end
        return options[1]
    end
    local borders = {"oroazul", "oro", "plata", "clase", "rango"}
    local icons = {"animales"}
    for i, style in ipairs({"group", "raid", "guild"}) do
        local key = style
        for j, field in ipairs({"border", "icon"}) do
            local property = field
            local button = CreateFrame("Button", nil, preview, "UIPanelButtonTemplate")
            button:SetSize(220, 24)
            button:SetPoint("BOTTOMLEFT", 15 + (i - 1) * 235, 46 + (2 - j) * 28)
            local function Label()
                button:SetText(({group="Grupo", raid="Banda", guild="Hermandad"})[key] ..
                    (property == "border" and " · borde: " or " · icono: ") .. db.appearance[key][property])
            end
            button:SetScript("OnClick", function()
                db.appearance[key][property] = Cycle(db.appearance[key][property], property == "border" and borders or icons)
                Label(); Refresh()
            end)
            button:SetScript("OnShow", Label)
            Label()
        end
    end
    local note = preview:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("BOTTOM", 0, 14)
    note:SetText("Vista de diseño: los rangos mostrados son ejemplos. Arrastra para mover.")
    preview:Show()
end

local function RegisterOptions()
    TisteltiPlatesOptions.Register(db, {Refresh=Refresh, FrameBorder=FrameBorder, Ornament=Ornament,
        Paint=Paint, Safe=Safe, WHITE=WHITE, SILVER=SILVER})
end

SLASH_TISTELTIPLATES1 = "/tistelti"
SlashCmdList.TISTELTIPLATES = function(text)
    if not db then return end
    local cmd, value = text:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "pvp" then
        if value == "on" or value == "off" then
            db.pvp.enabled = value == "on"
            if InCombatLockdown() then Message("El cambio de modo se aplicará al terminar el combate.") end
            Refresh()
        elseif TisteltiPlatesPvP.category and Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(TisteltiPlatesPvP.category:GetID())
        else
            Message("Opciones > AddOns > TisteltiPlates > Modo PvP. /tistelti pvp on/off")
        end
        return
    end
    if cmd == "enemigos" then
        if value ~= "rojo" and value ~= "clase" then Message("/tistelti enemigos rojo/clase"); return end
        db.pvp.enemyColor = value == "rojo" and "red" or "class"
        Refresh(); return
    end
    if cmd == "cc" then TisteltiPlatesCC.Report(); return end
    if cmd == "vista" then Preview(); return end
    if cmd == "on" or cmd == "off" then db.enabled = cmd == "on"
    elseif cmd == "borde" or cmd == "icono" or cmd == "color" then
        local scope, choice = value:match("^(%S+)%s+(.+)$")
        local style = scope == "grupo" and "group" or scope == "banda" and "raid" or scope == "guild" and "guild"
        if not style then Message("Indica grupo, banda o guild; ejemplo: borde banda plata."); return end
        local config = db.appearance[style]
        if cmd == "borde" then
            if not metals[choice] and choice ~= "oroazul" and choice ~= "oro" and choice ~= "plata" and choice ~= "clase" and choice ~= "rango" then
                Message("Bordes: oroazul, oro, plata, clase o rango."); return
            end
            config.border = choice
        elseif cmd == "icono" then
            config.icon = "animales"
            Message("Insignia de mérito: animales con espadas y reborde bronce, plata u oro.")
        else
            local r, g, b = choice:match("^(%S+)%s+(%S+)%s+(%S+)$")
            r, g, b = tonumber(r), tonumber(g), tonumber(b)
            if not r or not g or not b or r < 0 or r > 1 or g < 0 or g > 1 or b < 0 or b > 1 then
                Message("Color RGB entre 0 y 1; ejemplo: color guild 0.3 0.8 1"); return
            end
            config.border, config.color = "color", {r, g, b}
        end
    elseif cmd == "grupo" or cmd == "banda" or cmd == "guild" then
        if value ~= "on" and value ~= "off" then Message("Usa " .. cmd .. " on/off."); return end
        db[({grupo="group", banda="raid", guild="guild"})[cmd]] = value == "on"
    elseif cmd == "tamano" then
        local n = tonumber(value)
        if not n or n < .8 or n > 1.8 then Message("Tamaño: entre 0.8 y 1.8; normal 1."); return end
        db.scale = n
    elseif cmd == "merito" or cmd == "rango" then
        local unit = Safe(UnitIsPlayer, "target") and "target" or "player"
        Message(Safe(TisteltiHonorTexto, unit) or "Mérito: sin datos")
    else
        Message("/tistelti cc | vista | on/off | grupo/banda/guild on/off | tamano 0.8–1.8")
        Message("/tistelti pvp: opciones compactas | pvp on/off | enemigos rojo/clase")
        Message("/tistelti merito: consulta el mérito del objetivo o de tu personaje")
        Message("borde grupo/banda/guild oroazul/oro/plata/clase/rango | Insignia: animales por mérito")
        Message("color grupo/banda/guild R G B (valores de 0 a 1). Vista incluye botones de personalización.")
        Message("PvP: mundo abierto y campos de batalla/arenas. Mérito automático; no es rango oficial.")
        return
    end
    Refresh()
end

driver:SetScript("OnEvent", function(_, event, unit)
    if event == "ADDON_LOADED" then
        if unit ~= ADDON then return end
        if type(TisteltiPlatesDB) ~= "table" then TisteltiPlatesDB = {} end
        db = TisteltiPlatesDB
        if db.enabled == nil then db.enabled = true end
        if db.group == nil then db.group = true end
        if db.raid == nil then db.raid = db.group end
        if db.guild == nil then db.guild = true end
        if type(db.playerColors) ~= "table" then db.playerColors = {} end
        for _, kind in ipairs({"ally", "enemy"}) do
            if type(db.playerColors[kind]) ~= "table" then db.playerColors[kind] = {} end
            local config = db.playerColors[kind]
            if type(config.name) ~= "boolean" then config.name = kind == "enemy" and db.hordeRedName ~= false end
            if type(config.border) ~= "boolean" then config.border = kind == "enemy" and db.hordeRedBorder ~= false end
            local default = kind == "enemy" and {1,.12,.12} or {.2,.65,1}
            for _, key in ipairs({"nameColor", "borderColor"}) do
                if type(config[key]) ~= "table" then config[key] = {} end
                for i=1,3 do
                    local v = config[key][i]
                    if type(v) ~= "number" or v ~= v or v < 0 or v > 1 then config[key][i] = default[i] end
                end
            end
        end
        if db.priority ~= "group" and db.priority ~= "guild" then db.priority = "guild" end
        if type(db.hideRightWingOnCC) ~= "boolean" then db.hideRightWingOnCC = true end
        if type(db.scale) ~= "number" or db.scale < .8 or db.scale > 1.8 then db.scale = 1 end
        if type(db.ranks) ~= "table" then db.ranks = {} end
        if type(db.appearance) ~= "table" then db.appearance = {} end
        if type(db.appearance.raid) ~= "table" then
            local group = type(db.appearance.group) == "table" and db.appearance.group or {}
            local rgb = type(group.color) == "table" and group.color or GOLD
            db.appearance.raid = {border=group.border, icon=group.icon, color={rgb[1], rgb[2], rgb[3]}}
        end
        for _, style in ipairs({"group", "raid", "guild"}) do
            if type(db.appearance[style]) ~= "table" then db.appearance[style] = {} end
            local config = db.appearance[style]
            local valid = {oroazul=true, oro=true, plata=true, clase=true, rango=true, color=true}
            if not valid[config.border or ""] and not metals[config.border] then config.border = style ~= "guild" and "oroazul" or "plata" end
            if not db.frameFixVersion and config.border == "oro" then config.border = "oroazul" end
            config.icon = "animales"
            local rgb = config.color
            if type(rgb) ~= "table" then rgb = {} end
            for i = 1, 3 do
                if type(rgb[i]) ~= "number" or rgb[i] < 0 or rgb[i] > 1 then rgb[i] = GOLD[i] end
            end
            config.color = rgb
        end
        db.compactIconDefault = true
        db.frameFixVersion = 1
        if TisteltiPlatesPvP then TisteltiPlatesPvP.Initialize(db) end
        RegisterOptions()
        if CompactUnitFrame_UpdateHealthColor then hooksecurefunc("CompactUnitFrame_UpdateHealthColor", Tint) end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        tracked[unit] = C_NamePlate.GetNamePlateForUnit(unit)
        if TisteltiPlatesCC.Attach then TisteltiPlatesCC.Attach(tracked[unit]) end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local plate = tracked[unit]
        if plate and plate.UnitFrame then
            if TisteltiPlatesCC.Release then TisteltiPlatesCC.Release(plate.UnitFrame) end
            Remove(plate.UnitFrame)
            if TisteltiPlatesPlayers then TisteltiPlatesPlayers.Remove(plate.UnitFrame) end
        end
        tracked[unit] = nil
    end
    Refresh()
end)
for _, event in ipairs({"ADDON_LOADED", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
    "GROUP_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_FACTION", "PLAYER_TARGET_CHANGED", "RAID_TARGET_UPDATE"}) do driver:RegisterEvent(event) end
local elapsed = 0
driver:SetScript("OnUpdate", function(_, dt)
    if InCombatLockdown() then
        elapsed = elapsed + dt
        if elapsed >= .35 then elapsed = 0; Refresh() end
        return
    end
    elapsed = elapsed + dt
    if elapsed >= .35 then elapsed = 0; Refresh() end
end)









