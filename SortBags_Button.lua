-- SortBags_Button.lua  (Turtle WoW 1.12 / Lua 5.0)

-- Per-character saved pos
SortBagsDB = SortBagsDB or { x = 40, y = -140 }

local BTN_NAME = "SortBags_MinimapButton"
local btn = CreateFrame("Button", BTN_NAME, UIParent)

-- 1) Blizzard minimap button footprint
btn:SetFrameStrata("HIGH")
btn:SetClampedToScreen(true)
btn:SetMovable(true)
btn:EnableMouse(true)
btn:SetWidth(49); btn:SetHeight(49)

-- Anchor using saved offsets (free-move anywhere)
btn:ClearAllPoints()
btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", SortBagsDB.x, SortBagsDB.y)

-- 2) Gold ring border (Blizzard standard)
local border = btn:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetAllPoints(btn)

-- 3) Inner circular “icon” pad (20×20, SLIGHT upward nudge)
--    This pad defines the true visual center inside the ring.
local pad = btn:CreateTexture(nil, "BACKGROUND")
pad:SetTexture("Interface\\Minimap\\UI-Minimap-Background") -- dark disc
pad:SetWidth(20); pad:SetHeight(20)
pad:SetPoint("CENTER", btn, "CENTER", -10, 11) -- <- classic offset
pad:SetVertexColor(0, 0, 0, 0.65)

-- 4) “SB” text centered on the pad (so it stays inside the ring)
local label = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
label:SetPoint("CENTER", pad, "CENTER", 0, -1) -- tiny nudge looks best
do
  local f, size = label:GetFont()
  label:SetFont(f, 12)           -- 12 fits cleanly inside the ring
end
label:SetTextColor(1.0, 0.82, 0) -- Blizzard gold
label:SetText("SB")

-- 5) Tooltip (1.12 uses `this`; no var args)
btn:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
  GameTooltip:ClearLines()
  GameTooltip:AddLine("SortBags", 5, 0.82, 0)
  GameTooltip:AddLine("Click: Sort inventory", 1, 1, 1)
  GameTooltip:AddLine("Shift+Drag: Move anywhere", 1, 1, 1)
  GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- 6) Click = run sorter (no grey/enable state)
btn:SetScript("OnClick", function()
  if SortBags_Run and (not SortBags_IsBusy or not SortBags_IsBusy()) then
    SortBags_Run()
  end
end)

-- 7) Free-move anywhere with Shift+Drag, persist position
btn:RegisterForDrag("LeftButton")
btn:SetScript("OnDragStart", function()
  if IsShiftKeyDown() then this:StartMoving() end
end)
btn:SetScript("OnDragStop", function()
  this:StopMovingOrSizing()
  -- save top-left offsets so it looks identical after reload
  local left  = this:GetLeft()  or 0
  local top   = this:GetTop()   or 0
  local uLeft = math.floor(left + 0.5)
  local uTop  = math.floor(top  + 0.5)
  SortBagsDB.x = uLeft
  SortBagsDB.y = uTop - UIParent:GetTop()  -- convert to TOPLEFT offsets
  btn:ClearAllPoints()
  btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", SortBagsDB.x, SortBagsDB.y)
end)

-- 8) Re-apply saved pos on login (and normalize if missing)
btn:SetScript("OnEvent", function()
  if event == "PLAYER_LOGIN" then
    local x = SortBagsDB.x or 40
    local y = SortBagsDB.y or -140
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
  end
end)
btn:RegisterEvent("PLAYER_LOGIN")
