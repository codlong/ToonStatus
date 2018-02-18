local name, addon = ...
local _toonStatus
local _debug = false

local frame  = CreateFrame("Frame", "ToonStatusFrame", UIParent)
frame.width  = 500
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
    if (event == "ADDON_LOADED" and name == arg1) then
      -- Grab value of the saved variable
      _toonStatus = ToonStatus
      ShowStatusMessage()
    elseif (event == "PLAYER_ENTERING_WORLD") then
      SavePlayerData()
    elseif (event == "PLAYER_LEAVING_WORLD") then 
      ToonStatus = _toonStatus
    end
end
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:SetScript("OnEvent", OnEvent)

--
-- Slash command
--
SLASH_TOON_STATUS1 = "/ts"
SlashCmdList["TOON_STATUS"] = function(cmd)
  if (cmd == "csv") then
    SavePlayerData()

    StaticPopupDialogs["TOON_STATUS_CSV"] = {
      text="Copy CSV output",
      button1 = CANCEL,
      OnCancel = function()
        StaticPopup_Hide ("TOON_STATUS_CSV")
      end,
      OnShow = function (self, data)
        self.editBox:SetMultiLine()
        self.editBox:Insert("player,copper,artifact_name,artifact_level,order_resources,veiled_argunite,ilvl\n")
        for player, player_data in pairs(_toonStatus) do
          self.editBox:Insert(CharacterStatusCSVString(player_data).."\n")
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
  else
    if ToonStatusFrame:IsShown() then
      ToonStatusFrame:Hide()
    else
      SavePlayerData()

      local players = {}
      for k in pairs(_toonStatus) do
        table.insert(players, k) 
      end
      table.sort(players)

      messageFrame:Clear()
      for i, player in ipairs(players) do
        TS_ChatMessage(player)
        messageFrame:AddMessage(CharacterStatusString(_toonStatus[player]))
      end
      ToonStatusFrame:Show()
    end  
  end
end

function SavePlayerData()
  if _debug then TS_ChatMessage("SavePlayerData") end
  if (not _toonStatus) then
    _toonStatus = {}
  end
  data = GetPlayerData()
  _toonStatus[data.player_name] = data
  ToonStatus = _toonStatus
  return data.player_name
end

function ShowStatusMessage()
  TS_ChatMessage("Type /ts to see the status of your toons")
end

function CharacterStatusString(data)
  if _debug then TS_ChatMessage("CharacterStatusString") end
  return ("%s\n%s\nArtifact %s Level %d\nOrder Resources %d\nVeiled Argunite %d\niLevel %d\n\n"):format(
    nvl(data.player_name, "UNKNOWN"), 
    GetCoinText(nvl(data.copper, 0)), 
    nvl(data.artifact_name, "NO ARTIFACT"),
    nvl(data.artifact_level, 0),
    nvl(data.order_resources, 0),
    nvl(data.veiled_argunite, 0),
    nvl(data.ilvl, 0)
  )
end

function CharacterStatusCSVString(data)
  if _debug then TS_ChatMessage("CharacterStatusString") end
  return ("%s,%s,%s,%d,%d,%d,%d"):format(
    nvl(data.player_name, "UNKNOWN"), 
    nvl(data.copper, 0), 
    nvl(data.artifact_name, "NO ARTIFACT"),
    nvl(data.artifact_level, 0),
    nvl(data.order_resources, 0),
    nvl(data.veiled_argunite, 0),
    nvl(data.ilvl, 0)
  )
end

function nvl(val, alt)
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
  local data = {}

  -- Player Name
  local player_name, realm = UnitName("player")
  if _debug then TS_ChatMessage("Player " .. nvl(player_name, "UNKNOWN")) end
  data.player_name = player_name

  -- Gold
  data.copper = GetMoney()
  if _debug then TS_ChatMessage("Copper " .. nvl(data.copper, -1)) end

  -- Artifact Info
  local itemID, altItemID, name, icon, xp, pointsSpent, quality, artifactAppearanceID, appearanceModID, itemAppearanceID, altItemAppearanceID, altOnTop, artifactTier = C_ArtifactUI.GetEquippedArtifactInfo()
  if _debug then TS_ChatMessage("Artifact " .. nvl(itemID, -1)) end
  data.artifact_name = name
  data.artifact_level = pointsSpent

  -- Interesting Resources
  for i=1,GetCurrencyListSize() do
    name, isHeader, isExpanded, isUnused, isWatched, count, extraCurrencyType, icon, itemID = GetCurrencyListInfo(i)
    if _debug then TS_ChatMessage("Currency ".. nvl(name, unknown)) end
    if name == "Order Resources" then
      data.order_resources = count
    elseif name == "Veiled Argunite" then
      data.veiled_argunite = count
    end
  end

  -- Item Level
  local overall, equipped = GetAverageItemLevel()
  if _debug then TS_ChatMessage("ilvl " .. nvl(equipped, -1)) end
  data.ilvl = equipped
  return data
end

function TS_ChatMessage(msg)
  appName = "Toon Status"
  print(("%s: %s"):format(appName, msg))
end
