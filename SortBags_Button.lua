-- SortBags_Button.lua — Turtle WoW 1.12
-- Round minimap button with “SB”, draggable (Shift+Drag). Tunable offsets below.

SortBagsDB = SortBagsDB or { angle = 45 }

-- ======= tweak here if it looks a hair off on your UI =======
local RADIUS_PAD   = 4      -- smaller = closer to the very edge (try 3–6)
local RING_OX, RING_OY = -10, 10   -- tracking ring anchor offsets
local CENTER_OX, CENTER_OY = -1, 1 -- text/disc center offsets
-- ============================================================

local btn = CreateFrame("Button", "SortBags_MinimapButton", Minimap)
btn:SetWidth(31); btn:SetHeight(31)
btn:SetFrameStrata("MEDIUM"); btn:SetFrameLevel(8)
btn:EnableMouse(true)
btn:RegisterForClicks("LeftButtonUp")
btn:RegisterForDrag("LeftButton")

-- Gold ring (Blizzard tracking border)
local ring = btn:CreateTexture(nil, "OVERLAY")
ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
ring:SetWidth(54); ring:SetHeight(54)
ring:SetPoint("TOPLEFT", RING_OX, RING_OY)

-- Inner round disc
local disc = btn:CreateTexture(nil, "ARTWORK")
disc:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
disc:SetVertexColor(0.10, 0.10, 0.10, 1)
disc:SetWidth(20); disc:SetHeight(20)
disc:SetPoint("CENTER", CENTER_OX, CENTER_OY)

-- “SB” label
local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
fs:SetPoint("CENTER", CENTER_OX, CENTER_OY)
fs:SetText("SB")
fs:SetTextColor(1.0, 0.95, 0.2)
fs:SetShadowColor(0,0,0,1)
fs:SetShadowOffset(1,-1)

-- Hover highlight
local hl = btn:CreateTexture(nil, "HIGHLIGHT")
hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
hl:SetBlendMode("ADD")
hl:SetAllPoints(disc)

-- Place on the rim
local function updatePosition()
  local angle = SortBagsDB.angle or 45
  local radius = (Minimap:GetWidth() / 2) - RADIUS_PAD
  local x = cos(angle) * radius
  local y = sin(angle) * radius
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function recalcAngleFromCursor()
  local mx, my = Minimap:GetCenter()
  local cx, cy = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  local dx, dy = cx/scale - mx, cy/scale - my
  SortBagsDB.angle = math.deg(math.atan2(dy, dx))
  updatePosition()
end

btn:SetScript("OnDragStart", function()
  if IsShiftKeyDown() then this.isMoving = true end
end)
btn:SetScript("OnDragStop", function() this.isMoving = nil end)
btn:SetScript("OnUpdate", function()
  if this.isMoving then recalcAngleFromCursor() end
end)

btn:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_TOP")
  GameTooltip:AddLine("SortBags")
  GameTooltip:AddLine("Click: Sort inventory", 1,1,1)
  GameTooltip:AddLine("Shift+Drag: Move around minimap", 1,1,1)
  GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
btn:SetScript("OnClick", function()
  if SortBags_Run then SortBags_Run() end
end)

btn:RegisterEvent("PLAYER_LOGIN")
btn:RegisterEvent("PLAYER_ENTERING_WORLD")
btn:SetScript("OnEvent", function()
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    updatePosition()
    this:Show()
  end
end)
