-- Native tab semantics used by the headless settings tests.
PanelTemplates_TabResize=function(tab,padding,absolute,minWidth)
    assert(tab.template=="PanelTopTabButtonTemplate", "Settings must use native WoW tabs")
    tab:SetWidth(absolute or minWidth or 100)
end
PanelTemplates_SetNumTabs=function(panel,count)
    assert(#panel.Tabs==count)
    panel.numTabs=count
end
PanelTemplates_SetTab=function(panel,index)
    assert(panel.Tabs[index])
    panel.selectedTab=index
    for i,tab in ipairs(panel.Tabs) do tab.selected=i==index end
end
