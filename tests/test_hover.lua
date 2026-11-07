local secret = {}
issecretvalue = function(value) return value == secret end
local combat = false
InCombatLockdown = function() return combat end
local driver
CreateFrame = function()
    driver = {RegisterEvent=function() end, SetScript=function(self, event, callback) self[event]=callback end}
    return driver
end
assert(loadfile("TisteltiPlates/HoverWidth.lua"))()
local Hover = TisteltiPlatesHover
local function tick() driver:OnUpdate(.05) end
local function near(a,b) assert(math.abs(a-b)<.01, tostring(a).." ~= "..tostring(b)) end

local function Plate(textWidth)
    local plate={unit="nameplate1", width=100, scale=1, writes=0, visible=true}
    function plate:IsForbidden() return self.forbidden or false end
    function plate:IsProtected() return self.protected or false end
    function plate:GetWidth() return self.width end
    function plate:GetEffectiveScale() return self.scale end
    function plate:SetWidth(width)
        assert(not self.forbidden and (not combat or not self.protected))
        assert(width==width and width<math.huge)
        self.width=width; self.writes=self.writes+1
    end
    local bar={hover=false}
    function bar:IsForbidden() return false end
    function bar:IsVisible() return plate.visible end
    function bar:IsMouseOver() return self.hover end
    plate.HealthBarsContainer=bar
    local name={textWidth=textWidth, padding=30, hover=false, scale=1}
    function name:IsForbidden() return self.forbidden or false end
    function name:IsVisible() return plate.visible end
    function name:IsMouseOver() return self.hover end
    function name:GetUnboundedStringWidth() return self.textWidth end
    function name:GetWidth() return (plate.width-self.padding)*plate.scale/self.scale end
    function name:GetEffectiveScale() return self.scale end
    plate.name=name
    return plate
end

local plate=Plate(180)
Hover.Track(plate,122,100)
near(plate.width,122)
plate.HealthBarsContainer.hover=true; tick()
near(plate.width,214)
assert(plate.name:GetWidth()>=plate.name.textWidth+4)
local writes=plate.writes
for i=1,20 do tick(); Hover.Track(plate,122,100) end
near(plate.width,214)
assert(plate.writes==writes, "Periodic decoration refresh must not cause oscillation or growth")
plate.HealthBarsContainer.hover=false; tick()
near(plate.width,122)
plate.name.hover=true; tick()
near(plate.width,214)
plate.name.textWidth=210; tick()
near(plate.width,244)
plate.name.padding=55; tick()
near(plate.width,269)
plate.visible=false; tick()
near(plate.width,122)
plate.visible=true
Hover.Release(plate)
near(plate.width,100)
tick(); near(plate.width,100)
print("PASS: full name fits, hover exit restores width, repeated refresh is stable, layout changes recalculate")

local short=Plate(50)
short.HealthBarsContainer.hover=true
Hover.Track(short,122,100)
near(short.width,122)
Hover.Release(short)

local scaled=Plate(180)
scaled.scale=2; scaled.name.scale=3
scaled.HealthBarsContainer.hover=true
Hover.Track(scaled,122,100)
near(scaled.width,306)
assert(scaled.name:GetWidth()>=184)
Hover.Release(scaled)

local fallback=Plate(180)
fallback.HealthBarsContainer.IsMouseOver=nil
fallback.name.IsMouseOver=nil
MouseIsOver=function(region) return region.hover end
fallback.HealthBarsContainer.hover=true
Hover.Track(fallback,122,100)
near(fallback.width,214)
Hover.Release(fallback)
MouseIsOver=nil
InputUtil={IsMouseOver=function(region) return region.hover end}
Hover.Track(fallback,122,100)
near(fallback.width,214)
Hover.Release(fallback)
InputUtil=nil
print("PASS: short names, independent text scaling and legacy/current hover APIs")

local locked=Plate(180)
locked.protected=true; locked.HealthBarsContainer.hover=true
Hover.Track(locked,122,100)
near(locked.width,122)
combat=true; tick(); near(locked.width,122)
Hover.Release(locked)
combat=false; tick(); near(locked.width,100)

local fighting=Plate(180)
Hover.Track(fighting,100,100)
fighting.HealthBarsContainer.hover=true; tick()
near(fighting.width,214)
combat=true; driver:OnEvent("PLAYER_REGEN_DISABLED")
near(fighting.width,100)
tick(); near(fighting.width,100)
combat=false; tick(); near(fighting.width,214)
fighting.HealthBarsContainer.hover=false; tick(); near(fighting.width,100)
Hover.Release(fighting)
print("PASS: entering combat immediately restores width; no expansion in combat or on protected plates")

local recycled=Plate(180)
recycled.HealthBarsContainer.hover=true
Hover.Track(recycled,122,100)
recycled.unit="nameplate2"; tick()
near(recycled.width,100)
Hover.Track(recycled,122,100)
near(recycled.width,214)
recycled.unit=nil; tick()
near(recycled.width,100)

local hidden=Plate(180)
hidden.HealthBarsContainer.hover=true
Hover.Track(hidden,122,100)
hidden.name.textWidth=secret; tick()
near(hidden.width,122)
hidden.name.textWidth=180; hidden.name.forbidden=true; tick()
near(hidden.width,122)
hidden.name.forbidden=false; hidden.name.textWidth=0/0; tick()
near(hidden.width,122)
hidden.name.textWidth=math.huge; tick()
near(hidden.width,122)
Hover.Release(hidden)
Hover.Track(hidden,secret,100)
near(hidden.width,100)
print("PASS: recycled/removed units, secret or forbidden metrics and invalid widths")

-- Simulate Blizzard's opposing anchors: SetWidth alone cannot change the width.
local anchored=Plate(180)
local parent={}
anchored.points={{"TOPLEFT",parent,"TOPLEFT",0,-2},{"BOTTOMRIGHT",parent,"BOTTOMRIGHT",0,3}}
function anchored:GetNumPoints() return #self.points end
function anchored:GetPoint(i) return table.unpack(self.points[i]) end
function anchored:SetPoint(point, relative, relativePoint, x, y)
    for i, old in ipairs(self.points) do
        if old[1]==point then self.points[i]={point,relative,relativePoint,x,y} end
    end
    self.width=100+self.points[2][4]-self.points[1][4]
end
function anchored:SetWidth() end
anchored.HealthBarsContainer.hover=true
Hover.Track(anchored,122,100)
near(anchored.width,214)
near(anchored.points[1][4],-57); near(anchored.points[2][4],57)
assert(anchored.points[1][5]==-2 and anchored.points[2][5]==3, "Vertical offsets must never change")
for i=1,20 do tick(); Hover.Track(anchored,122,100) end
near(anchored.width,214)
anchored.HealthBarsContainer.hover=false; tick(); near(anchored.width,122)
Hover.Release(anchored); near(anchored.width,100)
assert(anchored.points[1][4]==0 and anchored.points[2][4]==0)
print("PASS: opposing native anchors widen horizontally, retain height and restore exactly")

local native=Plate(180)
native.name.GetEffectiveScale=nil
native.name.GetParent=function() return native end
UnitIsUnit=function(unit,other) return unit==native.unit and other=="mouseover" end
Hover.Track(native,100,100)
near(native.width,214)
UnitIsUnit=function() return false end
tick(); near(native.width,100)
Hover.Release(native)
print("PASS: mouseover unit detects native plates without mouse events; font scale falls back to parent")

-- Exercise Core's real refresh/event paths; decoration settings must not filter hover.
local hoverDriver=driver
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
UnitIsPlayer=function(unit) return unit~="npc" end
UnitIsFriend=function(_,unit) return unit~="enemy" end
UnitInParty=function(unit) return unit=="party" end
UnitIsInMyGuild=function(unit) return unit=="guild" end
local plates={}
C_NamePlate={GetNamePlateForUnit=function(unit) return plates[unit] end}
for _,unit in ipairs({"party","guild","stranger","enemy","npc"}) do
    local uf=Plate(180); uf.unit=unit; uf.HealthBarsContainer.hover=true
    plates[unit]={UnitFrame=uf}
    core.driver:OnEvent("NAME_PLATE_UNIT_ADDED",unit)
    near(uf.width,unit=="npc" and 100 or 214)
end
for i=1,10 do core.refresh(); hoverDriver:OnUpdate(.05) end
for unit,plate in pairs(plates) do near(plate.UnitFrame.width,unit=="npc" and 100 or 214) end
instance=true; core.refresh(); near(plates.enemy.UnitFrame.width,214)
combat=true; core.refresh(); hoverDriver:OnEvent("PLAYER_REGEN_DISABLED")
for _,plate in pairs(plates) do near(plate.UnitFrame.width,100) end
combat=false; core.refresh(); near(plates.enemy.UnitFrame.width,214)
config.enabled=false; core.refresh()
for _,plate in pairs(plates) do near(plate.UnitFrame.width,100) end
config.enabled=true; core.refresh()
core.driver:OnEvent("NAME_PLATE_UNIT_REMOVED","enemy")
near(plates.enemy.UnitFrame.width,100)
hoverDriver:OnUpdate(.05); near(plates.enemy.UnitFrame.width,100)
for unit in pairs(plates) do core.driver:OnEvent("NAME_PLATE_UNIT_REMOVED",unit) end
print("PASS: real Core enrollment covers party, guild, strangers and enemies; excludes NPCs; handles instances, disable and removal")
