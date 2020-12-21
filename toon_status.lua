--
-- ToonStatus: Keep track of interesting resource stats across toons
--
local addon_name, addon = ...

--
-- Set to true for debug chat messages
--
local _debug = false

--
-- Resources to track. These are the names the "stat" command recognizes
--
-- Names stored in WTF
local resourceNames = {
    ["level"] = "player_level",
    ["ilvl"] = "ilvl",
    ["gold"] = "copper",
    ["soul_ash"] = "soul_ash",
    ["anima"] = "anima",
    ["stygia"] = "stygia"
}

-- Labels for display
local resourceLabels = {
    ["level"] = "Level",
    ["ilvl"] = "iLvl",
    ["gold"] = "Gold",
    ["soul_ash"] = "Soul Ash",
    ["anima"] = "Anima",
    ["stygia"] = "Stygia"
}

-- Sort order
local resourceOrder = {"level", "ilvl", "gold", "soul_ash", "anima", "stygia"}

-- Track totals across Toons
local resourceTotals = {"gold", "soul_ash", "anima", "stygia"}

local knownResources = {}
for k, v in pairs(resourceNames) do
    table.insert(knownResources, k)
end

local resourceSort = "ilvl"
--
-- WOW Events to monitor
--
local toonEvents = {
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_MONEY",
    "CURRENCY_DISPLAY_UPDATE",
    "ARTIFACT_UPDATE"
}

--
-- Create our main dialog frame
--
local frame  = CreateFrame("Frame", "ToonStatusFrame", UIParent,  BackdropTemplateMixin and "BackdropTemplate")
frame.width  = 700
frame.height = 400
frame:SetFrameStrata("FULLSCREEN_DIALOG")
frame:SetSize(frame.width, frame.height)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile     = true,
    tileSize = 32,
    edgeSize = 32,
    insets   = { left = 8, right = 8, top = 8, bottom = 8 }
})
frame:SetBackdropColor(0, 0, 0, 1)
frame:EnableMouse(true)
frame:EnableMouseWheel(true)

-- Make movable/resizable
frame:SetMovable(true)
frame:SetResizable(enable)
frame:SetMinResize(100, 100)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

tinsert(UISpecialFrames, "ToonStatusFrame")

-- Close button
local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
closeButton:SetPoint("BOTTOM", 0, 10)
closeButton:SetHeight(25)
closeButton:SetWidth(70)
closeButton:SetText(CLOSE)
closeButton:SetScript("OnClick", function(self)
    HideParentPanel(self)
end)
frame.closeButton = closeButton

-- ScrollingMessageFrame
local myfont = CreateFont("ToonStatusDialog")
myfont:SetFont("Interface\\Addons\\toon_status\\FiraMono-Medium.ttf", 12)

local messageFrame = CreateFrame("ScrollingMessageFrame", nil, frame)
messageFrame:SetPoint("CENTER", 15, 20)
messageFrame:SetSize(frame.width, 50)
messageFrame:SetFontObject(myfont) --(GameFontNormal) 
messageFrame:SetTextColor(1, 1, 1, 1) -- default color
messageFrame:SetJustifyH("LEFT")
messageFrame:SetHyperlinksEnabled(true)
messageFrame:SetFading(false)
messageFrame:SetMaxLines(500)
frame.messageFrame = messageFrame

-- Scroll bar
--local scrollBar = CreateFrame("Slider", nil, frame, "UIPanelScrollBarTemplate")
--scrollBar:SetPoint("RIGHT", frame, "RIGHT", -10, 10)
--scrollBar:SetSize(30, frame.height - 90)
--scrollBar:SetMinMaxValues(0, 9)
--scrollBar:SetValueStep(1)
--scrollBar.scrollStep = 1
--frame.scrollBar = scrollBar

--scrollBar:SetScript("OnValueChanged", function(self, value)
--    messageFrame:SetScrollOffset(select(2, scrollBar:GetMinMaxValues()) - value)
--end)

--scrollBar:SetValue(select(2, scrollBar:GetMinMaxValues()))

--frame:SetScript("OnMouseWheel", function(self, delta)
--    local cur_val = scrollBar:GetValue()
--    local min_val, max_val = scrollBar:GetMinMaxValues()

--    if delta < 0 and cur_val < max_val then
--        cur_val = math.min(max_val, cur_val + 1)
--        scrollBar:SetValue(cur_val)
--    elseif delta > 0 and cur_val > min_val then
--        cur_val = math.max(min_val, cur_val - 1)
--        scrollBar:SetValue(cur_val)
--    end
--end)

frame:Hide()

--
-- Returns val if it is not nil and has a value, alt otherwise
-- 
local function nvl(val, alt)
    local ret
    if (val) then
        ret = val
    else
        ret = alt
    end
    return ret
end

--
-- Display a chat message to the user
--
local function TS_ChatMessage(msg)
    local appName = "Toon Status"
    if (type(msg) == "table") then
        for k, v in pairs(msg) do
            print(("%s: %s: %s"):format(appName, k, tostring(v)))
        end
    else
        print(("%s: %s"):format(appName, msg))
    end
end

--
-- Show the startup usage message to the user
--
local function ShowHelpMessage()
    TS_ChatMessage("/ts to see the status of your toons")
    TS_ChatMessage("/ts toon [add remove] Player (Player2 ...) to add/remove toons from display (names are case-sensitive)")
    TS_ChatMessage("/ts csv to get data in comma-separated values format (just hit ctrl-c to copy to clipboard)")
    
    local resource_string = ""
    for i, stat in ipairs(knownResources) do
        resource_string = resource_string..stat.." "
    end

    TS_ChatMessage("/ts stat ["..resource_string.."] to filter stats (does not persist)")
    TS_ChatMessage("/ts sort [toon "..resource_string.."] to sort the data by the given resource")
    TS_ChatMessage(
        "/ts update to update current player data without displaying anything. Can be used in a macro with /logout to save before exit.")
    TS_ChatMessage("/ts help to display this information")
end

--
--  Returns interesting player resource stats:
--      player_name
--      copper
--      soul_ash
--      anima
--      stygia
--
local function GetPlayerData()
    if _debug then TS_ChatMessage("GetPlayerData") end
    local player_data = {}

    -- Player Name and level
    local player_name, realm = UnitName("player")
    if _debug then TS_ChatMessage("Player " .. nvl(player_name, "UNKNOWN")) end
    player_data.player_name = player_name
    player_data.player_level = UnitLevel("player")

    -- Gold
    player_data.copper = GetMoney()
    if _debug then TS_ChatMessage("Copper " .. nvl(player_data.copper, -1)) end

    -- Interesting Resources
    for i=1,C_CurrencyInfo.GetCurrencyListSize() do
        local currency_info = C_CurrencyInfo.GetCurrencyListInfo(i)
        currency_name = currency_info["name"]
        count = currency_info["quantity"]
        if _debug then TS_ChatMessage("Currency ".. nvl(currency_name, unknown)) end
        if currency_name == "Soul Ash" then
            player_data.soul_ash = count
        elseif currency_name == "Reservoir Anima" then
            player_data.anima = count
        elseif currency_name == "Stygia" then
            player_data.stygia = count
        end
    end

    -- Item Level
    local overall, equipped = GetAverageItemLevel()
    if _debug then TS_ChatMessage("ilvl " .. nvl(equipped, -1)) end
    player_data.ilvl = equipped
    return player_data
end

--
-- Save player data to the saved variable
--
local function SavePlayerData()
    if _debug then TS_ChatMessage("SavePlayerData") end
    if (not ToonStatus) then
        ToonStatus = {}
    end
    local data = GetPlayerData()
    ToonStatus[data.player_name] = data
    return data.player_name
end

--
-- Add-on event handler
--
local function OnEvent(self, event, arg1, ...)
    if _debug then TS_ChatMessage(event) end
    if (event == "ADDON_LOADED") then
        if (addon_name == arg1) then
            -- initialize active player list if it doesn't exist
            if (not ToonStatusActivePlayers) then
                ToonStatusActivePlayers = {}
                for player, data in pairs(ToonStatus) do
                    table.insert(ToonStatusActivePlayers, player)
                end
            end
            TS_ChatMessage("/ts help to see options")
        end
    elseif (event == "PLAYER_ENTERING_WORLD") then
        SavePlayerData()
    end
end

--
-- Register for the events we care about
--
for i, eventName in ipairs(toonEvents) do
    frame:RegisterEvent(eventName)
end

frame:SetScript("OnEvent", OnEvent)

--
-- Return whether the item is in the list
--
local function IsInList(item, list)
    if (list) then
        for i, j in ipairs(list) do
            if (item == j) then
                return true
            end 
        end
    end
    return false
end

--
-- Return header string for the resources requested
--
local function ResourceHeaderString(resources)
    if (_debug) then TS_ChatMessage(resources) end
    if (not resources) then
        resources = knownResources
    end
    local ret = ("%-12s"):format("Toon")
    if (IsInList("level", resources)) then
        ret = ret..("%6s"):format("Level")
    end
    if (IsInList("gold", resources)) then
        ret = ret..("%13s"):format("Gold")
    end
    if (IsInList("soul_ash", resources)) then
        ret = ret..("%10s"):format("Soul Ash")
    end
    if (IsInList("anima", resources)) then
        ret = ret..("%9s"):format("Anima")
    end
    if (IsInList("stygia", resources)) then
        ret = ret..("%9s"):format("Stygia")
    end
    if (IsInList("ilvl", resources)) then
        ret = ret..("%7s"):format("iLvl")
    end

    return ret.."\n\n"
end

-- from sam_lie
-- Compatible with Lua 5.0 and 5.1.
-- Disclaimer : use at own risk especially for hedge fund reports :-)

---============================================================
-- add comma to separate thousands
-- 
local function comma_value(amount)
    local formatted = amount
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k==0) then
            break
        end
    end
    return formatted
end

---============================================================
-- rounds a number to the nearest decimal places
--
function round(val, decimal)
    if (decimal) then
      return math.floor( (val * 10^decimal) + 0.5) / (10^decimal)
    else
      return math.floor(val+0.5)
    end
  end

--
-- Return a display string for the resources requested
--
local function CharacterStatusString(data, resources)
    if _debug then TS_ChatMessage("CharacterStatusString") end
    if (not resources) then
        resources = knownResources
    end

    local ret = nil

    if (data) then
        ret = ("%-12s"):format(nvl(data.player_name, "UNKNOWN"))
        if (IsInList("level", resources)) then
            ret = ret .. ("%6d"):format(nvl(data.player_level, 0))
        end
        if (IsInList("gold", resources)) then
            ret = ret .. ("%13s"):format(comma_value(round(nvl(data.copper, 0)/10000, 0)))
        end
        if (IsInList("soul_ash", resources)) then
            ret = ret .. ("%10s"):format(comma_value(nvl(data.soul_ash, 0)))
        end
        if (IsInList("anima", resources)) then
            ret = ret .. ("%9s"):format(comma_value(nvl(data.anima, 0)))
        end
        if (IsInList("stygia", resources)) then
            ret = ret .. ("%9s"):format(comma_value(nvl(data.stygia, 0)))
        end
        if (IsInList("ilvl", resources)) then
            ret = ret .. ("%7.1f"):format(nvl(data.ilvl, 0.0))
        end
    end
    return ret 
end

--
-- Return a display string for total resources
--
local function StatTotalsString(resources)
    local total_copper = 0
    local total_soul_ash = 0
    local total_anima = 0
    local total_stygia = 0

    if (not resources) then
        resources = knownResources
    end
    for player, stats in pairs(ToonStatus) do
        if (IsInList(player, ToonStatusActivePlayers)) then
            total_copper = total_copper + nvl(stats.copper, 0)
            total_soul_ash = total_soul_ash + nvl(stats.soul_ash, 0)
            total_anima = total_anima + nvl(stats.anima, 0)
            total_stygia = total_stygia + nvl(stats.stygia, 0)
       end
    end

    local ret = ("\n\n%-12s"):format("Totals")
    if (IsInList("level", resources)) then
        ret = ret..("%6s"):format("")
    end
    if (IsInList("gold", resources)) then
        ret = ret..("%13s"):format(comma_value(round(total_copper/10000, 0)))
    end
    if (IsInList("soul_ash", resources)) then
        ret = ret..("%10d"):format(total_soul_ash)
    end
    if (IsInList("anima", resources)) then
        ret = ret..("%9d"):format(total_anima)
    end
    if (IsInList("stygia", resources)) then
        ret = ret..("%9d"):format(total_stygia)
    end

    return ret
end


--
-- Add or remove toon handler
--
local function AddRemoveToons(args)
    local toon_cmd
    for arg in string.gmatch(args, "%S+") do
        if (not toon_cmd) then
            toon_cmd = arg
        elseif (toon_cmd == "remove" or toon_cmd == "r") then
            for i, player in ipairs(ToonStatusActivePlayers) do
                if (player == arg) then
                    table.remove(ToonStatusActivePlayers, i)
                end
            end
        elseif (toon_cmd == "add" or toon_cmd == 'a') then
            for i, player in ipairs(ToonStatusActivePlayers) do
                if (player == arg) then
                    TS_ChatMessage("Toon is already active")
                    return
                end
            end
            table.insert(ToonStatusActivePlayers, arg)
        else
            TS_ChatMessage(("Unknown toon command %s. Usage: /ts toon [add remove] Player (Player2 ...)"):format(toon_cmd))
            break
        end
    end
    local toons = "Active players: "
    for i, player in ipairs(ToonStatusActivePlayers) do
        toons = toons .. player .. " "
    end
    TS_ChatMessage(toons)
end

local function GetColumn(columnName)
    return {
        ["name"] = columnName,
        ["width"] = 75,
        ["align"] = "RIGHT",
        ["color"] = { 
            ["r"] = 0.5, 
            ["g"] = 0.5, 
            ["b"] = 1.0, 
            ["a"] = 1.0 
        },
        ["colorargs"] = nil,
        ["bgcolor"] = {
            ["r"] = 0.0, 
            ["g"] = 0.0, 
            ["b"] = 0.0, 
            ["a"] = 0.0 
        }, 
        ["defaultsort"] = "dsc",
        --["sortnext"]= 4,
        --["comparesort"] = function (cella, cellb, columnName)
        --    if cella then
        --        TS_ChatMessage("CELLA")
        --        TS_ChatMessage(cella)
        --    end
        --    if cellb then
        --        TS_ChatMessage("CELLB")
        --        TS_ChatMessage(cellb)
        --    end
        --    TS_ChatMessage(columnName)
        --    return cella.value < cellb.value;
        --end,
        ["DoCellUpdate"] = nil,
    }
end

local function ToonTableData()
    data = {}
    
    for i, player in ipairs(ToonStatusActivePlayers) do
        foo = {}
        table.insert(foo, player)
        for k, v in pairs(resourceNames) do
            val = nvl(ToonStatus[player][v], 0)
            if (v == "copper") then
                val = round(nvl(val, 0)/10000, 0)
            end
            table.insert(foo, val)
        end
        table.insert(data, foo)
    end

    return data
end

local function InitScrollingTable()
    cols = {}
    
    table.insert(cols, GetColumn("Toon"))
    for k, v in ipairs(resourceOrder) do      
        table.insert(cols, GetColumn(resourceLabels[v]))
    end
    
    local ScrollingTable = LibStub("ScrollingTable")
    local statusTable = ScrollingTable:CreateST(cols, 8, nil, nil, frame)

    statusTable:SetData(ToonTableData(), true)
end

--
-- Show the stat dialog
--
local function ShowPlayerDataWindow(requestedResources, sort)
    -- Add current player if not in active list
    local current_toon = UnitName("player")
    if (not IsInList(current_toon, ToonStatusActivePlayers)) then
        AddRemoveToons("add "..current_toon)
    end

    SavePlayerData()

    if ((not sort) or (sort == "toon")) then
        table.sort(ToonStatusActivePlayers)
    elseif (IsInList(sort, knownResources)) then
        table.sort(ToonStatusActivePlayers, 
        function (a,b) 
            -- Sort first by resource
            resource_a = nvl(ToonStatus[a][resourceNames[sort]], 0)
            resource_b = nvl(ToonStatus[b][resourceNames[sort]], 0)
            if (not resource_a and not resource_b) then
                return false 
            -- Then by player name
            elseif (resource_a == resource_b) then
                resource_a = b
                resource_b = a           
            end
            return resource_a > resource_b 
        end)
    end

    InitScrollingTable()
    messageFrame:Clear()
    --messageFrame:AddMessage(ResourceHeaderString(requestedResources))
    --for i, player in ipairs(ToonStatusActivePlayers) do
    --    messageFrame:AddMessage(CharacterStatusString(ToonStatus[player], requestedResources))
    --end
    messageFrame:AddMessage(StatTotalsString(requestedResources))
    ToonStatusFrame:Show()
end

--
-- Toggle the stat dialog
--
local function TogglePlayerDataWindow()
    if ToonStatusFrame:IsShown() then
        ToonStatusFrame:Hide()
    else
        ShowPlayerDataWindow(knownResources, resourceSort)
    end  
end

--
-- Return a csv string for the given data
--
local function CharacterStatusCSVString(data)
    if _debug then TS_ChatMessage("CharacterStatusString") end
    return ("%s,%d,%.0f,%d,%d,%d,%d"):format(
        nvl(data.player_name, "UNKNOWN"), 
        nvl(data.player_level, 0),
        nvl(data.copper, 0), 
        nvl(data.soul_ash, 0),
        nvl(data.anima, 0),
        nvl(data.stygia, 0),
        nvl(data.ilvl, 0)
    )
end

--
-- Show the csv dialog
--
local function ShowPlayerDataCSV()
    StaticPopupDialogs["TOON_STATUS_CSV"] = {
        text = "Copy CSV output",
        button1 = CANCEL,
        OnCancel = function()
            StaticPopup_Hide ("TOON_STATUS_CSV")
        end,
        OnShow = function (self, data)
            self.editBox:SetMultiLine()
            local now = date("%m/%d/%y %H:%M:%S",time())
            self.editBox:Insert("player,player_level,copper,soul_ash,anima,stygia,ilvl,timestamp\n")
            for i, player in ipairs(ToonStatusActivePlayers) do
            self.editBox:Insert(("%s,%s\n"):format(CharacterStatusCSVString(ToonStatus[player]), now))
            end
            self.editBox:HighlightText()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        hasEditBox = true,
        preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
    }
    StaticPopup_Show ("TOON_STATUS_CSV")
end

--
-- Return whether r is a known resource
--
local function IsKnownResource(r)
    return IsInList(r, knownResources)
end

--
-- Show the stat dialog for the requested resources
--
local function ShowResourceValue(args)
    local requestedResources = {}
    for arg in string.gmatch(args, "%S+") do
        arg = string.lower(arg)
        if IsKnownResource(arg) then
            table.insert(requestedResources, arg)
        else
            TS_ChatMessage("Unknown resource "..arg)
        end
    end
    ShowPlayerDataWindow(requestedResources, resourceSort)
end

--
-- Set the sort value
--
local function SetSortValue(args)
    for arg in string.gmatch(args, "%S+") do
        arg = string.lower(arg)
        if (arg == "toon" or IsInList(arg, knownResources)) then
            resourceSort = arg
        else
            TS_ChatMessage("Unknown sort value "..arg)
        end
        break
    end
    TS_ChatMessage("Sort value is "..resourceSort)
    ShowPlayerDataWindow(knownResources, resourceSort)
end

--
-- Slash command
--
SLASH_TOON_STATUS1 = "/ts"
SlashCmdList["TOON_STATUS"] = function(msg)
    local _, _, cmd, args = string.find(msg, "%s?(%w+)%s?(.*)")
    if (cmd) then 
        cmd = string.lower(cmd) 
        if (cmd == "csv") then
            SavePlayerData()
            ShowPlayerDataCSV()
        elseif (cmd == "toon") then
            AddRemoveToons(args)
        elseif (cmd == "stat") then
            ShowResourceValue(args)
        elseif (cmd == "help") then
            ShowHelpMessage()
        elseif (cmd == "update") then
            SavePlayerData()
            TS_ChatMessage("Player data saved")
        elseif (cmd == "sort") then
            SetSortValue(args)      
        elseif (cmd == "tt") then
            TestTable(args)   
        else
            TS_ChatMessage(("Unknown command [%s]"):format(cmd))
        end
    else
        TogglePlayerDataWindow()
    end
end
