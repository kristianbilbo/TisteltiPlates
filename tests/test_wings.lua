dofile("tests/ui_stubs.lua")
dofile("Options.lua")
-- Run from the repository root with Lua 5.1 or later.
unpack = unpack or table.unpack
local frames, panel = {}, nil
local raid = true
local function Frame(parent)
    local f = {parent=parent, shown=true, height=19, frameLevel=1, scripts={}}
    function f:CreateTexture() return Frame(self) end
    function f:CreateFontString() return Frame(self) end
    function f:SetScript(k,v) self.scripts[k]=v end
    function f:SetText(v) self.text=v end
    function f:SetTextColor(...) self.textColor={...} end
    function f:SetBackdropBorderColor(...) self.borderColor={...} end
    function f:SetChecked(v) self.checked=v end
    function f:GetChecked() return self.checked end
    function f:SetTexture(v) self.texture=v end
    function f:SetAlpha(v) self.alpha=v end
    function f:SetHeight(v) self.height=v end
    function f:SetSize(w,h) self.width=w; self.height=h end
    function f:GetHeight() return self.height end
    function f:GetFrameLevel() return self.frameLevel end
    function f:SetFrameLevel(v) self.frameLevel=v end
    function f:SetShown(v) self.shown=v end
    function f:IsShown() return self.shown end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false end
    function f:EnableMouse() end
    function f:RegisterEvent() end
    setmetatable(f, {__index=function(_,k)
        if k:match('^Set') or k=='ClearAllPoints' then return function() end end
    end})
    frames[#frames+1]=f
    return f
end
CreateFrame=function(_,_,parent,template) local f=Frame(parent); f.template=template; return f end
UIParent=Frame()
SlashCmdList={}
RAID_CLASS_COLORS={MAGE={r=.2,g=.6,b=1}}
TisteltiPlatesCC={AttachArt=function() end}
Settings={RegisterCanvasLayoutCategory=function(p) panel=p; return p end, RegisterAddOnCategory=function() end}
IsInRaid=function() return raid end
IsInInstance=function() return false end
InCombatLockdown=function() return false end
UnitIsPlayer=function() return true end
UnitIsUnit=function() return false end
UnitIsFriend=function() return true end
UnitInParty=function() return true end -- Raid subgroup members can also match.
UnitInRaid=function() return raid end
UnitIsInMyGuild=function() return false end
local file=assert(io.open('Core.lua','rb'))
local source=file:read('*a'); file:close()
local core=assert((loadstring or load)(source .. [[
return {driver=driver, membership=Membership, rosterMembership=RosterMembership, wings=PaintWings}
]]))('TisteltiPlates')
local function initialize(db)
    TisteltiPlatesDB=db
    core.driver.scripts.OnEvent(core.driver,'ADDON_LOADED','TisteltiPlates')
end
initialize({group=false, guild=true, appearance={group={border='color',color={.1,.2,.3}}}})
assert(TisteltiPlatesDB.raid==false, 'Migration must preserve the old disabled group setting')
assert(TisteltiPlatesDB.appearance.raid.border=='color')
assert(TisteltiPlatesDB.appearance.raid.color[1]==.1)
assert(TisteltiPlatesDB.appearance.raid~=TisteltiPlatesDB.appearance.group)
assert(TisteltiPlatesDB.appearance.raid.color~=TisteltiPlatesDB.appearance.group.color)
initialize({group=true,guild=true})
assert(TisteltiPlatesDB.raid==true)
assert(TisteltiPlatesDB.priority=='guild', 'Updating must retain the existing guild priority')
local function menu(caption)
    for i=#frames,1,-1 do if frames[i].caption==caption then return frames[i] end end
    error('Missing menu: '..caption)
end
local function choose(caption, text)
    local button=menu(caption)
    button.scripts.OnClick()
    for i=#frames,1,-1 do
        local row=frames[i]
        if row.parent and row.parent.owner==button and row.text==text and row.shown then
            row.scripts.OnClick(); return
        end
    end
    error('Missing choice: '..text)
end
local function selectTab(text)
    for i=#frames,1,-1 do
        if frames[i].template=='PanelTopTabButtonTemplate' and frames[i].text==text and frames[i].scripts.OnClick then
            frames[i].scripts.OnClick(); return
        end
    end
    error('Missing tab: '..text)
end
local function displayedTexture()
    for i=#frames,1,-1 do
        local texture=frames[i].texture
        if type(texture)=='string' and texture:find('Wings',1,true) then return texture end
    end
end
-- Regression: the options preview must remain turquoise even while in a raid.
panel.scripts.OnShow()
assert(displayedTexture():find('Wings-Grupo-v1.tga',1,true))
choose('Estilo','Banda')
assert(displayedTexture():find('Wings-Banda-v1.tga',1,true))
choose('Borde','Cobre')
assert(TisteltiPlatesDB.appearance.raid.border=='cobre')
assert(TisteltiPlatesDB.appearance.group.border=='oroazul')
choose('Estilo','Grupo')
assert(displayedTexture():find('Wings-Grupo-v1.tga',1,true))
choose('Mostrar','Desactivado')
assert(not TisteltiPlatesDB.group and TisteltiPlatesDB.raid)
assert(core.membership('nameplate1')=='raid')
choose('Estilo','Banda'); choose('Mostrar','Desactivado')
assert(core.membership('nameplate1')==nil, 'Disabled raid must not fall back to party style')
raid=false; TisteltiPlatesDB.group=true
assert(core.membership('nameplate1')=='group')
raid=true; TisteltiPlatesDB.raid=true
assert(core.membership('nameplate1')=='raid')
selectTab('Hermandad')
assert(displayedTexture():find('Media\\Wings.tga',1,true))
-- Explicit styles must also work for plates and their two light layers.
local o={wings=Frame(),rightWing=Frame(),leftWingLight=Frame(),rightWingLight=Frame()}
for _,style in ipairs({'group','raid','guild','group'}) do
    core.wings(o,style)
    assert(o.wings.texture==o.rightWing.texture and o.wings.texture==o.leftWingLight.texture
        and o.wings.texture==o.rightWingLight.texture)
end
initialize(TisteltiPlatesDB)
assert(TisteltiPlatesDB.appearance.raid.border=='cobre', 'Reload must preserve raid customization')
print('PASS: three options styles, correct previews while in raid, independent settings, migration and membership')

-- Guild takes priority in both direct/combat membership and roster identity.
local sameGuild = {}
UnitIsInMyGuild=function(unit) return sameGuild[unit] or false end
for _,isRaid in ipairs({false,true}) do
    raid=isRaid
    local fallback=raid and 'raid' or 'group'
    TisteltiPlatesDB.group=true; TisteltiPlatesDB.raid=true; TisteltiPlatesDB.guild=true
    sameGuild={nameplate1=true}
    assert(core.membership('nameplate1')=='guild')
    assert(core.rosterMembership('nameplate1','roster1',fallback)=='guild')
    sameGuild={roster1=true}
    assert(core.rosterMembership('nameplate1','roster1',fallback)=='guild')
    assert(core.rosterMembership('nameplate1','roster1',nil)=='guild', 'Guild still applies with group/raid disabled')
    TisteltiPlatesDB.guild=false
    assert(core.rosterMembership('nameplate1','roster1',fallback)==fallback)
    sameGuild={}
    assert(core.membership('nameplate1')==fallback)
    assert(core.rosterMembership('nameplate1','roster1',fallback)==fallback)
    assert(core.rosterMembership('nameplate1','roster1',nil)==nil)
end
TisteltiPlatesDB.guild=true; sameGuild={nameplate1=true}
UnitIsFriend=function() return false end
assert(core.membership('nameplate1')==nil, 'Hostile players must remain excluded')
print('PASS: guild priority in party/raid, direct and roster identities, disabled styles and hostile exclusion')

UnitIsFriend=function() return true end
TisteltiPlatesDB.guild=true
for _,isRaid in ipairs({false,true}) do
    raid=isRaid
    local fallback=raid and 'raid' or 'group'
    sameGuild={nameplate1=true,roster1=true}
    choose('Prioridad','Grupo/Banda')
    assert(TisteltiPlatesDB.priority=='group')
    assert(core.membership('nameplate1')==fallback)
    assert(core.rosterMembership('nameplate1','roster1',fallback)==fallback)
    selectTab('Hermandad')
    assert(TisteltiPlatesDB.priority=='group', 'Editing an appearance must not change priority')
    assert(core.rosterMembership('nameplate1','roster1',nil)=='guild', 'Disabled group style falls back to guild')
    choose('Prioridad','Hermandad')
    assert(core.membership('nameplate1')=='guild')
    assert(core.rosterMembership('nameplate1','roster1',fallback)=='guild')
    sameGuild={}
    assert(core.membership('nameplate1')==fallback, 'Other guilds retain the group/raid appearance')
end
sameGuild={nameplate1=true}
UnitInRaid=function() return false end
UnitInParty=function() return false end
choose('Prioridad','Grupo/Banda')
assert(core.membership('nameplate1')=='guild', 'Guild members outside the roster keep their usual appearance')
initialize(TisteltiPlatesDB)
assert(TisteltiPlatesDB.priority=='group', 'Priority must persist across reloads')
assert(menu('Prioridad').read()=='groupFirst')
print('PASS: priority dropdown changes actual party/raid membership, preserves guild outside groups and survives reload')

-- Exercise the real tab controls, previews, color picker and cancellation.
local function visibleButton(prefix)
    for i=#frames,1,-1 do
        local f=frames[i]
        if f.shown and type(f.text)=='string' and f.text:sub(1,#prefix)==prefix and f.scripts.OnClick then return f end
    end
    error('Missing visible button: '..prefix)
end
local function named(text)
    for i=#frames,1,-1 do if frames[i].text==text then return frames[i] end end
    error('Missing preview: '..text)
end
local picked={.3,.8,.5}
ColorPickerFrame={Hide=function() end,
    GetColorRGB=function() return unpack(picked) end,
    SetupColorPickerAndShow=function(self,info) self.info=info end}
selectTab('Enemigos')
local sample=named('Jugador enemigo')
assert(sample.textColor[1]==1 and sample.textColor[2]==.12)
visibleButton('Color del nombre').scripts.OnClick()
ColorPickerFrame.info.swatchFunc()
assert(TisteltiPlatesDB.playerColors.enemy.nameColor[1]==.3 and sample.textColor[2]==.8)
ColorPickerFrame.info.cancelFunc()
assert(TisteltiPlatesDB.playerColors.enemy.nameColor[1]==1 and sample.textColor[2]==.12)
visibleButton('Color del borde').scripts.OnClick()
ColorPickerFrame.info.swatchFunc()
local found=false
for _,f in ipairs(frames) do if f.shown and f.borderColor and f.borderColor[2]==.8 then found=true end end
assert(found, 'Border preview follows the chosen RGB')
selectTab('Aliados')
assert(named('Jugador aliado').textColor[1]==1, 'Disabled ally name keeps its normal color')
assert(TisteltiPlatesDB.playerColors.ally.borderColor[2]==.65, 'Enemy picker leaves allies unchanged')
-- A picker opened in one tab must not write to another after switching.
ColorPickerFrame.info.cancelFunc()
assert(TisteltiPlatesDB.playerColors.enemy.borderColor[2]==.12)
selectTab('Hermandad')
local oldMode=TisteltiPlatesDB.appearance.guild.border
visibleButton('Color del borde').scripts.OnClick(); ColorPickerFrame.info.swatchFunc()
assert(TisteltiPlatesDB.appearance.guild.border=='color')
ColorPickerFrame.info.cancelFunc()
assert(TisteltiPlatesDB.appearance.guild.border==oldMode)
print('PASS: four tabs, live enemy/ally previews, independent RGB colors, cancel and tab-switch isolation')

assert(panel.numTabs==4 and #panel.Tabs==4)
selectTab('Enemigos'); assert(panel.selectedTab==4 and panel.Tabs[4].selected)
selectTab('Hermandad'); assert(panel.selectedTab==1 and not panel.Tabs[4].selected)
for _,tab in ipairs(panel.Tabs) do assert(tab.template=='PanelTopTabButtonTemplate') end
print('PASS: native WoW tab templates and selection API, not ordinary button navigation')
