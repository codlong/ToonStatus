local addon_name, addon = ...
local _debug = false

local frame  = CreateFrame("Frame", "ToonStatusFrame", UIParent)
frame.width  = 750
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
--local myfont = CreateFont("ToonStatusDialog")
--myfont:SetFont("Interface\\Addons\\toon_status\\FiraMono-Medium.ttf", 12)

local messageFrame = CreateFrame("ScrollingMessageFrame", nil, frame)
messageFrame:SetPoint("CENTER", 15, 20)
messageFrame:SetSize(frame.width, frame.height - 50)
messageFrame:SetFontObject(GameFontNormal) 
messageFrame:SetTextColor(1, 1, 1, 1) -- default color
messageFrame:SetJustifyH("LEFT")
messageFrame:SetHyperlinksEnabled(true)
messageFrame:SetFading(false)
messageFrame:SetMaxLines(500)
frame.messageFrame = messageFrame

-------------------------------------------------------------------------------
-- Scroll bar
-------------------------------------------------------------------------------
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
 
function OnEvent(self, event, arg1, ...)
    if _debug then TS_ChatMessage(event) end
    if (event == "ADDON_LOADED" and addon_name == arg1) then
      -- initialize active player list if it doesn't exist
      if (not ToonStatusActivePlayers) then
        ToonStatusActivePlayers = {}
        for player, data in pairs(ToonStatus) do
          table.insert(ToonStatusActivePlayers, player)
        end
      end

      ShowStatusMessage()
    elseif (event == "PLAYER_ENTERING_WORLD") then
      SavePlayerData()
    end
end
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", OnEvent)

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
  elseif (not cmd) then
    TogglePlayerDataWindow()
  else
    TS_ChatMessage(("Unknown command [%s]"):format(cmd))
  end
end

function AddRemoveToons(args)
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

function ShowPlayerDataCSV()
  StaticPopupDialogs["TOON_STATUS_CSV"] = {
    text="Copy CSV output",
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

function TogglePlayerDataWindow()
  if ToonStatusFrame:IsShown() then
    ToonStatusFrame:Hide()
  else
    SavePlayerData()

    table.sort(ToonStatusActivePlayers)

    messageFrame:Clear()
    for i, player in ipairs(ToonStatusActivePlayers) do
      messageFrame:AddMessage(CharacterStatusString(ToonStatus[player]))
    end
    ToonStatusFrame:Show()
  end  
end

function SavePlayerData()
  if _debug then TS_ChatMessage("SavePlayerData") end
  if (not ToonStatus) then
    ToonStatus = {}
  end
  local data = GetPlayerData()
  ToonStatus[data.player_name] = data
  return data.player_name
end

function ShowStatusMessage()
  TS_ChatMessage("Type /ts to see the status of your toons")
end

function CharacterStatusString(data)
  if _debug then TS_ChatMessage("CharacterStatusString") end
  local ret = nil
  if (data) then
    --"%-12s %3d %10.1fg  %-35s %2d %9d %7d %7.0f"
    ret = ("%s %d %.1fg %s level %d resources %d argunite %d ilvl %d\n"):format(
      nvl(data.player_name, "UNKNOWN"), 
      nvl(data.player_level, 0),
      nvl(data.copper, 0)/10000, 
      nvl(data.artifact_name, "NO ARTIFACT"),
      nvl(data.artifact_level, 0),
      nvl(data.order_resources, 0),
      nvl(data.veiled_argunite, 0),
      nvl(data.ilvl, 0)
    )
  end
  return ret 
end

function CharacterStatusCSVString(data)
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

function nvl(val, alt)
  local ret
  if (val) then
    ret = val
  else
    ret = alt
  end
  return ret
end

--[[
  Returns interesting player data:
  player_name
  copper
  artifact_name
  artifact_level
  order_resources
  veiled_argunite
--]]
function GetPlayerData()
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

function TS_ChatMessage(msg)
  local appName = "Toon Status"
  print(("%s: %s"):format(appName, msg))
end
