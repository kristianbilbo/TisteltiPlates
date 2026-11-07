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
loss.protected=false; crowd.protected=false
CC.Position(uf)
assert(loss.points[1][2]==combatArt.badge, "Unprotected controls can move during combat")
combat=false
events.scripts.OnEvent(events,"PLAYER_REGEN_ENABLED")
assert(loss.points[1][2]==combatArt.badge)
combatArt:Hide()
assert(loss.points[1][2]==uf.PlayerLevelDiffFrame and loss.level==2)
uf.PlayerLevelDiffFrame.alpha=0
CC.Position(uf)
assert(loss.points[1][2]==uf.HealthBarsContainer)
uf.PlayerLevelDiffFrame.alpha=1
events.scripts.OnEvent(events,"NAME_PLATE_UNIT_ADDED","nameplate1")
uf:UpdateAnchors()
assert(loss.points[1][2]==uf.PlayerLevelDiffFrame, "Undecorated/enemy plates keep standalone positioning")
local preview=Frame(); preview.rightWing=Frame(preview); preview.rightWingLight=Frame(preview)
CC.AttachArt(preview, Frame())
assert(not preview.scripts.OnUpdate)
loss.AuraItemFrame:Hide(); art:Show()
assert(art.rightWing.shown, "Reused decoration restores wing")
print("PASS: icon visibility, glow, empty containers, parents, combat, reuse, previews and positioning")

-- Exercise the actual Core layout so it cannot move CC back above the plate.
local f=assert(io.open("TisteltiPlates/Core.lua","rb"))
local source=f:read("*a"); f:close()
local core=assert(loadChunk(source .. [[
return {layout=Layout, remove=Remove, active=active, setDB=function(value) db=value end}
]]))()
core.setDB({enabled=true,scale=1})
IsInInstance=function() return false end
local buff=Frame(auras)
local state={art=art,levels={},cc={
    {frame=buff,row=0}, {frame=loss,row=2},
}}
art.ccAnchor=Frame(art)
core.layout(state)
assert(buff.points[1][1]=="BOTTOM")
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
