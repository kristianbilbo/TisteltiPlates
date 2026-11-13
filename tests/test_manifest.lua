-- Load exactly the shipped TOC, including Honor, in the native-frame fixture.
local file=assert(io.open('tests/test_pvp.lua','r'))
local fixture=file:read('*a'); file:close()
fixture=fixture:sub(1,assert(fixture:find("assert(loadfile('Prioridad.lua'))()",1,true))-1)
fixture=fixture:gsub('dofile%("Options.lua"%)\n','')
local cases=[=[
local toc=assert(io.open('TisteltiPlates.toc','r'))
local loaded={}
for line in toc:lines() do
    local path=line:match('^%s*(.-)%s*$')
    if path:match('%.lua$') then
        assert(not loaded[path], 'Duplicate module: '..path)
        assert(loadfile(path))('TisteltiPlates')
        loaded[path]=true
    end
end
toc:close()
for _,path in ipairs({'Honor.lua','Prioridad.lua','NamesOnly.lua','PlayerStyle.lua',
    'PvP.lua','CCPosition.lua','Options.lua','Core.lua'}) do
    assert(loaded[path], 'Missing module: '..path)
end
local driver=frames[#frames]
TisteltiPlatesDB={}
driver.scripts.OnEvent(driver,'ADDON_LOADED','TisteltiPlates')
local uf=Frame(); uf.unit='enemy'; uf.native=true
uf.healthBar=Frame(uf); uf.HealthBarsContainer=uf.healthBar
uf.name=Frame(uf); uf.name:SetText('Enemy')
plates.enemy={UnitFrame=uf}
driver.scripts.OnEvent(driver,'NAME_PLATE_UNIT_ADDED','enemy')
assert(uf.TisteltiPlayerBorder.shown and uf.name.textColor[2]==.12)
SlashCmdList.TISTELTIPLATES('pvp on')
assert(uf.TisteltiPvPArt.shown and not uf.TisteltiPlayerBorder.shown)
assert(uf.name.textColor[2]==.12)
SlashCmdList.TISTELTIPLATES('off')
assert(not uf.TisteltiPvPArt.shown and uf.name.textColor[1]==1)
assert(#errors==0,table.concat(errors,'\n'))
print('PASS: all eight shipped TOC modules load, initialize, render, switch modes and restore together')
]=]
assert((loadstring or load)(fixture..cases))()
