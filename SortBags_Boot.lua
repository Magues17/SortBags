-- SortBags_Boot.lua — minimal loader, no slash commands.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffSortBags:|r loaded.")
  end
end)
