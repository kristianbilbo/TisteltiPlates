-- Configuration only; rendering and frame lifecycle stay in their own modules.
TisteltiPlatesOptions = {}
function TisteltiPlatesOptions.Register(db, api)
    local Refresh, FrameBorder, Ornament, Paint, Safe = api.Refresh, api.FrameBorder, api.Ornament, api.Paint, api.Safe
    local WHITE, SILVER = api.WHITE, api.SILVER
    if not Settings or not Settings.RegisterCanvasLayoutCategory then return end
    local panel = CreateFrame("Frame")
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -20); title:SetText("TisteltiPlates")
    local tab, style, rank = "group", "group", 0
    local color = RAID_CLASS_COLORS.MAGE
    local bar = CreateFrame("StatusBar", nil, panel)
    bar:SetPoint("TOPLEFT", 100, -465); bar:SetSize(180, 19)
    bar:SetStatusBarTexture(WHITE); bar:SetMinMaxValues(0, 100); bar:SetValue(78)
    bar:SetStatusBarColor(color.r, color.g, color.b)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(.025,.035,.07,1)
    local name = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("LEFT", 5, 0)
    local art = Ornament(bar)
    local plainBorder = FrameBorder(bar, 14, false)
    plainBorder:SetPoint("TOPLEFT", bar, "TOPLEFT", -5, 5)
    plainBorder:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 5, -5)
    local previewBox = FrameBorder(panel, 12, true)
    previewBox:SetPoint("TOPLEFT", 20, -400); previewBox:SetSize(460, 150)
    previewBox:SetFrameLevel(panel:GetFrameLevel()+1)
    bar:SetFrameLevel(previewBox:GetFrameLevel()+1)
    local caption = previewBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    caption:SetPoint("TOPLEFT",16,-14)
    local note = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    note:SetPoint("TOPLEFT",20,-108); note:SetWidth(460); note:SetJustifyH("LEFT"); note:SetWordWrap(true)
    local labels = {group="Grupo", groupFirst="Grupo/Banda", raid="Banda", guild="Hermandad", ally="Aliados", enemy="Enemigos",
        oroazul="Oro y azul", oro="Oro", plata="Plata", clase="Clase", rango="Por rango", color="Color personalizado",
        cobre="Cobre", bronce="Bronce", platino="Platino", zafiro="Zafiro", esmeralda="Esmeralda", amatista="Amatista", rubi="Rubí",
        animales="Animales de la Alianza", on="Activado", off="Desactivado", [0]="Sin rango"}
    for i=1,14 do labels[i]="Rango "..i end
    local menus, controls, tabs, updates = {}, {}, {}, {}
    local redraw
    local function control(widget, scope)
        controls[#controls+1]={widget=widget,scope=scope}
        return widget
    end
    local function decorated() return tab == "group" or tab == "guild" end
    local popup = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    popup:SetFrameStrata("TOOLTIP"); popup:EnableMouse(true)
    popup:SetBackdrop({bgFile=WHITE}); popup:SetBackdropColor(.035,.045,.07,1); popup:Hide()
    local rows = {}
    local function dropdown(x,y,label,choices,get,set,scope)
        local button=control(CreateFrame("Button",nil,panel,"UIPanelButtonTemplate"),scope or "decorated")
        button:SetSize(220,26); button:SetPoint("TOPLEFT",x,y)
        button.caption,button.read=label,get; menus[#menus+1]=button
        button:SetNormalFontObject(GameFontHighlight)
        local heading=control(panel:CreateFontString(nil,"OVERLAY","GameFontNormal"),scope or "decorated")
        heading:SetPoint("BOTTOMLEFT",button,"TOPLEFT",2,5); heading:SetText(label)
        button:SetScript("OnClick",function()
            if popup:IsShown() and popup.owner==button then popup:Hide(); return end
            popup.owner=button; popup:ClearAllPoints(); popup:SetPoint("TOPLEFT",button,"BOTTOMLEFT")
            popup:SetSize(220,#choices*22+4)
            for _,row in ipairs(rows) do row:Hide() end
            for i,value in ipairs(choices) do
                local choice=value
                local row=rows[i] or CreateFrame("Button",nil,popup,"UIPanelButtonTemplate")
                rows[i]=row; row:SetSize(216,22); row:SetPoint("TOPLEFT",2,-2-(i-1)*22)
                row:SetText(labels[choice]); row:SetScript("OnClick",function()
                    set(choice); popup:Hide(); Refresh(); redraw()
                end); row:Show()
            end
            popup:Show()
        end)
    end
    local function check(x,y,text,get,set,scope)
        local button=control(CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate"),scope)
        button:SetSize(26,26); button:SetPoint("TOPLEFT",x,y)
        local label=button:CreateFontString(nil,"OVERLAY","GameFontNormal")
        label:SetPoint("LEFT",button,"RIGHT",4,0); label:SetText(text)
        local function update() button:SetChecked(get()) end
        updates[#updates+1]=update
        button:SetScript("OnShow",update)
        button:SetScript("OnClick",function(self) set(self:GetChecked() and true or false); Refresh(); redraw() end)
        return button
    end
    local function colorButton(x,y,text,get,set,scope)
        local button=control(CreateFrame("Button",nil,panel,"UIPanelButtonTemplate"),scope)
        button:SetSize(220,26); button:SetPoint("TOPLEFT",x,y)
        button:SetNormalFontObject(GameFontHighlight)
        local swatch=button:CreateTexture(nil,"OVERLAY")
        swatch:SetSize(14,14); swatch:SetPoint("RIGHT",-12,0)
        updates[#updates+1]=function()
            local rgb=get()
            swatch:SetColorTexture(rgb[1],rgb[2],rgb[3],1)
            button:SetText(text)
        end
        button:SetScript("OnClick",function()
            local picker=ColorPickerFrame
            if not picker then return end
            -- Capture this tab's setting so switching tabs cannot edit another one.
            local rgb=get()
            local apply,restore=set()
            local original={rgb[1],rgb[2],rgb[3]}
            local function changed()
                local r,g,b=picker:GetColorRGB(); apply({r,g,b}); Refresh(); redraw()
            end
            local function cancel()
                if restore then restore() else apply(original) end
                Refresh(); redraw()
            end
            picker:Hide()
            if picker.SetupColorPickerAndShow then
                picker:SetupColorPickerAndShow({r=rgb[1],g=rgb[2],b=rgb[3],hasOpacity=false,
                    swatchFunc=changed,cancelFunc=cancel})
            else
                picker.hasOpacity=false; picker.func=changed; picker.cancelFunc=cancel
                picker:SetColorRGB(rgb[1],rgb[2],rgb[3]); picker:Show()
            end
        end)
    end
    panel.Tabs = {}
    for i,key in ipairs({"guild","group","ally","enemy"}) do
        local kind=key
        local button=CreateFrame("Button",nil,panel,"PanelTopTabButtonTemplate")
        button:SetID(i); panel.Tabs[i]=button
        button:SetNormalFontObject(GameFontNormal)
        button:SetHighlightFontObject(GameFontHighlight)
        button:SetDisabledFontObject(GameFontHighlight)
        button:SetText(labels[kind]); PanelTemplates_TabResize(button,14,nil,100)
        if i==1 then button:SetPoint("TOPLEFT",20,-60)
        else button:SetPoint("LEFT",panel.Tabs[i-1],"RIGHT",2,0) end
        tabs[kind]=i
        button:SetScript("OnClick",function()
            tab=kind
            if kind=="guild" then style="guild" elseif kind=="group" and style=="guild" then style="group" end
            popup:Hide(); redraw()
            if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB) end
        end)
    end
    PanelTemplates_SetNumTabs(panel,4)
    dropdown(20,-185,"Estilo",{"group","raid"},function() return style end,function(v) style=v end,"group")
    dropdown(250,-185,"Mostrar",{"on","off"},function() return db[style] and "on" or "off" end,function(v) db[style]=v=="on" end)
    dropdown(20,-245,"Borde",{"oroazul","oro","plata","cobre","bronce","platino","zafiro","esmeralda","amatista","rubi","clase","rango","color"},
        function() return db.appearance[style].border end,function(v) db.appearance[style].border=v end)
    dropdown(250,-305,"Ejemplo mérito",{0,1,2,3,4,5,6,7,8,9,10,11,12,13,14},function() return rank end,function(v) rank=v end)
    dropdown(250,-245,"Prioridad",{"groupFirst","guild"},function() return db.priority=="group" and "groupFirst" or "guild" end,
        function(v) db.priority=v=="groupFirst" and "group" or "guild" end)
    colorButton(20,-305,"Color del borde",function() return db.appearance[style].color end,function()
        local config=db.appearance[style]
        local oldMode,oldColor=config.border,config.color
        -- Selecting a color opts into the existing custom RGB border mode.
        return function(rgb) config.color=rgb; config.border="color" end,
            function() config.color=oldColor; config.border=oldMode end
    end,"decorated")
    check(20,-350,"Ocultar ala derecha al mostrar controles",function() return db.hideRightWingOnCC~=false end,
        function(v) db.hideRightWingOnCC=v end,"decorated")
    local function playerConfig() return db.playerColors[tab=="enemy" and "enemy" or "ally"] end
    check(20,-185,"Colorear nombre",function() return playerConfig().name end,function(v) playerConfig().name=v end,"players")
    check(20,-245,"Colorear borde",function() return playerConfig().border end,function(v) playerConfig().border=v end,"players")
    for i,key in ipairs({"nameColor","borderColor"}) do
        local field=key
        colorButton(250,-185-(i-1)*60,i==1 and "Color del nombre" or "Color del borde",
            function() return playerConfig()[field] end,function()
                local config=playerConfig()
                return function(rgb) config[field]=rgb end
            end,"players")
    end
    check(280,-14,"Activar TisteltiPlates",function() return db.enabled end,function(v) db.enabled=v end,"all")
    redraw=function()
        local special=decorated()
        PanelTemplates_SetTab(panel,tabs[tab])
        for _,entry in ipairs(controls) do
            entry.widget:SetShown(entry.scope=="all" or entry.scope==tab or (entry.scope=="decorated" and special) or (entry.scope=="players" and not special))
        end
        for _,update in ipairs(updates) do update() end
        for _,menu in ipairs(menus) do menu:SetText(labels[menu.read()]) end
        caption:SetText("Vista previa · "..labels[special and style or tab])
        if special then
            plainBorder:Hide(); bar:SetShown(db[style]); name:SetText("Mago de muestra"); name:SetTextColor(1,1,1)
            Paint(art,bar,style,color,60,rank,db.scale,Safe(GetGuildInfo,"player") or "Hermandad de muestra")
            note:SetText("Elige el aspecto de estas placas. Prioridad decide qué estilo usar cuando coinciden grupo y hermandad.")
        else
            art:Hide(); bar:Show()
            local config=playerConfig()
            name:SetText(tab=="enemy" and "Jugador enemigo" or "Jugador aliado")
            name:SetTextColor(unpack(config.name and config.nameColor or {1,1,1}))
            plainBorder:Show(); plainBorder:SetBackdropBorderColor(unpack(config.border and config.borderColor or SILVER))
            note:SetText(tab=="enemy" and "Jugadores enemigos de tu personaje, tanto si juegas Alianza como Horda."
                or "Otros jugadores aliados. Grupo y hermandad conservan sus propios estilos.")
        end
    end
    panel:SetScript("OnShow",redraw)
    panel:SetScript("OnHide",function() popup:Hide() end)
    local category=Settings.RegisterCanvasLayoutCategory(panel,"TisteltiPlates")
    Settings.RegisterAddOnCategory(category)
    if TisteltiPlatesPvP then TisteltiPlatesPvP.RegisterOptions(category,Refresh) end
    redraw()
end
