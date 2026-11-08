unpack = unpack or table.unpack
local loadChunk = loadstring or load
local combat, secret = false, {}
issecretvalue = function(value) return value == secret end
InCombatLockdown = function() return combat end
local frames = {}
local function Frame(parent)
    local f = {parent=parent, shown=true, alpha=1, level=2, scripts={}, children={}, points={}}
    if parent then table.insert(parent.children, f) end
    function f:IsForbidden() return self.forbidden or false end
    function f:IsProtected() return self.protected or false end
    function f:IsVisible()
        if self.secretVisibility then return secret end
        return self.shown and (not self.parent or self.parent:IsVisible())
    end
    function f:IsShown() return self.shown end
    function f:GetEffectiveAlpha() return self.alpha * (self.parent and self.parent:GetEffectiveAlpha() or 1) end
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(a) self.alpha=a end
    function f:GetParent() return self.parent end
    function f:GetChildren() return unpack(self.children) end
    function f:GetFrameLevel() return self.level end
    function f:SetFrameLevel(n) self.level=n end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i) return unpack(self.points[i]) end
    function f:ClearAllPoints() assert(not combat or not self:IsProtected()); self.points={} end
    function f:SetPoint(...) assert(not combat or not self:IsProtected()); self.points={ {...} } end
    function f:SetScript(event, callback) self.scripts[event]=callback end
    function f:RegisterEvent() end
    function f:SetShown(show)
        if self.shown == show then return end
        self.shown=show
        local fn=self.scripts[show and "OnShow" or "OnHide"]
        if fn then fn(self) end
    end
    function f:Show() self:SetShown(true) end
    function f:Hide() self:SetShown(false) end
    function f:SetScale() end
    function f:SetWidth() end
    function f:SetStatusBarColor() end
    function f:UpdateAnchors() end
    frames[#frames+1]=f
    return f
end
CreateFrame = function() return Frame() end
hooksecurefunc = function(frame, method, callback)
    local old=frame[method]
    frame[method]=function(self, ...) old(self,...); callback(self,...) end
end
SlashCmdList={}
local plate={UnitFrame=Frame()}
local uf=plate.UnitFrame
uf.unit="nameplate1"
uf.HealthBarsContainer=Frame(uf)
uf.PlayerLevelDiffFrame=Frame(uf)
uf.AurasFrame=Frame(uf)
local auras=uf.AurasFrame
auras.LossOfControlFrame=Frame(auras)
auras.CrowdControlListFrame=Frame(auras)
local loss=auras.LossOfControlFrame
local crowd=auras.CrowdControlListFrame
loss:SetPoint('BOTTOM',uf.HealthBarsContainer,'TOP',0,4)
crowd:SetPoint('BOTTOM',uf.HealthBarsContainer,'TOP',0,5)
loss.AuraItemFrame=Frame(loss)
loss.AuraItemFrame:Hide()
local crowdIcon=Frame(crowd)
crowdIcon.Icon={}; crowdIcon.Cooldown={}; crowdIcon:Hide()
C_NamePlate={GetNamePlateForUnit=function() return plate end, GetNamePlates=function() return {plate} end}
assert(loadfile("TisteltiPlates/CCPosition.lua"))()
local CC=TisteltiPlatesCC
local events=frames[#frames]
local function tick(art) art.scripts.OnUpdate(art,.05) end
local function artFor(key)
    local art=Frame(uf)
    art.badge=Frame(art)
    art.ccAnchor=Frame(art)
    art.badge.level=20
    art.rightWing=Frame(art); art.rightWingLight=Frame(art); art.wings=Frame(art)
    art:Hide()
    uf[key]=art
    CC.AttachArt(art,uf)
    art:Show()
    return art
end
local art=artFor("TisteltiArt")
assert(loss.points[1][2]==art.badge and loss.points[1][4]==8)
assert(art.rightWing.shown and art.rightWingLight.shown, "Empty visible container must not hide wing")
loss.AuraItemFrame:Show(); tick(art)
assert(not art.rightWing.shown and not art.rightWingLight.shown and art.wings.shown)
TisteltiPlatesDB={hideRightWingOnCC=false}
tick(art)
assert(art.rightWing.shown and art.rightWingLight.shown, "Opt-out restores both textures while CC remains active")
assert(loss.points[1][2]==art.badge, "Opt-out must not change control positioning")
TisteltiPlatesDB.hideRightWingOnCC=true; tick(art)
assert(not art.rightWing.shown and not art.rightWingLight.shown)
loss.AuraItemFrame:Hide(); tick(art)
assert(art.rightWing.shown and art.rightWingLight.shown)
crowdIcon:Show(); tick(art)
assert(not art.rightWing.shown)
crowd:Hide(); tick(art)
assert(art.rightWing.shown, "Hidden parent must not count")
crowd:Show(); crowd.alpha=0; tick(art)
assert(art.rightWing.shown, "Transparent native controls must not count")
crowd.alpha=1; auras:Hide(); tick(art)
assert(art.rightWing.shown)
auras:Show(); crowdIcon:Hide()
loss.AuraItemFrame:Show(); loss.AuraItemFrame.forbidden=true; tick(art)
assert(art.rightWing.shown, "Forbidden frames must not be queried")
loss.AuraItemFrame.forbidden=false; loss.AuraItemFrame.secretVisibility=true; tick(art)
assert(art.rightWing.shown, "Secret visibility must not be branched on")
loss.AuraItemFrame.secretVisibility=false
combat=true; tick(art)
assert(not art.rightWing.shown, "Wing must react in combat")
loss.protected=true; crowd.protected=true
CC.Position(uf)
loss.AuraItemFrame:Hide(); tick(art)
assert(art.rightWing.shown)
art:Hide()
local combatArt=artFor("TisteltiCombatArt")
loss.AuraItemFrame:Show(); tick(combatArt)
assert(not combatArt.rightWing.shown and not combatArt.rightWingLight.shown)
TisteltiPlatesDB.hideRightWingOnCC=false; tick(combatArt)
assert(combatArt.rightWing.shown and combatArt.rightWingLight.shown, "Preference must also apply in combat")
TisteltiPlatesDB.hideRightWingOnCC=true; tick(combatArt)
assert(not combatArt.rightWing.shown and not combatArt.rightWingLight.shown)
loss.protected=false; crowd.protected=false
CC.Position(uf)
assert(loss.points[1][2]==combatArt.badge, "Unprotected controls can move during combat")
combat=false
events.scripts.OnEvent(events,"PLAYER_REGEN_ENABLED")
assert(loss.points[1][2]==combatArt.badge)
combatArt:Hide()
assert(loss.points[1][2]==uf.HealthBarsContainer and loss.points[1][5]==4 and loss.level==2)
uf.PlayerLevelDiffFrame.alpha=0
CC.Position(uf)
assert(loss.points[1][2]==uf.HealthBarsContainer)
uf.PlayerLevelDiffFrame.alpha=1
events.scripts.OnEvent(events,"NAME_PLATE_UNIT_ADDED","nameplate1")
uf:UpdateAnchors()
assert(loss.points[1][2]==uf.HealthBarsContainer and loss.points[1][5]==4, "Undecorated plates keep native positioning")
local preview=Frame(); preview.rightWing=Frame(preview); preview.rightWingLight=Frame(preview)
CC.AttachArt(preview, Frame())
assert(not preview.scripts.OnUpdate)
loss.AuraItemFrame:Hide(); art:Show()
assert(art.rightWing.shown, "Reused decoration restores wing")
print("PASS: icon visibility, glow, empty containers, parents, combat, reuse, previews and positioning")

-- Exercise the actual Core layout so it cannot move CC back above the plate.
assert(loadfile("TisteltiPlates/HoverWidth.lua"))()
local f=assert(io.open("TisteltiPlates/Core.lua","rb"))
local source=f:read("*a"); f:close()
local core=assert(loadChunk(source .. [[
return {layout=Layout, remove=Remove, active=active, driver=driver, options=RegisterOptions,
    setDB=function(value) db=value end}
]]))("TisteltiPlates")
core.setDB({enabled=true,scale=1})
IsInInstance=function() return false end
local buff=Frame(auras)
auras.BuffListFrame=buff
buff:SetPoint('BOTTOM',uf.HealthBarsContainer,'TOP',0,3)
local state={art=art,levels={},cc={
    {frame=buff,row=0}, {frame=loss,row=2},
}}
art.ccAnchor=Frame(art)
core.layout(state)
assert(buff.points[1][1]=="BOTTOMLEFT" and buff.points[1][2]==art.ccAnchor)
assert(loss.points[1][1]=="LEFT" and loss.points[1][2]==art.badge)
uf:UpdateAnchors()
core.layout(state)
assert(loss.points[1][2]==art.badge)
print("PASS: Tistelti layout keeps buffs above and controls beside the badge")

-- The existing nil-unit fix remains intact after integration.
core.active[uf]={art=art,levels={},cc={},bar=Frame(),originalColor={1,1,1}}
uf.unit=nil
CompactUnitFrame_UpdateHealthColor=function() error("Native color update on missing unit") end
core.remove(uf)
assert(core.active[uf]==nil)
print("PASS: removed plates without a unit still clean up safely")

-- Initialization must retain an explicit opt-out across reloads.
CompactUnitFrame_UpdateHealthColor=nil
TisteltiPlatesDB={}
core.driver.scripts.OnEvent(core.driver,"ADDON_LOADED","TisteltiPlates")
assert(TisteltiPlatesDB.hideRightWingOnCC==true)
TisteltiPlatesDB.hideRightWingOnCC=false
core.driver.scripts.OnEvent(core.driver,"ADDON_LOADED","TisteltiPlates")
assert(TisteltiPlatesDB.hideRightWingOnCC==false)
print("PASS: wing preference defaults on, toggles live and persists when disabled")

-- Build the real options panel and exercise the checkbox's actual callbacks.
local checkbox
local function UIFrame(parent)
    local frame=Frame(parent)
    frame.CreateTexture=function(self) return UIFrame(self) end
    frame.CreateFontString=function(self) return UIFrame(self) end
    frame.SetText=function(self,text) self.text=text end
    frame.SetChecked=function(self,value) self.checked=value end
    frame.GetChecked=function(self) return self.checked end
    return setmetatable(frame,{__index=function(_,key)
        if key:match("^Set") or key:match("^Enable") then return function() end end
    end})
end
CreateFrame=function(kind,_,parent)
    local frame=UIFrame(parent)
    if kind=="CheckButton" then checkbox=frame end
    return frame
end
RAID_CLASS_COLORS={MAGE={r=0.2,g=0.6,b=1}}
Settings={RegisterCanvasLayoutCategory=function(panel) return panel end, RegisterAddOnCategory=function() end}
core.options()
assert(checkbox and checkbox.checked==false, "Options must reflect the saved opt-out")
checkbox:SetChecked(true); checkbox.scripts.OnClick(checkbox)
assert(TisteltiPlatesDB.hideRightWingOnCC==true)
loss.AuraItemFrame:Show(); art:Show(); tick(art)
assert(not art.rightWing.shown and not art.rightWingLight.shown)
checkbox:SetChecked(false); checkbox.scripts.OnClick(checkbox); tick(art)
assert(TisteltiPlatesDB.hideRightWingOnCC==false and art.rightWing.shown and art.rightWingLight.shown)
checkbox:SetChecked(true); checkbox.scripts.OnShow(checkbox)
assert(checkbox.checked==false, "Reopening must resync the saved preference")
print("PASS: config checkbox changes live wings and reflects the saved preference")

local message
local oldPrint=print
print=function(text) message=text end
C_CVar={GetCVarBitfield=function(name,index)
    assert(name=="nameplateFriendlyPlayerAuraDisplay" and index==3)
    return true
end,GetCVarBool=function() return true end}
CC.Report()
assert(message:find("control/stuns en amigos: activado",1,true))
C_CVar.GetCVarBitfield=function() return false end
CC.Report()
assert(message:find("control/stuns en amigos: desactivado",1,true))
print=oldPrint
print("PASS: /tistelti cc reports settings without changing them")

-- Switching to compact PvP must restore the real native points, not the
-- positioner's temporary right-of-badge anchor. Protected lists defer safely.
local compact=false
TisteltiPlatesPvP={IsActive=function() return compact end}
local fresh=Frame()
fresh.HealthBarsContainer=Frame(fresh)
fresh.AurasFrame=Frame(fresh)
local native=Frame(fresh.AurasFrame)
fresh.AurasFrame.LossOfControlFrame=native
native:SetPoint('BOTTOM',fresh.HealthBarsContainer,'TOP',0,4)
local nativeLevel=native:GetFrameLevel()
local freshArt=Frame(fresh)
freshArt.badge=Frame(freshArt); freshArt.ccAnchor=Frame(freshArt)
fresh.TisteltiArt=freshArt
CC.Position(fresh)
assert(native.points[1][1]=='LEFT')
local saved=CC.OriginalPlacement(native)
assert(saved[1][1]=='BOTTOM' and saved[1][5]==4)
compact=true; combat=true; native.protected=true
CC.Position(fresh); assert(native.points[1][1]=='LEFT')
combat=false; CC.Position(fresh)
assert(native.points[1][1]=='BOTTOM' and native.points[1][5]==4 and native:GetFrameLevel()==nativeLevel)
print('PASS: compact PvP restores native CC anchors and defers protected changes in combat')

-- Real-client regression: IsForbidden=false is not enough. Native controls
-- can forbid FrameMeasurement and throw from GetPoint thousands of times.
compact=false
local restrictedUF=Frame()
restrictedUF.HealthBarsContainer=Frame(restrictedUF)
restrictedUF.AurasFrame=Frame(restrictedUF)
local restricted=Frame(restrictedUF.AurasFrame)
restrictedUF.AurasFrame.LossOfControlFrame=restricted
restrictedUF.TisteltiArt=Frame(restrictedUF)
restrictedUF.TisteltiArt.badge=Frame(restrictedUF.TisteltiArt)
restricted:SetPoint('BOTTOM',restrictedUF.HealthBarsContainer,'TOP',0,4)
local original=restricted.points[1]
local measurements,mutations=0,0
restricted.HasAnyForbiddenAspects=function() return true end
restricted.GetPoint=function() measurements=measurements+1 error("Can't measure restricted regions") end
restricted.ClearAllPoints=function() mutations=mutations+1 error('Restricted anchor mutation') end
for i=1,1000 do CC.Position(restrictedUF) end
assert(measurements==0 and mutations==0 and restricted.points[1]==original,'Forbidden aspects must be checked before reading native points')
restricted.HasAnyForbiddenAspects=function() return false end
restricted.HasAccessConstraints=function() return true end
CC.Position(restrictedUF) assert(measurements==0)
restricted.HasAccessConstraints=function() return secret end
CC.Position(restrictedUF) assert(measurements==0,'Unknown access fails closed')
restricted.HasAccessConstraints=nil restricted.HasAnyForbiddenAspects=nil
for i=1,1000 do CC.Position(restrictedUF) end
assert(measurements==1 and mutations==0,'A client without preflight only attempts a failed snapshot once')
local hiddenAccess=Frame()
hiddenAccess.GetPoint=function() return secret end
hiddenAccess.GetNumPoints=function() return 1 end
assert(not CC.CapturePlacement(hiddenAccess),'Secret anchor values are never saved or used')
print('PASS: restricted FrameMeasurement, access constraints and repeated GetPoint failures leave native controls untouched')

-- Late aura lists, asynchronous native/EllesmereUI layout, combat and cleanup.
local late=Frame()
late.AurasFrame=Frame(late)
late.TisteltiArt=Frame(late)
local lateArt=late.TisteltiArt
lateArt.badge=Frame(lateArt); lateArt.ccAnchor=Frame(lateArt)
lateArt.rightWing=Frame(lateArt); lateArt.rightWingLight=Frame(lateArt)
CC.AttachArt(lateArt,late)
local lateBuff=Frame(late.AurasFrame)
late.AurasFrame.BuffListFrame=lateBuff
lateBuff:SetPoint('LEFT',late,'LEFT',1,2)
tick(lateArt)
assert(lateBuff.points[1][2]==lateArt.ccAnchor,'Late-created buffs must clear the wing')
lateBuff:SetPoint('LEFT',late,'LEFT',0,0)
tick(lateArt)
assert(lateBuff.points[1][2]==lateArt.ccAnchor,'Aura refresh must not leave buffs inside the wing')
local lateDebuff=Frame(late.AurasFrame)
late.AurasFrame.DebuffListFrame=lateDebuff
lateDebuff:SetPoint('RIGHT',late,'RIGHT',3,4)
tick(lateArt)
assert(lateDebuff.points[1][2]==lateBuff,'Second visible aura row stacks above buffs')
combat=true; lateBuff.protected=true
lateBuff:SetShown(false)
tick(lateArt)
assert(lateDebuff.points[1][2]==lateArt.ccAnchor,'Hidden/protected first row must not create an overlap')
lateArt:Hide()
assert(lateDebuff.points[1][1]=='RIGHT' and lateDebuff.points[1][4]==3)
combat=false; CC.Position(late)
assert(lateBuff.points[1][1]=='LEFT' and lateBuff.points[1][4]==1 and lateBuff.points[1][5]==2)
lateBuff:SetPoint('TOP',late,'BOTTOM',7,8)
CC.Position(late)
assert(lateBuff.points[1][1]=='TOP','Inactive Tistelti must leave other addons alone')
print('PASS: late buffs, refreshed anchors, stacked rows, protected combat and full native restoration')
