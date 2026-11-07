local secret = {}
issecretvalue = function(value) return value == secret end
local combat = false
InCombatLockdown = function() return combat end
local driver
CreateFrame = function()
    driver = {SetScript=function(self, event, callback) self[event]=callback end}
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
locked.HealthBarsContainer.hover=true
Hover.Track(locked,122,100)
near(locked.width,214)
locked.protected=true; combat=true
locked.HealthBarsContainer.hover=false; tick()
near(locked.width,214)
Hover.Release(locked)
near(locked.width,214)
combat=false; tick()
near(locked.width,100)

local fighting=Plate(180)
combat=true
Hover.Track(fighting,100,100)
fighting.HealthBarsContainer.hover=true; tick()
near(fighting.width,214)
fighting.HealthBarsContainer.hover=false; tick()
near(fighting.width,100)
Hover.Release(fighting); combat=false
print("PASS: protected combat frames wait; unprotected combat plates expand and restore")

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
