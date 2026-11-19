-- MacTotem: keeps a shaman macro that casts the totems of the active totem bar page

local _, ns = ...

-- name of the managed macro
local MACRO = "MacTotem"
-- question mark icon, so #showtooltip shows the next totem
local ICON = 134400
-- totem buttons per totem bar page
local PER_PAGE = 4
-- totem bar pages (Call of the Elements, Ancestors, Spirits)
local PAGES = 3
-- action slot offset of the totem bar when the client does not report it
local DEFAULT_BASE = 132
-- macro constants of newer clients
local MACRO_CONSTS = Constants and Constants.MacroConsts or {}
-- general (account) macro limit
local MAX_ACCOUNT = MAX_ACCOUNT_MACROS or MACRO_CONSTS.MAX_ACCOUNT_MACROS or 120

-- names of the totem sets, one per totem bar page
local SETS = { "Call of the Elements", "Call of the Ancestors", "Call of the Spirits" }

-- totem elements with their totem slot, in default cast order
local ELEMENTS = {
  { "earth", "Earth", EARTH_TOTEM_SLOT or 2 },
  { "fire", "Fire", FIRE_TOTEM_SLOT or 1 },
  { "water", "Water", WATER_TOTEM_SLOT or 3 },
  { "air", "Air", AIR_TOTEM_SLOT or 4 },
}
-- element key to totem slot
local SLOTS = {}
-- element choices for the order dropdowns
local ELEMENT_CHOICES = {}
-- element keys for the order command
local ELEMENT_KEYS = {}
for index, element in ipairs(ELEMENTS) do
  SLOTS[element[1]] = element[3]
  ELEMENT_CHOICES[index] = { element[1], element[2] }
  ELEMENT_KEYS[index] = element[1]
end
-- position without a totem; such positions always sit at the end
local NONE = "none"
ELEMENT_CHOICES[#ELEMENT_CHOICES + 1] = { NONE, "None" }
-- choices for the order command, including none
local ORDER_KEYS = { NONE }
for index, key in ipairs(ELEMENT_KEYS) do
  ORDER_KEYS[index + 1] = key
end

-- last arranged order per totem set, to know the value before a change
local known = {}
-- guard against change callbacks from our own rearranging
local arranging = false

-- full macro list already reported once
local warned = false

-- whether the player is a shaman
local function IsShaman()
  return select(2, UnitClass("player")) == "SHAMAN"
end

-- whether the macro should be managed now
local function Active()
  return ns.db ~= nil and ns.db.enabled and IsShaman()
end

-- action slot offset of the totem bar
local function ActionBase()
  local index = C_ActionBar and C_ActionBar.GetMultiCastBarIndex and C_ActionBar.GetMultiCastBarIndex()
  if not index or index < 1 then
    return DEFAULT_BASE
  end
  return (index - 1) * NUM_ACTIONBAR_BUTTONS
end

-- active totem bar page, as chosen on the Blizzard totem bar
local function Page()
  return MultiCastActionBarFrame and MultiCastActionBarFrame.currentPage or 1
end

-- saved key of a cast position within a totem set
local function Key(page, position)
  return "order" .. page .. "_" .. position
end

-- totem names on the active page, in the element order of its totem set
local function Totems()
  local names = {}
  local page = Page()
  local first = ActionBase() + (page - 1) * PER_PAGE
  for index = 1, PER_PAGE do
    local slot = SLOTS[ns.db[Key(page, index)]]
    if slot then
      local kind, id = GetActionInfo(first + slot)
      local name = kind == "spell" and C_Spell.GetSpellName(id)
      if name then
        names[#names + 1] = name
      end
    end
  end
  return names
end

-- element order of a totem set as text, skipped elements left out
local function Order(page)
  local order = {}
  for index = 1, PER_PAGE do
    local value = ns.db[Key(page, index)]
    if value ~= NONE then
      order[#order + 1] = value
    end
  end
  return #order > 0 and table.concat(order, ", ") or NONE
end

-- reset condition of the cast sequence
local function Reset()
  return ns.db.reset > 0 and "combat/" .. ns.db.reset or "combat"
end

-- macro text for the given totems; tooltip only when the page is empty
local function Body(names)
  if #names == 0 then
    return "#showtooltip"
  end
  return "#showtooltip\n/castsequence reset=" .. Reset() .. " " .. table.concat(names, ", ")
end

-- rewrite the general macro, create it if missing; never deletes; only called out of combat
local function Apply()
  if not Active() then
    return
  end
  local body = Body(Totems())
  local account = GetNumMacros()
  for index = 1, account do
    if GetMacroInfo(index) == MACRO then
      if GetMacroBody(index) ~= body then
        EditMacro(index, MACRO, nil, body)
      end
      return
    end
  end
  if account >= MAX_ACCOUNT then
    if not warned then
      ns.Error("no free general macro slot for " .. MACRO)
      warned = true
    end
    return
  end
  CreateMacro(MACRO, ICON, body, false)
end

-- update now, or right after combat
local function Refresh()
  ns.AfterCombat(Apply)
end

-- saved order of a totem set as a list
local function Saved(page)
  local list = {}
  for index = 1, PER_PAGE do
    list[index] = ns.db[Key(page, index)]
  end
  return list
end

-- store an order with elements first and none at the end, without change callbacks
local function SaveOrder(page, list)
  local arranged = {}
  for _, value in ipairs(list) do
    if value ~= NONE then
      arranged[#arranged + 1] = value
    end
  end
  for index = #arranged + 1, PER_PAGE do
    arranged[index] = NONE
  end
  arranging = true
  for index = 1, PER_PAGE do
    if ns.db[Key(page, index)] ~= arranged[index] then
      ns.Set(Key(page, index), arranged[index])
    end
  end
  arranging = false
  known[page] = arranged
end

-- position changed: none moves to the end, a used element swaps places
local function Arrange(page, position, value)
  if arranging then
    return
  end
  local list = {}
  for index, old in ipairs(known[page]) do
    list[index] = old
  end
  if value == NONE then
    table.remove(list, position)
    list[PER_PAGE] = NONE
  else
    for index = 1, PER_PAGE do
      if index ~= position and list[index] == value then
        list[index] = list[position]
      end
    end
    list[position] = value
  end
  SaveOrder(page, list)
  Refresh()
end

-- current state and the totems of the active page
local function Status()
  local hint = ""
  if not IsShaman() then
    hint = ns.Color("warning", " (shamans only)")
  elseif not ns.db.enabled then
    hint = ns.Color("muted", " - turn on with ") .. ns.Color("command", ns.slash .. " on")
  elseif InCombatLockdown() then
    hint = ns.Color("warning", " (updates after combat)")
  end
  ns.Print("macro " .. ns.Color("value", MACRO) .. " " .. ns.OnOff(ns.db.enabled) .. hint)
  ns.Detail("reset " .. ns.Color("value", Reset()))
  for page, set in ipairs(SETS) do
    ns.Detail(set .. " (" .. page .. "): " .. ns.Color("value", Order(page)))
  end
  if IsShaman() then
    local names = Totems()
    ns.Detail("active: " .. ns.Color("value", SETS[Page()] or Page()) .. ": "
      .. (#names > 0 and ns.Color("value", table.concat(names, ", ")) or ns.Color("muted", "no totems")))
  end
end

-- switch the macro management and report the new state
local function Switch(enabled)
  ns.Set("enabled", enabled)
  Status()
end

-- follow page changes on the Blizzard totem bar
if ChangeMultiCastActionPage then
  hooksecurefunc("ChangeMultiCastActionPage", Refresh)
end

-- event handlers by event name
local events = {}

-- world ready: action slots are known
function events.PLAYER_ENTERING_WORLD()
  Refresh()
end

-- totem bar rebuilt, e.g. after learning totems
function events.UPDATE_MULTI_CAST_ACTIONBAR()
  Refresh()
end

-- totem assigned to or removed from a totem bar slot
function events.ACTIONBAR_SLOT_CHANGED(slot)
  local base = ActionBase()
  if not slot or slot == 0 or (slot > base and slot <= base + PAGES * PER_PAGE) then
    Refresh()
  end
end

-- one frame dispatching all events above
local frame = CreateFrame("Frame")
for event in pairs(events) do
  frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event, ...)
  events[event](...)
end)

-- saved defaults: off, element order of ELEMENTS in every totem set
local defaults = { enabled = false, reset = 0 }
for page = 1, PAGES do
  for index, key in ipairs(ELEMENT_KEYS) do
    defaults[Key(page, index)] = key
  end
end

-- saved state; settings page and first update once loaded
ns.Store("MacTotemDB", defaults, function()
  ns.Settings()
  ns.Checkbox("enabled", "Manage macro", "Keep the MacTotem macro in sync with the active totem bar page", Refresh)
  ns.Slider("reset", "Reset after seconds", 0, 60, 1,
    "Seconds without a cast until the sequence restarts; 0 restarts only after combat", Refresh)
  -- four order dropdowns per totem set, each group under its own header
  for page, set in ipairs(SETS) do
    SaveOrder(page, Saved(page))
    ns.Header(set)
    for index = 1, PER_PAGE do
      ns.Dropdown(Key(page, index), "Totem " .. index, ELEMENT_CHOICES,
        "Element cast at position " .. index .. " for " .. set
          .. "; a used element swaps places, None skips the totem and moves to the end",
        function(value)
          Arrange(page, index, value)
        end)
    end
  end
  Refresh()
end)

-- chat commands
ns.Command({ name = "on", help = "manage the macro", run = function() Switch(true) end })
ns.Command({ name = "off", help = "stop managing the macro", run = function() Switch(false) end })
ns.Command({
  name = "reset",
  help = "seconds until the sequence restarts, 0 = only after combat",
  args = { { name = "seconds", type = "number", min = 0, max = 60 } },
  run = function(args)
    ns.Set("reset", math.floor(args.seconds))
    Status()
  end,
})
ns.Command({
  name = "order",
  help = "cast order of a totem set (1-3); elements left out are not cast",
  args = {
    { name = "set", type = "number", min = 1, max = PAGES },
    { name = "first", choices = ORDER_KEYS },
    { name = "second", choices = ORDER_KEYS, optional = true },
    { name = "third", choices = ORDER_KEYS, optional = true },
    { name = "fourth", choices = ORDER_KEYS, optional = true },
  },
  run = function(args)
    local order = { args.first, args.second or NONE, args.third or NONE, args.fourth or NONE }
    local seen = {}
    for _, element in ipairs(order) do
      if seen[element] and element ~= NONE then
        return ns.Error("name every element at most once")
      end
      seen[element] = true
    end
    SaveOrder(math.floor(args.set), order)
    Refresh()
    Status()
  end,
})
ns.Command({ name = "config", help = "open the settings page", run = ns.OpenSettings })
ns.Slash({ "/mt", "/mactotem" }, Status)
