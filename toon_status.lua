--
-- ToonStatus: Keep track of interesting resource stats across toons
--
local addon_name, addon = ...

--
-- Set to true for debug chat messages
--
local _debug = false

--
-- Resources to track. 
--
-- Names stored in WTF
local resourceNames = {
    ["level"] = "player_level",
    ["ilvl"] = "ilvl",
    ["renown"] = "renown",
    ["gold"] = "copper",
    ["soul_ash"] = "soul_ash",
    ["anima"] = "anima",
    ["stygia"] = "stygia",
    ["adventure"] = "adventure"
}

-- Labels for display
local resourceLabels = {
    ["level"] = "Level",
    ["ilvl"] = "iLvl",
    ["renown"] = "Renown",
    ["gold"] = "Gold",
    ["soul_ash"] = "Soul Ash",
    ["anima"] = "Anima",
    ["stygia"] = "Stygia",
    ["adventure"] = "Adv Prog"
}

-- Sort order
local resourceOrder = {"level", "ilvl", "renown", "gold", "soul_ash", "anima", "stygia", "adventure"}

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
    "CURRENCY_DISPLAY_UPDATE"
}

--
-- Create our main dialog frame
--
local frame  = CreateFrame("Frame", "ToonStatusFrame", UIParent,  BackdropTemplateMixin and "BackdropTemplate")
frame.width  = 750
frame.height = 450
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

-- Title
frame.title = frame:CreateFontString("ToonStatus_Title", "OVERLAY", "GameFontNormal")
frame.title:SetPoint("TOP", 0, -18)
frame.title:SetText("ToonStatus")

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
messageFrame:SetPoint("BOTTOM", 15, 50)
messageFrame:SetSize(frame.width, 50)
messageFrame:SetFontObject(GameFontNormal) --(GameFontNormal) 
messageFrame:SetTextColor(1.0, 0.75, 0.1, 1.0) -- default color
messageFrame:SetJustifyH("LEFT")
messageFrame:SetHyperlinksEnabled(true)
messageFrame:SetFading(false)
messageFrame:SetMaxLines(500)
frame.messageFrame = messageFrame


local ScrollingTable = LibStub("ScrollingTable")
frame.statusTable = nil
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
    TS_ChatMessage(
        "/ts update to update current player data without displaying anything. Can be used in a macro with /logout to save before exit.")
    TS_ChatMessage(
        "Adventure Campaign Progress (Adv Prog) is a new 'currency' that allows you to get better follower missions, and is now tracked.")
    TS_ChatMessage("/ts help to display this information")
end

--
--  Returns interesting player resource stats:
--
local function GetPlayerData()
    if _debug then TS_ChatMessage("GetPlayerData") end
    local player_data = {}

    -- Player Name and level
    local player_name, realm = UnitName("player")
    if _debug then TS_ChatMessage("Player " .. nvl(player_name, "UNKNOWN")) end
    player_data.player_name = player_name
    player_data.player_level = UnitLevel("player")

    -- Renown
    player_data.renown = C_CovenantSanctumUI.GetRenownLevel()

    -- Gold
    player_data.copper = GetMoney()
    if _debug then TS_ChatMessage("Copper " .. nvl(player_data.copper, -1)) end

    -- Adventure Campaign Progress
    local adventure_progress = C_CurrencyInfo.GetCurrencyInfo(1889)
    player_data.adventure = adventure_progress.quantity

    -- Interesting Currency
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
    else
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
-- Return a display string for total resources
--
local function StatTotalsString(resources)
    local total_copper = 0
    local total_soul_ash = 0
    local total_anima = 0
    local total_stygia = 0

    if (not resources) then
        resources = resourceTotals
    end
    for player, stats in pairs(ToonStatus) do
        if (IsInList(player, ToonStatusActivePlayers)) then
            total_copper = total_copper + nvl(stats.copper, 0)
            total_soul_ash = total_soul_ash + nvl(stats.soul_ash, 0)
            total_anima = total_anima + nvl(stats.anima, 0)
            total_stygia = total_stygia + nvl(stats.stygia, 0)
       end
    end

    ret = ""
    if (IsInList("gold", resources)) then
        ret = ret..("Gold: %27s\n"):format(comma_value(round(total_copper/10000, 0)))
    end
    if (IsInList("soul_ash", resources)) then
        ret = ret..("Soul Ash: %25d\n"):format(total_soul_ash)
    end
    if (IsInList("anima", resources)) then
        ret = ret..("Reservoir Anima: %12d\n"):format(total_anima)
    end
    if (IsInList("stygia", resources)) then
        ret = ret..("Stygia: %28d\n"):format(total_stygia)
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

local function GetColumn(columnName, comparesort, sortnext)
    retval = {
        ["name"] = columnName,
        ["width"] = 75,
        ["align"] = "RIGHT",
        ["color"] = { 
            ["r"] = 1.0, 
            ["g"] = 0.75, 
            ["b"] = 0.1, 
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
        --["sortnext"]= 1,
        --["comparesort"] = function (cella, cellb, columnName)
        --end,
        ["DoCellUpdate"] = nil,
    }
    if comparesort then
        retval["comparesort"] = comparesort
    end
    if sortnext then
        retval["sortnext"] = sortnext
    end
    return retval
end

local function ToonTableData()
    data = {}
    
    for i, player in ipairs(ToonStatusActivePlayers) do
        foo = {}
        table.insert(foo, player)
        for k, v in pairs(resourceOrder) do
            val = nvl(ToonStatus[player][resourceNames[v]], 0)
            if (v == "gold") then
                val = comma_value(round(nvl(val, 0)/10000, 0))
            elseif (v == "ilvl") then
                val = ("%.1f"):format(val)
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
        comparesort = nil
        sortnext = nil
        if k ~= "Toon" then
            sortnext = 1
        end
        table.insert(cols, GetColumn(resourceLabels[v], comparesort, sortnext))
    end
    
    if frame.statusTable == nil then        
        frame.statusTable = ScrollingTable:CreateST(cols, 15, nil, nil, frame)
        frame.statusTable.frame:SetPoint("TOP", frame, "TOP", 0, -75)
    end

    frame.statusTable:SetData(ToonTableData(), true)
end

--
-- Show the stat dialog
--
local function ShowPlayerDataWindow(requestedResources)
    -- Add current player if not in active list
    local current_toon = UnitName("player")
    if (not IsInList(current_toon, ToonStatusActivePlayers)) then
        AddRemoveToons("add "..current_toon)
    end

    SavePlayerData()
    InitScrollingTable()
    messageFrame:Clear()
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
        ShowPlayerDataWindow(knownResources)
    end  
end

--
-- Return a csv string for the given data
--
local function CharacterStatusCSVString(data)
    return ("%s,%d,%d,%.0f,%d,%d,%d,%d,%d"):format(
        nvl(data.player_name, "UNKNOWN"), 
        nvl(data.player_level, 0),
        nvl(data.renown, 0),
        nvl(data.copper, 0), 
        nvl(data.soul_ash, 0),
        nvl(data.anima, 0),
        nvl(data.stygia, 0),
        nvl(data.ilvl, 0),
        nvl(data.adventure, 0)
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
            self.editBox:Insert("player,player_level,renown,copper,soul_ash,anima,stygia,ilvl,adventure,timestamp\n")
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
    ShowPlayerDataWindow(requestedResources)
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
        elseif (cmd == "help") then
            ShowHelpMessage()
        elseif (cmd == "update") then
            SavePlayerData()
            TS_ChatMessage("Player data saved")
        else
            TS_ChatMessage(("Unknown command [%s]"):format(cmd))
        end
    else
        TogglePlayerDataWindow()
    end
end
