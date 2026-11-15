dofile("Config.lua")
-- Regression: tiny native plate scales must not leave huge guild text in combat.
local combat=false
InCombatLockdown=function() return combat end
IsInInstance=function() return false end
UnitIsPlayer=function() return true end
UnitIsUnit=function() return false end
GetGuildInfo=function() return 'INFINITY' end
STANDARD_TEXT_FONT='font'
SlashCmdList={}
CreateFrame=function()
 return {SetScript=function(self,k,f) self[k]=f end,RegisterEvent=function() end}
end
UIParent={GetEffectiveScale=function() return 1 end}
local function Label()
 local label={scale=1}
 function label:SetFont() end
 function label:SetTextColor() end
 function label:ClearAllPoints() end
 function label:SetPoint() end
 function label:SetScale(s) self.scale=s end
 function label:SetText(t) self.text=t end
 function label:Show() self.shown=true end
 function label:SetShown(s) self.shown=s end
 function label:IsShown() return self.shown end
 return label
end
local f=assert(io.open('Core.lua','r'))
local source=f:read('*a');f:close()
local core=assert((loadstring or load)(source..[[
return {driver=driver,plain=PlainGuildName,labels=guildLabels,active=active,
setDB=function(v) db=v end,setGuildName=SetGuildName}
]]))('TisteltiPlates')
core.setDB({enabled=true})
local uf={scale=1,HealthBarsContainer={}}
function uf:GetEffectiveScale() return self.scale end
function uf:CreateFontString() return Label() end
core.plain(uf,'nameplate1')
local label=core.labels[uf]
local decorated=Label();decorated:Show()
core.active[{}]={art={guildName=decorated,GetEffectiveScale=function() return uf.scale end}}
for _,s in ipairs({1,.001,.02,.5,1.5}) do
 uf.scale=s
 core.driver:OnUpdate(.01)
 assert(label.scale==1 and decorated.scale==1,'Guild labels must not invert the native scale')
 combat=true;uf.scale=1
 core.driver:OnUpdate(.01)
 assert(label.scale==1 and decorated.scale==1,'Combat must not preserve an oversized guild label')
 combat=false
end
-- Reused labels lose any old multiplier, for both plain/decorated rendering.
label.scale=1000;core.plain(uf,'nameplate2')
assert(label.scale==1 and label.text=='<INFINITY>')
decorated.scale=1000;core.setGuildName(decorated,'Tistelti')
assert(decorated.scale==1 and decorated.text=='<Tistelti>' and decorated.shown)
core.setGuildName(decorated,nil)
assert(not decorated.shown and decorated.text=='')
print('PASS: tiny scales, distance/selection changes, combat transition and reused guild labels')
