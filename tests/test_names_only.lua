unpack=unpack or table.unpack
local secret={}
issecretvalue=function(v) return v==secret end
local function Frame()
    local f={shown=true,width=200,textWidth=80,justify='CENTER'}
    function f:CreateTexture() return Frame() end
    function f:EnableMouse() end
    function f:SetTexCoord(...) self.coords={...} end
    function f:SetTexture(v) self.texture=v end
    function f:SetSize(w,h) self.width,self.height=w,h end
    function f:SetPoint(...) self.point={...} end
    function f:ClearAllPoints() end
    function f:IsForbidden() return self.forbidden end
    function f:IsShown() return self.shown end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false end
    function f:GetWidth() return self.width end
    function f:GetStringWidth() return self.textWidth end
    function f:GetJustifyH() return self.justify end
    function f:IsShowOnlyName() return self.namesOnly end
    return f
end
CreateFrame=Frame
dofile('NamesOnly.lua')
local N=TisteltiPlatesNamesOnly
local uf=Frame(); uf.name=Frame(); uf.namesOnly=true
-- Any attempt to mutate native geometry or font in this test is a failure.
uf.SetSize=function() error('native sizing') end
uf.name.SetSize=function() error('native font sizing') end
local db={enabled=true,namesOnlyWings=true}
N.Update(uf,'guild',db)
local art=uf.TisteltiNameWings
assert(art.shown and art.width==80 and art.left.width==16)
assert(art.point[2]==uf.name and art.point[4]==0)
uf.name.justify='LEFT'; N.Update(uf,'guild',db); assert(art.point[4]==-60)
uf.name.justify='RIGHT'; N.Update(uf,'raid',db); assert(art.point[4]==60)
assert(art.left.texture:find('Wings-Banda',1,true))
uf.name.textWidth=300; N.Update(uf,'group',db)
assert(art.width==200 and art.point[4]==0, 'Truncated names use their visible span')
for _,bad in ipairs({0,-1,math.huge,secret}) do
    uf.name.textWidth=bad; N.Update(uf,'guild',db); assert(not art.shown)
end
uf.name.textWidth=80; uf.name.forbidden=true; N.Update(uf,'guild',db); assert(not art.shown)
uf.name.forbidden=false; uf.namesOnly=secret; N.Update(uf,'guild',db); assert(not art.shown)
uf.namesOnly=true; N.Update(uf,nil,db); assert(not art.shown)
N.Update(uf,'guild',db); assert(art.shown)
db.namesOnlyWings=false; N.Update(uf,'guild',db); assert(not art.shown)
db.namesOnlyWings=true; db.enabled=false; N.Update(uf,'guild',db); assert(not art.shown)
print('PASS: mini wings follow visible text width/alignment, safe dimensions and native names-only state')
