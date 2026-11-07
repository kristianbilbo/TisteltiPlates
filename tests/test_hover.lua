-- Regression model of Forever's native hierarchy, based on:
-- Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlateUnitFrame.lua
-- The engine-owned base rejects addon anchors; the name/bar are child regions.
unpack = unpack or table.unpack
local secret = {}
issecretvalue = function(value) return value == secret end
local combat, mouseUnit = false, nil
InCombatLockdown = function() return combat end
UnitIsUnit = function(unit, other) return other == "mouseover" and unit == mouseUnit end
UnitIsPlayer = function(unit) return unit ~= "npc" end
NamePlateConstants = {NAME_ANCHOR_STYLES={InsideHealthBar=1}}
NamePlateSetupOptions = {castBarToHealthBarSpacing=2,unitNameAnchorStyle=1}
UIParent = {}
local drivers = {}
CreateFrame = function()
    local driver = {SetScript=function(self, event, callback) self[event]=callback end, RegisterEvent=function() end, Hide=function() end}
    function driver:CreateFontString()
        local text = {}
        function text:SetWordWrap() end
        function text:SetFontObject(font) self.font=font end
        function text:SetFontHeight(height) self.height=height end
        function text:SetTextScale(scale) self.scale=scale end
        function text:SetText(value) assert(value ~= secret); self.text=value end
        function text:GetUnboundedStringWidth() return #self.text*self.height/2*self.scale end
        return text
    end
    drivers[#drivers+1]=driver
    return driver
end
hooksecurefunc = function(object, method, hook)
    local old=object[method]
    object[method]=function(self, ...) old(self, ...); hook(self, ...) end
end
assert(loadfile("TisteltiPlates/HoverWidth.lua"))()
local Hover, driver = TisteltiPlatesHover, drivers[1]
local function tick() driver:OnUpdate(.25) end
local function near(a,b) assert(math.abs(a-b)<.01, tostring(a).." ~= "..tostring(b)) end
local function Plate(textWidth)
    local uf={unit="nameplate1",width=160,scale=1,visible=true,levelGap=24,height=48}
    function uf:IsForbidden() return self.forbidden or false end
    function uf:IsProtected() return false end
    function uf:GetWidth() return self.width end
    function uf:GetEffectiveScale() return self.scale end
    -- SetAllPoints on the native root makes explicit SetWidth ineffective.
    function uf:SetWidth() end
    function uf:SetPoint() error("SetPoint would result in anchor family connection") end
    function uf:GetPoint() error("Can't measure restricted regions") end
    function uf:GetNumPoints() return 2 end
    local cast={}
    function cast:GetWidth() return uf.width-16 end
    uf.CastBarsContainer=cast
    local bar={hover=false,points={},height=18,writes=0}
    function bar:IsForbidden() return self.forbidden or false end
    function bar:IsProtected() return self.protected or false end
    function bar:IsVisible() return uf.visible end
    function bar:IsMouseOver() return self.hover end
    function bar:GetEffectiveScale() return uf.scale end
    function bar:GetWidth() return cast:GetWidth()+self.points[2][4]-self.points[1][4] end
    function bar:GetNumPoints() return 2 end
    function bar:GetPoint(i)
        if self.restrictedPoints then error("Can't measure restricted regions") end
        return unpack(self.points[i])
    end
    function bar:SetPoint(point, relative, relativePoint, x, y)
        assert(not self.forbidden and (not combat or not self.protected))
        assert(relative==cast, "Must not anchor to the engine-owned NamePlate root")
        assert(x==x and math.abs(x)<math.huge)
        if self.failRight and point=="BOTTOMRIGHT" then error("Anchor unavailable") end
        local index=point=="BOTTOMLEFT" and 1 or 2
        self.points[index]={point,relative,relativePoint,x,y}
        self.writes=self.writes+1
    end
    uf.HealthBarsContainer=bar
    bar.healthBar={}
    for _,key in ipairs({"Text","RightText","LeftText"}) do
        local label={width=key=="Text" and 30 or 0}
        function label:GetUnboundedStringWidth() return self.width end
        function label:GetParent() return uf end
        bar.healthBar[key]=label
    end
    local name={textWidth=textWidth,padding=40,hover=false,scale=1}
    function name:IsForbidden() return self.forbidden or false end
    function name:IsVisible() return uf.visible end
    function name:IsMouseOver() return self.hover end
    function name:GetUnboundedStringWidth() return self.secretGeometry and secret or self.textWidth end
    function name:GetWidth() return self.secretGeometry and secret or (bar:GetWidth()-self.padding)*uf.scale/self.scale end
    function name:GetParent() return uf end -- FontString has no GetEffectiveScale in this model.
    function name:GetText() return self.secretText and secret or string.rep("A",self.textWidth/8) end
    function name:GetFontObject() return "SystemFont_NamePlate" end
    function name:GetFontHeight() return 16 end
    function name:GetTextScale() return 1 end
    uf.name=name
    function uf:UpdateAnchors()
        bar.points={{"BOTTOMLEFT",cast,"TOPLEFT",0,2},{"BOTTOMRIGHT",cast,"TOPRIGHT",-self.levelGap,2}}
    end
    uf:UpdateAnchors()
    return uf
end

local p=Plate(180)
Hover.TrackPlayer(p); tick()
near(p.HealthBarsContainer:GetWidth(),120)
p.HealthBarsContainer.hover=true; tick()
near(p.HealthBarsContainer:GetWidth(),224)
near(p.name:GetWidth(),184)
near(p:GetWidth(),160)
assert(p.height==48 and p.HealthBarsContainer.height==18)
assert(p.HealthBarsContainer.points[1][5]==2 and p.HealthBarsContainer.points[2][5]==2)
local writes=p.HealthBarsContainer.writes
for i=1,20 do Hover.TrackPlayer(p); tick() end
assert(p.HealthBarsContainer.writes==writes, "Repeated refresh must not oscillate or grow")
p.HealthBarsContainer.hover=false; tick(); near(p.HealthBarsContainer:GetWidth(),120)
p.name.hover=true; tick(); near(p.HealthBarsContainer:GetWidth(),224)
p.visible=false; tick(); near(p.HealthBarsContainer:GetWidth(),120)
p.visible=true; tick(); near(p.HealthBarsContainer:GetWidth(),224)
Hover.Release(p); near(p.HealthBarsContainer:GetWidth(),120)
print("PASS: native root untouched; visible name/bar fit; only horizontal offsets change; hover exit and hidden plates restore")

local short=Plate(50)
short.HealthBarsContainer.hover=true
Hover.TrackPlayer(short); tick(); near(short.HealthBarsContainer:GetWidth(),120)
Hover.Release(short)
local scaled=Plate(180)
scaled.scale=2; scaled.name.scale=3
scaled.name.GetEffectiveScale=function(self) return self.scale end
scaled.HealthBarsContainer.hover=true
Hover.TrackPlayer(scaled); tick(); near(scaled.HealthBarsContainer:GetWidth(),316)
near(scaled.name:GetWidth(),184)
Hover.Release(scaled)
print("PASS: short names do not expand; independent font/plate scaling fits the full name")

local reset=Plate(180)
reset.HealthBarsContainer.hover=true
Hover.Track(reset,195.2,160) -- Decorated baseline still uses Core's original width API.; tick()
for i=1,10 do Hover.Track(reset,195.2,160); tick() end
near(reset.HealthBarsContainer:GetWidth(),224)
reset.levelGap=40; reset:UpdateAnchors(); tick()
near(reset.HealthBarsContainer:GetWidth(),224)
reset.HealthBarsContainer.hover=false; tick()
near(reset.HealthBarsContainer:GetWidth(),104)
reset.width=200; reset:UpdateAnchors()
near(reset.HealthBarsContainer:GetWidth(),144)
reset.HealthBarsContainer.hover=true; tick()
near(reset.HealthBarsContainer:GetWidth(),224)
Hover.Release(reset); near(reset.HealthBarsContainer:GetWidth(),144)
print("PASS: native layout resets, level-badge changes and UI resizing preserve the latest baseline")

local fallback=Plate(184)
fallback.HealthBarsContainer.restrictedPoints=true
fallback.name.secretGeometry=true
mouseUnit=fallback.unit
Hover.TrackPlayer(fallback); tick()
near(fallback.HealthBarsContainer:GetWidth(),228)
local writesBefore=fallback.HealthBarsContainer.writes
for i=1,10 do tick() end
assert(fallback.HealthBarsContainer.writes==writesBefore)
fallback.name.secretText=true; tick(); near(fallback.HealthBarsContainer:GetWidth(),120)
fallback.name.secretText=false; tick(); near(fallback.HealthBarsContainer:GetWidth(),228)
mouseUnit=nil; tick(); near(fallback.HealthBarsContainer:GetWidth(),120)
Hover.Release(fallback)
print("PASS: restricted native anchors and secret text geometry use public child layout and unanchored public text measurement")

local shortSecret=Plate(48)
shortSecret.name.secretGeometry=true
shortSecret.HealthBarsContainer.hover=true
Hover.TrackPlayer(shortSecret); tick()
near(shortSecret.HealthBarsContainer:GetWidth(),120)
shortSecret.name.textWidth=96; tick()
near(shortSecret.HealthBarsContainer:GetWidth(),140)
shortSecret.name.textWidth=184; tick()
near(shortSecret.HealthBarsContainer:GetWidth(),228)
-- A wider health label must reserve just its extra width, not duplicate the name.
shortSecret.HealthBarsContainer.healthBar.Text.width=46; tick()
near(shortSecret.HealthBarsContainer:GetWidth(),244)
shortSecret.HealthBarsContainer.healthBar.Text.width=secret; tick()
near(shortSecret.HealthBarsContainer:GetWidth(),120)
Hover.Release(shortSecret)
print("PASS: restricted name geometry leaves short names unchanged; medium/long names and health labels produce proportional widths")

-- Blizzard's TextStatusBar clears the two unused labels. Their geometry may
-- still be secret because they anchor to the populated health label. Empty
-- GetText results must not be confused with failed/secret text reads.
local emptyLabels=Plate(184)
emptyLabels.name.secretGeometry=true
emptyLabels.HealthBarsContainer.hover=true
for _,key in ipairs({"RightText","LeftText"}) do
    local label=emptyLabels.HealthBarsContainer.healthBar[key]
    label.width=secret
    label.GetText=function() return nil end
    label.GetParent=function() return nil end -- zero text needs no scale/font
end
Hover.TrackPlayer(emptyLabels)
driver:OnUpdate(.03)
assert(emptyLabels.HealthBarsContainer:GetWidth()>120,"Empty health labels must not cancel the animation")
for i=1,20 do driver:OnUpdate(.01) end
near(emptyLabels.HealthBarsContainer:GetWidth(),228)
local empty=emptyLabels.HealthBarsContainer.healthBar.LeftText
empty.GetText=function() return "" end
tick(); near(emptyLabels.HealthBarsContainer:GetWidth(),228)
empty.GetText=function() return secret end
tick(); near(emptyLabels.HealthBarsContainer:GetWidth(),120)
empty.GetText=function() error("restricted") end
tick(); near(emptyLabels.HealthBarsContainer:GetWidth(),120)
empty.GetText=nil
tick(); near(emptyLabels.HealthBarsContainer:GetWidth(),120)
Hover.Release(emptyLabels)
print("PASS: empty anchored health labels allow fitting/animation; secret, failed and missing reads do not become zero")

local animated=Plate(180)
animated.HealthBarsContainer.hover=true
Hover.TrackPlayer(animated)
near(animated.HealthBarsContainer:GetWidth(),120)
driver:OnUpdate(.03)
local halfway=animated.HealthBarsContainer:GetWidth()
assert(halfway>120 and halfway<224,"Hover must animate, not jump to the final width")
local beforeRefresh=halfway
Hover.TrackPlayer(animated)
near(animated.HealthBarsContainer:GetWidth(),beforeRefresh)
-- Reverse before expansion finishes without snapping to either endpoint.
animated.HealthBarsContainer.hover=false; driver:OnEvent("UPDATE_MOUSEOVER_UNIT")
near(animated.HealthBarsContainer:GetWidth(),halfway)
driver:OnUpdate(.03)
assert(animated.HealthBarsContainer:GetWidth()<halfway and animated.HealthBarsContainer:GetWidth()>120)
for i=1,15 do driver:OnUpdate(.01) end
near(animated.HealthBarsContainer:GetWidth(),120)
animated.HealthBarsContainer.hover=true; driver:OnEvent("UPDATE_MOUSEOVER_UNIT")
for i=1,18 do driver:OnUpdate(.01) end
near(animated.HealthBarsContainer:GetWidth(),224)
-- Combat interrupts the animation and restores immediately, as requested.
combat=true; driver:OnEvent("PLAYER_REGEN_DISABLED")
near(animated.HealthBarsContainer:GetWidth(),120)
combat=false; Hover.Release(animated)
print("PASS: smooth frame-by-frame expansion/retraction, reversal without jumps, stable refresh and instant combat restoration")

local secretSize=Plate(184)
secretSize.GetWidth=function() return secret end
secretSize.HealthBarsContainer.GetWidth=function() return secret end
secretSize.name.secretGeometry=true
secretSize.HealthBarsContainer.hover=true
Hover.TrackPlayer(secretSize); tick()
near(secretSize.HealthBarsContainer.points[1][4],0)
near(secretSize.HealthBarsContainer.points[2][4],-24)
Hover.Release(secretSize)
near(secretSize.HealthBarsContainer.points[1][4],0)
near(secretSize.HealthBarsContainer.points[2][4],-24)
print("PASS: fully unreadable allocation leaves width unchanged instead of guessing an expansion")

local fighting=Plate(180)
fighting.HealthBarsContainer.hover=true
Hover.TrackPlayer(fighting); tick(); near(fighting.HealthBarsContainer:GetWidth(),224)
combat=true; driver:OnEvent("PLAYER_REGEN_DISABLED")
near(fighting.HealthBarsContainer:GetWidth(),120)
for i=1,10 do tick(); Hover.TrackPlayer(fighting) end
near(fighting.HealthBarsContainer:GetWidth(),120)
combat=false; driver:OnEvent("PLAYER_REGEN_ENABLED"); tick()
near(fighting.HealthBarsContainer:GetWidth(),224)
Hover.Release(fighting)
local protected=Plate(180)
protected.HealthBarsContainer.protected=true; protected.HealthBarsContainer.hover=true
Hover.TrackPlayer(protected); tick(); near(protected.HealthBarsContainer:GetWidth(),120)
combat=true; tick(); near(protected.HealthBarsContainer:GetWidth(),120)
Hover.Release(protected); combat=false; tick()
print("PASS: combat entry restores immediately, no combat expansion, protected visual frames never expand")

local recycled=Plate(180)
recycled.HealthBarsContainer.hover=true
Hover.TrackPlayer(recycled); tick()
recycled.unit="npc"; Hover.TrackPlayer(recycled)
near(recycled.HealthBarsContainer:GetWidth(),120)
recycled.unit="nameplate2"; Hover.TrackPlayer(recycled); tick()
near(recycled.HealthBarsContainer:GetWidth(),224)
recycled.unit=nil; tick(); near(recycled.HealthBarsContainer:GetWidth(),120)
local invalid=Plate(0/0)
invalid.HealthBarsContainer.hover=true
invalid.name.GetText=function() return nil end
Hover.TrackPlayer(invalid); tick(); near(invalid.HealthBarsContainer:GetWidth(),120)
invalid.name.textWidth=math.huge; tick(); near(invalid.HealthBarsContainer:GetWidth(),120)
Hover.Release(invalid)
print("PASS: reused player/NPC plates, removed units, unreadable names and invalid measurements stay safe")

local partial=Plate(180)
partial.HealthBarsContainer.hover=true; partial.HealthBarsContainer.failRight=true
Hover.TrackPlayer(partial); tick()
partial.HealthBarsContainer.failRight=false
Hover.Release(partial)
near(partial.HealthBarsContainer:GetWidth(),120)
print("PASS: failed second anchor restores partial changes")

-- Test enrollment through Core's real events and all refresh return paths.
SlashCmdList={}
local f=assert(io.open("TisteltiPlates/Core.lua","rb"))
local source=f:read("*a"); f:close()
local core=assert(load(source .. [[
return {refresh=Refresh, driver=driver, setDB=function(value) db=value end}
]]))("TisteltiPlates")
local config={enabled=true,group=false,guild=false}
core.setDB(config)
local instance=false
IsInInstance=function() return instance end
UnitIsFriend=function(_,unit) return unit~="enemy" end
UnitInParty=function(unit) return unit=="party" end
UnitIsInMyGuild=function(unit) return unit=="guild" end
local plates={}
C_NamePlate={GetNamePlateForUnit=function(unit) return plates[unit] end}
for _,unit in ipairs({"party","guild","stranger","enemy","npc"}) do
    local uf=Plate(180); uf.unit=unit; uf.HealthBarsContainer.hover=true
    plates[unit]={UnitFrame=uf}
    core.driver:OnEvent("NAME_PLATE_UNIT_ADDED",unit); tick()
    near(uf.HealthBarsContainer:GetWidth(),unit=="npc" and 120 or 224)
end
for i=1,10 do core.refresh(); tick() end
for unit,plate in pairs(plates) do near(plate.UnitFrame.HealthBarsContainer:GetWidth(),unit=="npc" and 120 or 224) end
instance=true; core.refresh(); near(plates.enemy.UnitFrame.HealthBarsContainer:GetWidth(),224)
combat=true; core.refresh(); driver:OnEvent("PLAYER_REGEN_DISABLED")
for _,plate in pairs(plates) do near(plate.UnitFrame.HealthBarsContainer:GetWidth(),120) end
combat=false; core.refresh(); tick(); near(plates.enemy.UnitFrame.HealthBarsContainer:GetWidth(),224)
config.enabled=false; core.refresh()
for _,plate in pairs(plates) do near(plate.UnitFrame.HealthBarsContainer:GetWidth(),120) end
config.enabled=true; core.refresh()
core.driver:OnEvent("NAME_PLATE_UNIT_REMOVED","enemy")
near(plates.enemy.UnitFrame.HealthBarsContainer:GetWidth(),120)
tick(); near(plates.enemy.UnitFrame.HealthBarsContainer:GetWidth(),120)
for unit in pairs(plates) do core.driver:OnEvent("NAME_PLATE_UNIT_REMOVED",unit) end
print("PASS: all player types enrolled; NPCs excluded; instances, disable and removal restore native geometry")
