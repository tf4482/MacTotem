# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.2.1] - 2026-11-27

### Changed

- Wider dropdowns on the settings page, without the arrows beside them

## [0.2.0] - 2026-11-24

### Added

- "Per character" checkbox on the settings page and `/mt character on|off`: settings for
  this character only, or the account's.
- `/mt test` writes the macro once now and shows its text.
- `/mt reset` restores the default settings; `/mt debug on|off` shows what the addon does.

### Changed

- The reset timer command is now `/mt restart <s>`; enabled users see one chat line about
  it once. Saved settings stay as they are.
- Release zips no longer contain the icon image.

### Fixed

- Loading no longer fails when the saved cast order needs tidying before the settings
  page is built.
- Logging in or entering the world no longer creates a second `MacTotem` macro before
  the macro list is loaded.

## [0.1.2] - 2026-11-19

### Fixed

- Opening the key bindings in the options no longer reports that MacTotem was blocked
  from an action only available to the Blizzard UI.

## [0.1.1] - 2026-11-18

### Changed

- Release zips no longer contain the `VERSION` file.
- README shows screenshots of the macro and the settings page.

## [0.1.0] - 2026-11-18

### Added

- General (account) macro `MacTotem` with a `/castsequence` of the totems on the active
  totem bar page, updated when totems or the page change.
- Cast order of the elements per totem set, chosen on the settings page or with
  `/mt order`.
- None in the cast order skips a totem; it always moves to the end.
- Settings page, compartment entry, and `/mt` chat commands.
- Release zips named `MacTotem-vX.Y.Z.zip` on GitHub and CurseForge.
