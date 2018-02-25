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
local knownResources = {
    "level",
    "gold",
    "artifact",
    "resources",
    "argunite",
    "ilvl"
}

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
local frame  = CreateFrame("Frame", "ToonStatusFrame", UIParent)
frame.width  = 850
frame.height = 250
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
messageFrame:SetSize(frame.width, frame.height - 50)
messageFrame:SetFontObject(myfont) --(GameFontNormal) 
messageFrame:SetTextColor(1, 1, 1, 1) -- default color
messageFrame:SetJustifyH("LEFT")
messageFrame:SetHyperlinksEnabled(true)
messageFrame:SetFading(false)
messageFrame:SetMaxLines(500)
frame.messageFrame = messageFrame

-- Scroll bar
local scrollBar = CreateFrame("Slider", nil, frame, "UIPanelScrollBarTemplate")
scrollBar:SetPoint("RIGHT", frame, "RIGHT", -10, 10)
scrollBar:SetSize(30, frame.height - 90)
scrollBar:SetMinMaxValues(0, 9)
scrollBar:SetValueStep(1)
scrollBar.scrollStep = 1
frame.scrollBar = scrollBar

scrollBar:SetScript("OnValueChanged", function(self, value)
    messageFrame:SetScrollOffset(select(2, scrollBar:GetMinMaxValues()) - value)
end)

scrollBar:SetValue(select(2, scrollBar:GetMinMaxValues()))

frame:SetScript("OnMouseWheel", function(self, delta)
    local cur_val = scrollBar:GetValue()
    local min_val, max_val = scrollBar:GetMinMaxValues()

    if delta < 0 and cur_val < max_val then
        cur_val = math.min(max_val, cur_val + 1)
        scrollBar:SetValue(cur_val)
    elseif delta > 0 and cur_val > min_val then
        cur_val = math.max(min_val, cur_val - 1)
        scrollBar:SetValue(cur_val)
    end
end)

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
            print(("%s: %s: %s"):format(appName, k, v))
        end
    else
        print(("%s: %s"):format(appName, msg))
    end
end

--
-- Show the startup usage message to the user
--
local function ShowStatusMessage()
    TS_ChatMessage("/ts to see the status of your toons")
    TS_ChatMessage("/ts toon [add remove] player1 ... playern to add/remove toons from display" )
    local msg = "/ts stat ["
    for i, stat in ipairs(knownResources) do
        msg = msg..stat.." "
    end
    msg = msg.."] to filter stats"
    TS_ChatMessage(msg)
end

--
--  Returns interesting player resource stats:
--      player_name
--      copper
--      artifact_name
--      artifact_level
--      order_resources
--      veiled_argunite
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

    -- Artifact Info
    local itemID, altItemID, artifact_name, icon, xp, pointsSpent, quality, artifactAppearanceID, appearanceModID, itemAppearanceID, altItemAppearanceID, altOnTop, artifactTier = C_ArtifactUI.GetEquippedArtifactInfo()
    if _debug then TS_ChatMessage("Artifact " .. nvl(itemID, -1)) end
    player_data.artifact_name = artifact_name
    player_data.artifact_level = pointsSpent

    -- Interesting Resources
    for i=1,GetCurrencyListSize() do
        local currency_name, isHeader, isExpanded, isUnused, isWatched, count, extraCurrencyType, icon, itemID = GetCurrencyListInfo(i)
        if _debug then TS_ChatMessage("Currency ".. nvl(currency_name, unknown)) end
        if currency_name == "Order Resources" then
            player_data.order_resources = count
        elseif currency_name == "Veiled Argunite" then
            player_data.veiled_argunite = count
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
            ShowStatusMessage()
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
    local ret = ("%-12s"):format("Toon")
    if (not resources) then
        resources = knownResources
    end
    if (IsInList("level", resources)) then
        ret = ret..("%-6s"):format("Level")
    end
    if (IsInList("gold", resources)) then
        ret = ret..("%-11s"):format("   Gold")
    end
    if (IsInList("resources", resources)) then
        ret = ret..("%-10s"):format("Resources")
    end
    if (IsInList("argunite", resources)) then
        ret = ret..("%-9s"):format("Argunite")
    end
    if (IsInList("ilvl", resources)) then
        ret = ret..("%-6s"):format(" ilvl")
    end
    if (IsInList("artifact", resources)) then
        ret = ret.." Artifact"
    end
    return ret.."\n\n"
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
            ret = ret .. ("%9.1fg"):format(nvl(data.copper, 0)/10000)
        end
        if (IsInList("resources", resources)) then
            ret = ret .. ("%10d"):format(nvl(data.order_resources, 0))
        end
        if (IsInList("argunite", resources)) then
            ret = ret .. ("     %4d"):format(nvl(data.veiled_argunite, 0))
        end
        if (IsInList("ilvl", resources)) then
            ret = ret .. (" %3.1f"):format(nvl(data.ilvl, 0))
        end
        if (IsInList("artifact", resources)) then
        ret = ret .. ( " %s (%d)"):format(
            nvl(data.artifact_name, "NO ARTIFACT"),
            nvl(data.artifact_level, 0)
        )
        end
    end
    return ret 
end

--
-- Show the stat dialog
--
local function ShowPlayerDataWindow(requestedResources)
    SavePlayerData()
    table.sort(ToonStatusActivePlayers)

    messageFrame:Clear()
    messageFrame:AddMessage(ResourceHeaderString(requestedResources))
    for i, player in ipairs(ToonStatusActivePlayers) do
        messageFrame:AddMessage(CharacterStatusString(ToonStatus[player], requestedResources))
    end
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
    if _debug then TS_ChatMessage("CharacterStatusString") end
    return ("%s,%s,%d,\"%s\",%d,%d,%d,%d"):format(
        nvl(data.player_name, "UNKNOWN"), 
        nvl(data.player_level, 0),
        nvl(data.copper, 0), 
        nvl(data.artifact_name, "NO ARTIFACT"),
        nvl(data.artifact_level, 0),
        nvl(data.order_resources, 0),
        nvl(data.veiled_argunite, 0),
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
            self.editBox:Insert("player,player_level,copper,artifact_name,artifact_level,order_resources,veiled_argunite,ilvl,timestamp\n")
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
            TS_ChatMessage(("Unknown toon command %s. Usage: /ts toon [add|remove] player (player ...)"):format(toon_cmd))
            break
        end
    end
    local toons = "Active players: "
    for i, player in ipairs(ToonStatusActivePlayers) do
        toons = toons .. player .. " "
    end
    TS_ChatMessage(toons)
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

    if (cmd == "csv") then
        SavePlayerData()
        ShowPlayerDataCSV()
    elseif (cmd == "toon") then
        AddRemoveToons(args)
    elseif (cmd == "stat") then
        ShowResourceValue(args)
    elseif (not cmd) then
        TogglePlayerDataWindow()
    else
        TS_ChatMessage(("Unknown command [%s]"):format(cmd))
    end
end
