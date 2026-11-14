-- Saved preferences, scrollable sections and previews of the shared renderers.
TisteltiPlatesOptions = {}
local O=TisteltiPlatesOptions
local C=TisteltiPlatesConfig
local sections={"general","appearance","behavior","pvp","advanced"}
local labels={general="General",appearance="Apariencia",behavior="Comportamiento",pvp="PvP",advanced="Avanzado",
    group="Grupo",raid="Banda",guild="Hermandad",ally="Aliados",enemy="Enemigos",world="Mundo abierto",party="Mazmorras",arena="Arenas",
    auto="Heredado",native="Nativo de WoW",class="Clase",faction="Facción",custom="Personalizado",
    oroazul="Oro y azul",oro="Oro",plata="Plata",cobre="Cobre",bronce="Bronce",platino="Platino",zafiro="Zafiro",
    esmeralda="Esmeralda",amatista="Amatista",rubi="Rubí",clase="Clase",rango="Mérito",color="Personalizado",
    level="Nivel",health="Barra de salud",red="Rojo",blue="Azul",violeta="Violeta",azul="Azul",verde="Verde",
    normal="Normal",compact="En combate de grupo",control="Con control activo",names="Solo nombres",selected="Objetivo seleccionado",recommended="Objetivo recomendado",
    Alliance="Alianza",Horde="Horda"}
local function label(value) return labels[value] or tostring(value) end
function O.Open(section)
    if O.select then O.select(section or "general") end
    if O.category and Settings and Settings.OpenToCategory then Settings.OpenToCategory(O.category:GetID()) end
end
function O.Register(db,api)
    if not Settings or not Settings.RegisterCanvasLayoutCategory then return end
    local panel=CreateFrame("Frame")
    O.panel=panel; O.controls={}; O.previews={}
    local page,subject,scenario,faction,rank="general","group","normal","Alliance",8
    local updates,pages={},{}
    local redraw,scroll
    local function text(parent,value,x,y,size)
        local t=parent:CreateFontString(nil,"OVERLAY",size or "GameFontHighlightSmall")
        t:SetPoint("TOPLEFT",x,y); t:SetWidth(525); t:SetJustifyH("LEFT"); t:SetWordWrap(true); t:SetText(value)
        return t
    end
    text(panel,"TisteltiPlates",20,-14,"GameFontNormalLarge")
    local status=text(panel,"",20,-82)
    O.status=status
    local scopeEnable=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    scopeEnable:SetPoint("TOPRIGHT",-45,-12); scopeEnable:SetSize(245,26)
    O.controls["scope.enableCurrent"]=scopeEnable
    local popup=CreateFrame("Frame",nil,panel,"BackdropTemplate")
    popup:SetClampedToScreen(true); popup:SetFrameStrata("TOOLTIP"); popup:SetBackdrop({bgFile=api.WHITE}); popup:SetBackdropColor(.03,.04,.06,1)
    popup:EnableMouse(true); popup:Hide()
    local rows={}
    local function changed() api.Refresh(); redraw() end
    scopeEnable:SetScript("OnClick",function()
        local scope=C.Scope()
        if db.enabled and (scope=="party" or scope=="raid") then db.scopes[scope]=true; changed() end
    end)
    local function remember(id,widget) widget.settingID=id; O.controls[id]=widget end
    local function sync(widget,fn)
        updates[#updates+1]=fn; widget:SetScript("OnShow",fn)
    end
    local function choice(parent,id,caption,values,get,set,x,y,width)
        local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
        b:SetPoint("TOPLEFT",x or 12,y); b:SetSize(width or 525,26); b.caption=caption
        remember(id,b)
        sync(b,function() b:SetText(caption..": "..label(get())) end)
        b:SetScript("OnClick",function()
            if popup:IsShown() and popup.owner==b then popup:Hide(); return end
            popup.owner=b; popup:ClearAllPoints(); popup:SetPoint("TOPLEFT",b,"BOTTOMLEFT")
            popup:SetSize(width or 525,#values*22+4)
            for _,r in ipairs(rows) do r:Hide() end
            for i,value in ipairs(values) do
                local v=value
                local r=rows[i] or CreateFrame("Button",nil,popup,"UIPanelButtonTemplate"); rows[i]=r
                r:ClearAllPoints(); r:SetPoint("TOPLEFT",2,-2-(i-1)*22); r:SetSize((width or 525)-4,22)
                r:SetText(label(v)); r:SetScript("OnClick",function() set(v); popup:Hide(); changed() end); r:Show()
            end
            popup:Show()
        end)
        return b
    end
    local function check(parent,id,caption,get,set,y,dependency)
        local b=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate")
        b:SetPoint("TOPLEFT",12,y); b:SetSize(26,26); remember(id,b)
        local t=text(b,caption,32,-6); t:SetWidth(490)
        sync(b,function()
            b:SetChecked(get()); local available=not dependency or dependency()
            b:SetEnabled(available); t:SetAlpha(available and 1 or .5)
        end)
        b:SetScript("OnClick",function(self)
            if dependency and not dependency() then redraw(); return end
            set(self:GetChecked() and true or false); changed()
        end)
        return b
    end
    local function number(parent,id,caption,get,set,min,max,step,y,dependency)
        local t=text(parent,caption.." ("..min.."–"..max..")",16,y-7)
        t:SetWidth(390)
        local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
        e:SetSize(95,26); e:SetPoint("TOPLEFT",440,y); e:SetAutoFocus(false); remember(id,e)
        local function draw()
            e:SetText(tostring(get())); local available=not dependency or dependency()
            e:SetEnabled(available); t:SetAlpha(available and 1 or .5)
        end
        sync(e,draw)
        local function commit()
            local n=tonumber(e:GetText())
            if n and n==n and (not dependency or dependency()) then
                n=math.max(min,math.min(max,n)); n=tonumber(string.format("%.4f",math.floor(n/step+.5)*step))
                set(n); changed()
            else draw() end
            e:ClearFocus()
        end
        e:SetScript("OnEnterPressed",commit)
        e:SetScript("OnEscapePressed",function() draw(); e:ClearFocus() end)
        -- Losing focus restores the stored value; Enter is the explicit apply action.
        e:SetScript("OnEditFocusLost",draw)
    end
    local function color(parent,id,caption,get,resolve,y)
        local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
        b:SetSize(525,26); b:SetPoint("TOPLEFT",12,y); b:SetText(caption); remember(id,b)
        local swatch=b:CreateTexture(nil,"OVERLAY"); swatch:SetSize(14,14); swatch:SetPoint("RIGHT",-12,0)
        sync(b,function() local rgb=get(); swatch:SetColorTexture(rgb[1],rgb[2],rgb[3],1) end)
        b:SetScript("OnClick",function()
            local picker=ColorPickerFrame; if not picker then return end
            local rgb=get(); local apply,cancel=resolve(); local old={rgb[1],rgb[2],rgb[3]}
            local function update() local r,g,b=picker:GetColorRGB(); apply({r,g,b}); changed() end
            local function restore() if cancel then cancel() else apply(old) end; changed() end
            picker:Hide()
            if picker.SetupColorPickerAndShow then
                picker:SetupColorPickerAndShow({r=rgb[1],g=rgb[2],b=rgb[3],hasOpacity=false,swatchFunc=update,cancelFunc=restore})
            else picker.hasOpacity=false; picker.func=update; picker.cancelFunc=restore; picker:SetColorRGB(unpack(old)); picker:Show() end
        end)
    end
    panel.Tabs={}
    for i,key in ipairs(sections) do
        local section=key
        local b=CreateFrame("Button",nil,panel,"PanelTopTabButtonTemplate")
        b:SetID(i); b:SetText(labels[section]); panel.Tabs[i]=b
        b:SetNormalFontObject(GameFontNormal); b:SetHighlightFontObject(GameFontHighlight); b:SetDisabledFontObject(GameFontHighlight)
        PanelTemplates_TabResize(b,10,nil,95)
        if i==1 then b:SetPoint("TOPLEFT",20,-45) else b:SetPoint("LEFT",panel.Tabs[i-1],"RIGHT",1,0) end
        b:SetScript("OnClick",function() O.select(section) end)
    end
    PanelTemplates_SetNumTabs(panel,#sections)
    local preview=CreateFrame("Frame",nil,panel); preview:SetPoint("TOPLEFT",20,-110); preview:SetSize(550,200)
    local caption=text(preview,"Vista previa de los ajustes guardados",0,0,"GameFontNormal")
    local sample=CreateFrame("Frame",nil,preview); sample:SetSize(180,19); sample:SetPoint("TOPLEFT",160,-58)
    local bar=CreateFrame("StatusBar",nil,sample); bar:SetAllPoints(sample); bar:SetSize(180,19)
    bar:SetStatusBarTexture(api.WHITE); bar:SetMinMaxValues(0,100); bar:SetValue(78)
    sample.healthBar=bar
    sample.name=sample:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); sample.name:SetPoint("CENTER",bar,"CENTER")
    sample.name:SetWidth(170)
    local classic=api.Ornament(sample)
    local border=api.FrameBorder(sample,14,false); border:SetPoint("TOPLEFT",bar,"TOPLEFT",-5,5); border:SetPoint("BOTTOMRIGHT",bar,"BOTTOMRIGHT",5,-5)
    O.previews.sample=sample; O.previews.classic=classic; O.previews.border=border
    choice(preview,"preview.scenario","Escena",{"normal","compact","control","names","selected","recommended"},function() return scenario end,function(v)
        scenario=v
        if v=="selected" or v=="recommended" then subject="enemy" end
        if v=="compact" and subject~="group" and subject~="raid" then subject="group" end
    end,0,-145,265)
    choice(preview,"preview.faction","Facción",{"Alliance","Horde"},function() return faction end,function(v) faction=v end,275,-145,265)
    choice(preview,"preview.rank","Mérito de ejemplo",{0,1,2,3,4,5,6,7,8,9,10,11,12,13,14},function() return rank end,function(v) rank=v end,275,-178,265)
    choice(preview,"preview.subject","Vista de",{"guild","group","raid","ally","enemy"},function() return subject end,function(v) subject=v; if scroll then scroll:SetVerticalScroll(0) end; if scenario=="compact" and v~="group" and v~="raid" then scenario="normal" end end,0,-178,265)
    scroll=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",20,-340); scroll:SetPoint("BOTTOMRIGHT",-45,45)
    local reset=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate"); reset:SetPoint("BOTTOMLEFT",20,12); reset:SetSize(260,26)
    reset:SetText("Restaurar esta sección"); O.controls.reset=reset
    local armed
    reset:SetScript("OnClick",function()
        if armed~=page then armed=page; reset:SetText("Confirmar restauración"); return end
        C.Reset(db,page); armed=nil; reset:SetText("Restaurar esta sección"); changed()
    end)
    local function build(section)
        local content=CreateFrame("Frame",nil,scroll); content:SetSize(550,100); pages[section]=content
        local y=-8
        local function row() local v=y; y=y-34; return v end
        local function note(value) text(content,value,12,y); y=y-48 end
        local function heading(value) text(content,value,12,y,"GameFontNormal"); y=y-26 end
        local function toggle(id,caption,get,set,dependency) check(content,id,caption,get,set,row(),dependency) end
        local function field(section,key,caption,dependency)
            toggle(section.."."..key,caption,function() return db[section][key] end,function(v) db[section][key]=v end,dependency)
        end
        local function num(section,key,caption,min,max,step,dependency)
            number(content,section.."."..key,caption,function() return db[section][key] end,function(v) db[section][key]=v end,min,max,step,row(),dependency)
        end
        local function select(section,key,caption,values)
            choice(content,section.."."..key,caption,values,function() return db[section][key] end,function(v) db[section][key]=v end,12,row())
        end
        if section=="general" then
            toggle("enabled","Activar TisteltiPlates",function() return db.enabled end,function(v) db.enabled=v end)
            heading("Dónde mostrar placas y alitas")
            for _,key in ipairs({"world","party","raid","pvp","arena"}) do
                field("scopes",key,key=="pvp" and "Campos de batalla" or key=="raid" and "Bandas" or labels[key])
            end
            note("Desactivar un lugar también oculta las alitas de solo nombres. Mazmorras y bandas tienen interruptores independientes.")
            field("wings","dungeonGuildOnly","En mazmorras, alitas solo para mi hermandad")
            note("Se aplica a las alitas con barras y en solo nombres. Fuera de mazmorras se mantienen tus ajustes habituales.")
            heading("Alitas en el modo solo nombres de WoW")
            toggle("namesOnlyWings","Mostrar alitas junto al nombre",function() return db.namesOnlyWings end,function(v) db.namesOnlyWings=v end)
            for _,key in ipairs({"group","raid","guild"}) do field("mini",key,"Alitas · "..labels[key],function() return db.namesOnlyWings end) end
            note("Las alitas necesitan el estilo correspondiente de Apariencia. Si coinciden grupo y hermandad, se usa la prioridad guardada. No es necesario mostrar barras de vida.")
            local styles=CreateFrame("Button",nil,content,"UIPanelButtonTemplate")
            styles:SetPoint("TOPLEFT",12,row()); styles:SetSize(525,26)
            styles:SetText("Configurar estilos y ver alitas de ejemplo")
            styles:SetScript("OnClick",function() subject="group"; scenario="names"; O.select("appearance") end)
            remember("names.styles",styles)
            local diagnostic=CreateFrame("Button",nil,content,"UIPanelButtonTemplate")
            diagnostic:SetPoint("TOPLEFT",12,row()); diagnostic:SetSize(525,26)
            diagnostic:SetText("Comprobar placas y controles de WoW")
            diagnostic:SetScript("OnClick",function() TisteltiPlatesCC.Report() end)
            remember("diagnostics",diagnostic)
            note("En combate, los cambios que requieren restaurar marcos protegidos esperan a que termine. El estado superior indica si hay cambios pendientes.")
        elseif section=="appearance" then
            note("Elige la vista arriba. Grupo, banda y hermandad tienen componentes independientes. Aliados y enemigos configuran los acentos generales y los colores en PvP.")
            local startY=y
            local function decorated() return subject=="group" or subject=="raid" or subject=="guild" end
            local function style() return decorated() and subject or "group" end
            local function player() return db.playerColors[subject=="enemy" and "enemy" or "ally"] end
            toggle("style.enabled","Mostrar este estilo",function() return db[style()] end,function(v) db[style()]=v end,decorated)
            for _,pair in ipairs({{"showBorder","Borde"},{"showWings","Alas"},{"showLevel","Nivel"},{"showGuild","Nombre de hermandad"},{"showRole","Distintivo de hermandad"},{"showMerit","Emblema de mérito"}}) do
                local key,caption=pair[1],pair[2]
                toggle("style."..key,caption,function() return db.appearance[style()][key] end,function(v) db.appearance[style()][key]=v end,function() return decorated() and db[style()] end)
            end
            choice(content,"style.border","Acabado del borde",{"oroazul","oro","plata","cobre","bronce","platino","zafiro","esmeralda","amatista","rubi","clase","rango","color"},function() return db.appearance[style()].border end,function(v) if decorated() then db.appearance[style()].border=v end end,12,row())
            color(content,"style.color","Color personalizado del borde",function() return db.appearance[style()].color end,function()
                local config=db.appearance[style()]; local old,mode=config.color,config.border
                return function(rgb) config.color=rgb; config.border="color" end,function() config.color=old; config.border=mode end
            end,row())
            choice(content,"priority","Prioridad al coincidir",{"group","guild"},function() return db.priority end,function(v) db.priority=v end,12,row())
            local styleBottom=y
            y=startY
            local playerNote=text(content,"Colores de jugadores: Nativo restaura el color de WoW. Heredado conserva tus preferencias anteriores; en PvP puede aplicar el color de facción. Estos acentos no sustituyen el estilo de un aliado de grupo/hermandad.",12,y)
            y=y-72
            toggle("player.enabled","Activar acentos de este tipo de jugador",function() return player().enabled end,function(v) player().enabled=v end,function() return not decorated() end)
            for _,key in ipairs({"name","border"}) do
                local field=key
                choice(content,"player."..field.."Mode",field=="name" and "Color del nombre" or "Color del marco",{"auto","native","class","faction","custom"},function() return player()[field.."Mode"] end,function(v) if not decorated() then player()[field.."Mode"]=v end end,12,row())
                color(content,"player."..field.."Color",field=="name" and "Elegir color del nombre" or "Elegir color del marco",function() return player()[field.."Color"] end,function()
                    local config=player(); local old,mode=config[field.."Color"],config[field.."Mode"]
                    return function(rgb) config[field.."Color"]=rgb; config[field.."Mode"]="custom" end,function() config[field.."Color"]=old; config[field.."Mode"]=mode end
                end,row())
            end
            -- Keep unrelated controls out of the active subject; preserve scroll layout.
            updates[#updates+1]=function()
                playerNote:SetShown(not decorated())
                content:SetHeight(-(decorated() and styleBottom or y)+30)
                O.controls.priority:SetShown(decorated())
                for id,w in pairs(O.controls) do
                    if id:match("^style%.") then w:SetShown(decorated()) elseif id:match("^player%.") then w:SetShown(not decorated()) end
                end
            end
        elseif section=="behavior" then
            note("Las opciones atenuadas dependen del interruptor anterior. Los controles son los iconos de pérdida de control de WoW; el addon no modifica filtros ni temporizadores.")
            field("compact","enabled","Compactar grupo/banda durante combate")
            local compact=function() return db.compact.enabled end
            field("compact","group","Aplicar compactación a miembros del grupo",compact)
            field("compact","raid","Aplicar compactación a miembros de la banda",compact)
            field("compact","hideGuild","Ocultar hermandad al compactar",compact)
            field("compact","hideMerit","Ocultar mérito al compactar",compact)
            field("controls","enabled","Reposicionar iconos de control")
            local controls=function() return db.controls.enabled end
            field("controls","allies","Reposicionar controles de aliados",controls)
            field("controls","enemies","Reposicionar controles de enemigos",controls)
            field("controls","buffs","Separar filas de auras de las alas clásicas")
            toggle("hideRightWingOnCC","Ocultar ala derecha cuando hay un control",function() return db.hideRightWingOnCC end,function(v) db.hideRightWingOnCC=v end)
            field("auras","enabled","Dar prioridad a las auras que solapan adornos PvP")
            note("Las alitas de solo nombres y su activación en mazmorras están en General. En compacto se mantienen ambas alas; la ocultación por control actúa en la presentación completa.")
        elseif section=="pvp" then
            note("El modo PvP sustituye la decoración clásica de jugadores. Desmarcar aliados/enemigos excluye el marco PvP; los acentos generales de Apariencia siguen disponibles. La vista previa usa los colores guardados allí.")
            field("pvp","enabled","Activar modo PvP")
            for _,pair in ipairs({{"friends","Jugadores aliados"},{"enemies","Jugadores enemigos"},{"emblem","Emblema de facción"},{"wings","Alas de tu hermandad"},{"guildBothFactions","Alas de hermandad también en Horda"},{"classIcon","Icono de clase"},{"selected","Destacar objetivo seleccionado"},{"recommended","Destacar objetivo recomendado"},{"meritColors","Colorear alas según mérito"}}) do field("pvp",pair[1],pair[2]) end
            select("pvp","friendColor","Barra de aliados",{"class","blue"}); select("pvp","enemyColor","Barra de enemigos",{"class","red"})
            note("La recomendación es solo visual: nunca selecciona, marca ni ataca. Mérito utiliza datos conocidos y guardados por el addon; no fuerza comparaciones de logros. Sin dato se muestra el acabado neutro.")
        elseif section=="advanced" then
            note("Ajustes finos. En campos numéricos, pulsa Intro para aplicar; Escape cancela. La geometría es fija y se desactiva automáticamente si EllesmereUI gestiona las placas.")
            field("geometry","enabled","Ajustar tamaño fijo de placas clásicas")
            num("geometry","scale","Escala fija de la placa",.8,1.8,.01,function() return db.geometry.enabled end)
            num("geometry","width","Anchura fija de la placa",1,1.6,.01,function() return db.geometry.enabled end)
            number(content,"scale","Escala de los adornos clásicos",function() return db.scale end,function(v) db.scale=v end,.8,1.8,.01,row())
            num("compact","delay","Segundos de espera tras salir de combate",0,120,1)
            num("compact","size","Tamaño de alas compactas",.5,2,.05)
            select("controls","anchor","Anclar controles junto a",{"level","health"})
            num("controls","x","Desplazamiento horizontal de controles",-40,80,1)
            num("controls","y","Desplazamiento vertical de controles",-60,60,1)
            num("controls","buffGap","Separación entre filas de auras",0,30,1)
            num("auras","margin","Margen de solapamiento de auras PvP",0,16,1)
            num("mini","size","Tamaño de alitas de solo nombres",8,32,1)
            num("mini","gap","Separación de alitas y nombre",0,30,1)
            num("text","size","Tamaño del nombre de hermandad",8,20,1)
            num("text","offset","Posición vertical del nombre de hermandad",-40,20,1)
            field("recommendation","marked","Recomendar la calavera del grupo")
            field("recommendation","consensus","Recomendar por objetivos coincidentes del grupo")
            num("recommendation","votes","Compañeros necesarios para recomendar",1,10,1)
            num("recommendation","hold","Segundos mínimos antes de cambiar recomendación",0,10,.5)
            num("pvp","intensity","Brillo PvP",.6,1.4,.1)
            num("pvp","wingSize","Tamaño de alas PvP",.6,1.2,.1)
            num("pvp","classIconSize","Tamaño del icono de clase PvP",16,32,1)
            for _,pair in ipairs({{"low","Mérito 1–4"},{"middle","Mérito 5–9"},{"high","Mérito 10–14"}}) do select("pvp",pair[1],pair[2],{"bronce","plata","oro","violeta","azul","verde"}) end
            note("Los ajustes protegidos se restauran al salir de combate. Las comprobaciones de acceso y datos restringidos siempre están activas. No hay ampliación al pasar el cursor.")
        end
        content:SetHeight(-y+30); content:Hide()
    end
    for _,section in ipairs(sections) do build(section) end
    local function drawStatus()
        local pending=InCombatLockdown and InCombatLockdown()
        local active=TisteltiPlatesPvP and TisteltiPlatesPvP.IsActive()
        local scope=C.Scope()
        local place=({world="Mundo abierto",party="Mazmorra",raid="Banda",pvp="Campo de batalla",arena="Arena"})[scope] or "Ámbito actual"
        scopeEnable:SetShown(db.enabled and (scope=="party" or scope=="raid") and not db.scopes[scope] or false)
        scopeEnable:SetText(scope=="raid" and "Activar placas y alitas en bandas" or "Activar placas y alitas en mazmorras")
        status:SetText((not db.enabled and "TisteltiPlates desactivado" or C.Allowed(db) and (place..": activado") or (place..": placas y alitas desactivadas"))
            ..(pending and " · Combate: restauraciones protegidas al terminar" or "")
            ..(active~=db.pvp.enabled and " · Cambio de modo PvP pendiente" or "")
            ..(C.ExternalGeometry() and " · Tamaño gestionado por EllesmereUI" or ""))
    end
    redraw=function()
        for _,fn in ipairs(updates) do fn() end
        drawStatus()
        classic:Hide(); border:Hide(); if TisteltiPlatesNamesOnly then TisteltiPlatesNamesOnly.Remove(sample) end
        if sample.TisteltiPvPArt then sample.TisteltiPvPArt:Hide() end
        if sample.TisteltiPvPEmphasis then sample.TisteltiPvPEmphasis:Hide() end
        bar:Show(); sample.name:Show(); sample.name:SetText("Mago de muestra"); sample.name:SetTextColor(1,1,1)
        local rgb=RAID_CLASS_COLORS.MAGE; bar:SetStatusBarColor(rgb.r,rgb.g,rgb.b)
        local special=subject=="group" or subject=="raid" or subject=="guild"
        local usePvP=db.pvp.enabled and scenario~="names"
        caption:SetText("Muestra de aspecto · "..label(subject).." · "..(usePvP and "PvP" or "Clásico").." · "..label(scenario))
        if not db.enabled then return end
        if scenario=="names" then
            bar:Hide(); sample.name:Show()
            -- Name is parented to the sample so native names-only can remain visible.
            if not special then
                local name=C.ResolveColor(db,subject,"name","MAGE",faction,false)
                sample.name:SetTextColor(unpack(name or {1,1,1}))
            end
            if special and db[subject] and db.namesOnlyWings then TisteltiPlatesNamesOnly.Paint(sample,sample.name,subject,db) end
        elseif usePvP then
            local kind=subject=="enemy" and "enemy" or "ally"
            TisteltiPlatesPvP.DrawPreview(sample,kind,faction,rank,scenario)
            if not (kind=="enemy" and db.pvp.enemies or kind=="ally" and db.pvp.friends) then
                local frame=C.ResolveColor(db,kind,"border","MAGE",faction,false)
                if frame then border:SetBackdropBorderColor(unpack(frame)); border:Show() end
            end
        elseif special then
            if db[subject] then api.Paint(classic,bar,subject,rgb,60,rank,db.scale,"Hermandad de muestra",{compact=scenario=="compact",control=scenario=="control"}) end
        else
            local name=C.ResolveColor(db,subject,"name","MAGE",faction,false)
            local frame=C.ResolveColor(db,subject,"border","MAGE",faction,false)
            sample.name:SetTextColor(unpack(name or {1,1,1}))
            if frame then border:SetBackdropBorderColor(unpack(frame)); border:Show() end
        end
    end
    O.redraw=redraw
    O.select=function(section)
        if not pages[section] then section="general" end
        page=section; popup:Hide(); armed=nil; reset:SetText("Restaurar esta sección")
        for i,key in ipairs(sections) do pages[key]:SetShown(key==page); if key==page then PanelTemplates_SetTab(panel,i) end end
        scroll:SetScrollChild(pages[page]); scroll:SetVerticalScroll(0)
        preview:SetShown(page~="general")
        scroll:ClearAllPoints(); scroll:SetPoint("TOPLEFT",20,page=="general" and -110 or -340); scroll:SetPoint("BOTTOMRIGHT",-45,45)
        redraw()
    end
    panel:SetScript("OnShow",redraw); panel:SetScript("OnHide",function() popup:Hide(); armed=nil; reset:SetText("Restaurar esta sección") end)
    local elapsed=0
    panel:SetScript("OnUpdate",function(_,dt) elapsed=elapsed+dt; if elapsed>.25 then elapsed=0; drawStatus() end end)
    O.category=Settings.RegisterCanvasLayoutCategory(panel,"TisteltiPlates")
    -- Native AddOns navigation exposes this task directly, without a slash command.
    if Settings.RegisterCanvasLayoutSubcategory then
        local shortcuts=CreateFrame("Frame")
        text(shortcuts,"Alitas y mazmorras",20,-20,"GameFontNormalLarge")
        text(shortcuts,"Configura dónde aparecen las alitas y qué estilos las muestran. Estos ajustes son los mismos que en General y Apariencia.",20,-52)
        local nativeScroll=CreateFrame("ScrollFrame",nil,shortcuts,"UIPanelScrollFrameTemplate")
        nativeScroll:SetPoint("TOPLEFT",20,-100); nativeScroll:SetPoint("BOTTOMRIGHT",-45,50)
        local content=CreateFrame("Frame",nil,nativeScroll); content:SetSize(550,720)
        nativeScroll:SetScrollChild(content)
        local y=-8
        local function row(id,caption,get,set,dependency)
            check(content,"addons."..id,caption,get,set,y,dependency); y=y-34
        end
        row("enabled","Activar TisteltiPlates",function() return db.enabled end,function(v) db.enabled=v end)
        text(content,"Dónde mostrar placas y alitas",12,y,"GameFontNormal"); y=y-26
        for _,key in ipairs({"world","party","raid","pvp","arena"}) do
            local scope=key
            row("scopes."..scope,scope=="pvp" and "Campos de batalla" or scope=="raid" and "Bandas" or labels[scope],
                function() return db.scopes[scope] end,function(v) db.scopes[scope]=v end)
        end
        text(content,"Alitas en el modo solo nombres de WoW",12,y,"GameFontNormal"); y=y-26
        row("wings.dungeonGuildOnly","En mazmorras, alitas solo para mi hermandad",function() return db.wings.dungeonGuildOnly end,function(v) db.wings.dungeonGuildOnly=v end)
        row("namesOnlyWings","Mostrar alitas junto al nombre",function() return db.namesOnlyWings end,function(v) db.namesOnlyWings=v end)
        for _,key in ipairs({"group","raid","guild"}) do
            local style=key
            row("style."..style,"Activar estilo · "..labels[style],function() return db[style] end,function(v) db[style]=v end)
            row("mini."..style,"Mostrar alitas · "..labels[style],function() return db.mini[style] end,function(v) db.mini[style]=v end,
                function() return db.namesOnlyWings and db[style] end)
        end
        text(content,"Activa el lugar, el estilo y sus alitas. Si coinciden grupo y hermandad, se respeta la prioridad elegida en Apariencia. El modo solo nombres se activa en las opciones de placas de WoW.",12,y)
        content:SetHeight(-y+70)
        local example=CreateFrame("Button",nil,shortcuts,"UIPanelButtonTemplate")
        example:SetPoint("BOTTOMLEFT",20,12); example:SetSize(330,26)
        example:SetText("Ver ejemplo y configurar apariencia")
        example:SetScript("OnClick",function() subject="group"; scenario="names"; O.Open("appearance") end)
        remember("addons.preview",example)
        shortcuts:SetScript("OnShow",redraw)
        O.namesCategory=Settings.RegisterCanvasLayoutSubcategory(O.category,shortcuts,"Alitas y mazmorras")
    end
    Settings.RegisterAddOnCategory(O.category)
    if TisteltiPlatesPvP then TisteltiPlatesPvP.category=O.category end
    O.select("general")
end
