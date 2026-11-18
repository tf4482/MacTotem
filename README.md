# MacTotem

WoW Forever addon for shamans that keeps one macro casting the totems of the active totem
bar page in sequence.

## Features

- **Totem macro** - the macro `MacTotem` holds a `/castsequence` of the totems set on
  the active page of the Blizzard totem bar (Call of the Elements, Ancestors, or
  Spirits).
- **Cast order** - choose which element (Earth, Fire, Water, Air) is cast first, second,
  third, and fourth; default is Earth, Fire, Water, Air.
- **Macro list** - keep the macro in the character macros (default) or the general
  account macros; switching moves it, so place it on your bar again.
- **Always in sync** - the macro updates when you assign or remove a totem or switch the
  page; changes made in combat apply right after combat.
- **Reset timer** - the sequence restarts after combat and, optionally, after 1-60
  seconds without a cast.
- **Shamans only** - other classes get no macro.
- **Remembered** - settings are saved per account; default is off.
- **Settings page** - all options in the game menu under Options > AddOns, also opened
  from the addon compartment menu.
- **Chat commands** - every option can also be changed by slash command.

## Install

1. Download `MacTotem-vX.Y.Z.zip` from the [releases](https://github.com/tf4482/MacTotem/releases).
2. Unzip it into `World of Warcraft/_forever_/Interface/AddOns/`.
3. Restart the game or type `/reload`.
4. Type `/mt on`, then drag `MacTotem` from the macro window (`/macro`, character tab,
   or general tab with `/mt list account`) onto an action bar.

## Usage

```text
/mt                         show the state and the totems of the active page
/mt on                      manage the macro
/mt off                     stop managing the macro (the macro stays as it is)
/mt reset <s>               restart the sequence after s seconds, 0 = only after combat
/mt order <a> <b> <c> <d>   cast order of earth, fire, water, air, each once
/mt list character|account  keep the macro in the character or general macros
/mt config                  open the settings page
/mt help                    list all commands
```

`/mactotem` works as well (in case another addon already uses `/mt`).

## Examples

- Totem bar page 1 holds Strength of Earth, Searing, Healing Stream, and Windfury: the
  macro becomes `/castsequence reset=combat Strength of Earth Totem, Searing Totem, ...`;
  press it four times to drop all four.
- `/mt order fire earth air water`: the macro drops the fire totem first and the water
  totem last; the settings page shows the same order under Totem 1-4.
- `/mt list account`: the macro moves to the general macros and is shared by all
  characters; each shaman with MacTotem rewrites it for their own totem bar.
- `/mt reset 8` gives `reset=combat/8`: pausing 8 seconds starts again at the first
  totem.
- Switch the totem bar to Call of the Spirits: the macro follows that page at once, or
  right after combat.

## Develop

Check the code with [Luacheck](https://github.com/lunarmodules/luacheck) before each commit
(CI runs it on every push):

```text
luacheck .
```

Release: push an annotated tag `vX.Y.Z`; GitHub Actions packages the addon with the
BigWigs packager and publishes it.

## License

All rights reserved, see [LICENSE](LICENSE).
