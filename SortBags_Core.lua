-- SortBags_Core.lua — Turtle WoW 1.12 (Lua 5.0)
-- Deterministic multi-pass sorter with safe swaps & stall recovery.
-- Public entry: SortBags_Run()

-------------------------------------------------------
-- Tunables
-------------------------------------------------------
local STEP_THROTTLE = 0.08   -- ~25 moves/sec
local MAX_PASSES    = 3      -- run up to N full passes automatically
local STALL_SEC     = 1.7    -- if no swaps for this long, rebuild plan
local DEBUG         = false

local function dprint(msg)
  if DEBUG and DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff9999ffSortBags[DBG]:|r "..tostring(msg))
  end
end

-------------------------------------------------------
-- Category ordering
-------------------------------------------------------
local CATEGORY_ORDER = {
  "Container","Key","Quest","Reagent","Trade Goods",
  "Consumable","Projectile","Quiver","Recipe",
  "Weapon","Armor","Miscellaneous",
}
local CATEGORY_INDEX = {}
do for i=1, table.getn(CATEGORY_ORDER) do CATEGORY_INDEX[CATEGORY_ORDER[i]]=i end end

local ARMOR_WEAPON_SLOT_RANK = {
  INVTYPE_AMMO=0,  INVTYPE_HEAD=1,  INVTYPE_NECK=2,  INVTYPE_SHOULDER=3,
  INVTYPE_BODY=4,  INVTYPE_CHEST=5, INVTYPE_ROBE=5,  INVTYPE_WAIST=6,
  INVTYPE_LEGS=7,  INVTYPE_FEET=8,  INVTYPE_WRIST=9, INVTYPE_HAND=10,
  INVTYPE_FINGER=11, INVTYPE_TRINKET=12, INVTYPE_CLOAK=13,
  INVTYPE_WEAPON=14, INVTYPE_SHIELD=15, INVTYPE_2HWEAPON=16,
  INVTYPE_WEAPONMAINHAND=18, INVTYPE_WEAPONOFFHAND=19,
  INVTYPE_HOLDABLE=20, INVTYPE_RANGED=21, INVTYPE_THROWN=22,
  INVTYPE_RANGEDRIGHT=23, INVTYPE_RELIC=24, INVTYPE_TABARD=25,
}
local CONSUMABLE_SUB_ORDER = { "Flask","Elixir","Potion","Bandage","Scroll","Food","Drink","Buff" }
local function lower(s) if s then return string.lower(s) end end
local function subIx(sub, list)
  if not sub then return 1000 end
  local s = lower(sub)
  for i=1, table.getn(list) do
    if string.find(s, string.lower(list[i]), 1, true) then return i end
  end
  return 1000
end

-------------------------------------------------------
-- Scan & helpers
-------------------------------------------------------
local function parseItemLink(link)
  if not link then return nil end
  local _, _, id = string.find(link, "item:(%d+):")
  return id and tonumber(id) or nil
end

local function safeInfo(id, fallback)
  local name, _, quality, ilevel, _, itype, isub, _, equip = GetItemInfo(id or 0)
  return {
    name = name or fallback or ("item:"..tostring(id or "?")),
    q = quality or 0, il = ilevel or 0, t = itype or "", s = isub or "", e = equip or ""
  }
end

-- returns items[], slots[], posMap[pos]=idx
local function scanBags()
  local items, slots, posMap = {}, {}, {}
  local pos = 0
  for bag=0,4 do
    local n = GetContainerNumSlots(bag) or 0
    for slot=1,n do
      pos = pos + 1
      slots[pos] = {bag,slot}
      local link = GetContainerItemLink(bag,slot)
      if link then
        local _, count = GetContainerItemInfo(bag,slot)
        local id = parseItemLink(link)
        if id then
          local inf  = safeInfo(id, link)
          local cat  = CATEGORY_INDEX[inf.t] or 999
          local gear = ARMOR_WEAPON_SLOT_RANK[inf.e] or 999
          local cons = (cat == CATEGORY_INDEX["Consumable"]) and subIx(inf.s, CONSUMABLE_SUB_ORDER) or 1000
          local idx  = table.getn(items)+1
          items[idx] = {
            idx=idx, bag=bag, slot=slot, pos=pos,
            id=id, link=link, name=inf.name,
            q=inf.q, il=inf.il, t=inf.t, s=inf.s, e=inf.e,
            cat=cat, gear=gear, cons=cons, count=count or 1,
          }
          posMap[pos] = idx
        end
      end
    end
  end
  return items, slots, posMap
end

local function less(a,b)
  if a.cat ~= b.cat then return a.cat < b.cat end
  if a.cat == CATEGORY_INDEX["Consumable"] and a.cons ~= b.cons then return a.cons < b.cons end
  if (a.cat == CATEGORY_INDEX["Armor"] or a.cat == CATEGORY_INDEX["Weapon"]) and a.gear ~= b.gear then
    return a.gear < b.gear
  end
  if a.q  ~= b.q  then return a.q  > b.q  end
  if a.il ~= b.il then return a.il > b.il end
  local na, nb = a.name or "", b.name or ""
  if na ~= nb then return na < nb end
  if a.id ~= b.id then return a.id < b.id end
  return a.pos < b.pos
end

local function slotLocked(bag,slot)
  local _, _, locked = GetContainerItemInfo(bag,slot)
  return locked
end

-------------------------------------------------------
-- Engine (multi-pass controller + planner)
-------------------------------------------------------
local driver = CreateFrame("Frame")
local tick, busy, plan = 0, false, nil
local passNum, lastSwapClock = 0, 0

local function swapNow(fb,fs,tb,ts)
  if CursorHasItem() then ClearCursor() end
  ClearCursor(); PickupContainerItem(fb,fs)
  if CursorHasItem() then PickupContainerItem(tb,ts) end
  if CursorHasItem() then PickupContainerItem(fb,fs); ClearCursor() end
end

local function buildPlan()
  local items, slots, posMap = scanBags()
  if table.getn(items) == 0 then return nil end
  local desired = {}
  for i=1, table.getn(items) do desired[i] = items[i] end
  table.sort(desired, less)
  return {items=items, slots=slots, posMap=posMap, desired=desired, i=1}
end

local function passIsComplete()
  local items, _, _ = scanBags()
  if table.getn(items) == 0 then return true end
  local desired = {}
  for i=1, table.getn(items) do desired[i] = items[i] end
  table.sort(desired, less)
  for i=1, table.getn(desired) do
    if desired[i].pos ~= i then return false end
  end
  return true
end

-- Advance one swap; returns true if progressed (swapped), false if pass finished
local function stepPlanner()
  if not plan then
    plan = buildPlan()
    if not plan then return false end
    dprint("pass "..passNum.." built for "..table.getn(plan.items).." items")
  end

  local items, slots, posMap, desired, i = plan.items, plan.slots, plan.posMap, plan.desired, plan.i

  -- advance past correct positions
  while i <= table.getn(desired) and items[desired[i].idx].pos == i do
    i = i + 1
  end
  plan.i = i
  if i > table.getn(desired) then
    plan = nil
    return false
  end

  local wantIdx = desired[i].idx
  local want    = items[wantIdx]
  local wantPos = want.pos
  local tgtBag, tgtSlot = slots[i][1], slots[i][2]
  local curIdx = posMap[i]  -- may be nil

  if slotLocked(want.bag, want.slot) or slotLocked(tgtBag, tgtSlot) then
    return true -- no progress this frame, try again
  end

  swapNow(want.bag, want.slot, tgtBag, tgtSlot)
  lastSwapClock = GetTime() or 0

  -- Update maps AFTER swap
  if curIdx then
    local cur = items[curIdx]
    cur.bag, cur.slot, cur.pos = slots[wantPos][1], slots[wantPos][2], wantPos
    posMap[wantPos] = curIdx
  else
    posMap[wantPos] = nil
  end
  want.bag, want.slot, want.pos = tgtBag, tgtSlot, i
  posMap[i] = wantIdx

  plan.i = i + 1
  return true
end

driver:SetScript("OnUpdate", function()
  local elapsed = arg1 or 0
  tick = tick + elapsed
  if tick < STEP_THROTTLE then return end
  tick = 0
  if not busy then return end

  -- If planner progressed, keep going; if finished, check if another pass is needed.
  local progressed = stepPlanner()
  if not progressed then
    if passIsComplete() or passNum >= MAX_PASSES then
      busy = false
      dprint("sorting done (passes="..passNum..")")
      return
    else
      passNum = passNum + 1
      plan = buildPlan() -- start next pass
      return
    end
  end

  -- Stall watchdog: rebuild plan if we haven't swapped in a while
  local now = GetTime() or 0
  if lastSwapClock == 0 then lastSwapClock = now end
  if (now - lastSwapClock) > STALL_SEC then
    dprint("stall detected → rebuilding plan")
    plan = buildPlan()
    lastSwapClock = now
  end
end)

-- expose busy state to UI button
function SortBags_IsBusy()
  return busy and true or false
end


function SortBags_Run()
  if busy then return end
  passNum, plan, lastSwapClock = 1, nil, 0
  busy = true
end
