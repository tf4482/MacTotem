-- Shared component: Blizzard settings page and addon compartment entry bound to ns.db;
-- from wow-lua-house-style, plus ns.Header

local ADDON, ns = ...

-- settings category of this addon and its layout
local category, layout

-- TOC field of this addon
local function Meta(field)
  return C_AddOns.GetAddOnMetadata(ADDON, field)
end

-- open the settings page
function ns.OpenSettings()
  Settings.OpenToCategory(category:GetID())
end

-- create the settings page and the compartment entry; call once ns.db is loaded
function ns.Settings()
  local title = Meta("Title") or ADDON
  category, layout = Settings.RegisterVerticalLayoutCategory(title)
  Settings.RegisterAddOnCategory(category)
  if AddonCompartmentFrame then
    AddonCompartmentFrame:RegisterAddon({
      text = title,
      icon = Meta("IconTexture"),
      notCheckable = true,
      func = ns.OpenSettings,
    })
  end
end

-- change a setting from chat; updates ns.db and the page, runs onChange
function ns.Set(key, value)
  Settings.SetValue(ADDON .. "_" .. key, value)
end

-- section header below the controls added so far; never touch SettingsPanel (taints keybindings)
function ns.Header(text)
  layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
end

-- bind ns.db[key] with its Store default; onChange(value) runs after each change
local function Bind(key, label, onChange)
  local default = ns.defaults.db[key]
  local setting = Settings.RegisterAddOnSetting(
    category, ADDON .. "_" .. key, key, ns.db, type(default), label, default)
  if onChange then
    setting:SetValueChangedCallback(function(_, value)
      onChange(value)
    end)
  end
  return setting
end

-- checkbox for a boolean key
function ns.Checkbox(key, label, tooltip, onChange)
  Settings.CreateCheckbox(category, Bind(key, label, onChange), tooltip)
end

-- slider for a number key
function ns.Slider(key, label, min, max, step, tooltip, onChange)
  local options = Settings.CreateSliderOptions(min, max, step)
  options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
  Settings.CreateSlider(category, Bind(key, label, onChange), options, tooltip)
end

-- dropdown for a key; choices is a list of { value, label }
function ns.Dropdown(key, label, choices, tooltip, onChange)
  local function Options()
    local container = Settings.CreateControlTextContainer()
    for _, choice in ipairs(choices) do
      container:Add(choice[1], choice[2])
    end
    return container:GetData()
  end
  Settings.CreateDropdown(category, Bind(key, label, onChange), Options, tooltip)
end
