dofile("Config.lua")
unpack = unpack or table.unpack
local frames = {}
local function Frame()
    local f = {shown=true, color={.8,.8,.8,1}}
    function f:IsForbidden() return false end
    function f:IsShown() return self.shown end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false end
    function f:GetFrameLevel() return 5 end
    function f:GetTextColor() return unpack(self.color) end
    function f:SetTextColor(...) self.color={...} end
    function f:SetVertexColor(...) self.color={...} end
    function f:SetSize() error('Must not resize native plates') end
    function f:SetScale() error('Must not scale native plates') end
    setmetatable(f,{__index=function(_,key)
        if key:match('^Set') or key=='ClearAllPoints' or key=='EnableMouse' then
            return function() end
        end
    end})
    frames[#frames+1]=f
    return f
end
CreateFrame=Frame
hooksecurefunc=function(object,key,hook)
    local original=object[key]
    object[key]=function(...) original(...); hook(...) end
end
local units={player={true,'Alliance'},horde={true,'Horde'},ally={true,'Alliance'},npc={false,'Horde'}}
UnitIsUnit=function(a,b) return a==b end
UnitIsPlayer=function(unit) return units[unit] and units[unit][1] end
UnitFactionGroup=function(unit) return units[unit] and units[unit][2] end
local secret={}
issecretvalue=function(v) return v==secret end
units.restricted={true,secret}
dofile('PlayerStyle.lua')
local H=TisteltiPlatesPlayers
local uf=Frame(); uf.name=Frame(); uf.HealthBarsContainer=Frame(); uf.unit='horde'
local db={enabled=true,playerColors={enemy={name=true,border=true,nameColor={1,.12,.12},borderColor={1,.12,.12}},ally={name=false,border=false,nameColor={.2,.6,1},borderColor={.2,.6,1}}}}
H.Update(uf,uf.unit,db)
local border=frames[#frames]
assert(border~=uf.HealthBarsContainer and border.shown)
assert(uf.name.color[1]==1 and uf.name.color[2]==.12)
-- Native selection/mouseover changes must retain red, but restore their latest color.
uf.name:SetVertexColor(.2,.4,.6,1)
assert(uf.name.color[1]==1 and uf.name.color[2]==.12)
db.playerColors.enemy.name=false; H.Update(uf,uf.unit,db)
assert(uf.name.color[1]==.2 and uf.name.color[2]==.4 and border.shown)
db.playerColors.enemy.name=true; db.playerColors.enemy.border=false; H.Update(uf,uf.unit,db)
assert(uf.name.color[1]==1 and not border.shown)
db.playerColors.enemy.border=true
for _,unit in ipairs({'ally','npc','restricted','missing'}) do
    uf.unit=unit; H.Update(uf,unit,db)
    assert(not border.shown and uf.name.color[1]==.2, 'Only known Horde players are accented')
    uf.unit='horde'; H.Update(uf,uf.unit,db)
end
-- A reused native frame must not keep forcing red before the next refresh.
uf.unit='ally'; uf.name:SetVertexColor(.7,.7,.7,1)
assert(uf.name.color[1]==.7)
H.Remove(uf); assert(not border.shown and uf.name.color[1]==.7)
uf.unit='horde'; H.Update(uf,uf.unit,db)
db.enabled=false; H.Update(uf,uf.unit,db)
assert(not border.shown and uf.name.color[1]==.7)
db.enabled=true; H.Update(uf,uf.unit,db)
uf.unit=nil; H.Remove(uf)
assert(not border.shown and uf.name.color[1]==.7)
-- Missing faction APIs fail closed, including restricted data in combat.
UnitFactionGroup=function() error('Restricted') end
uf.unit='horde'; H.Update(uf,uf.unit,db)
assert(not border.shown)
UnitFactionGroup=function(unit) return units[unit] and units[unit][2] end
units.player[2]='Horde'
assert(H.Kind('ally')=='enemy' and H.Kind('horde')=='ally')
assert(H.Kind('player')==nil and H.Kind('npc')==nil)
UnitCanAttack=function(_,unit) return unit=='horde' end
assert(H.Kind('horde')=='enemy', 'Same-faction duels are enemies')
UnitCanAttack=function() return false end
UnitIsFriend=function(_,unit) return unit=='ally' end
assert(H.Kind('ally')=='ally', 'Friendly cross-faction players are allies')
UnitIsFriend=nil
uf.unit='ally'; db.playerColors.enemy.nameColor={.3,.9,.4}; H.Update(uf,uf.unit,db)
assert(uf.name.color[1]==.3 and uf.name.color[2]==.9)
H.Remove(uf)
uf.unit='horde'; db.playerColors.ally.name=true; db.playerColors.ally.border=true
H.Update(uf,uf.unit,db)
assert(uf.name.color[1]==.2 and border.shown)
H.Update(uf,uf.unit,db,true)
assert(not border.shown and uf.name.color[1]==.7, 'Guild/group keep their style')
print('PASS: both player factions, duels, friendly cross-faction players, custom colors and guild/group priority')
