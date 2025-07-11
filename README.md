# EventTools

A BeamMP plugin that provides various commands for organizing events.

Initial base taken from [@Neverless's RaceOptions script](https://github.com/OfficialLambdax/BeamMP-ServerScripts/tree/main/RaceOptions), licensed under the MIT License.

---

## Main Command: `/ropt`

### Example Usage
`/ropt restr enable`

### Arguments

- `state`: `enable` or `disable`  
  - `enable`: Applies the restriction  
  - `disable`: Removes the restriction  
- `playerId`: *(optional)* Targets a specific player. If omitted, affects everyone.  
- `speed`: Speed in **km/h**  
- `time`: Format `HH:MM` (24-hour)

> World Editor is always disabled.

---

## Commands

### `/ropt restr <state>`
Disables access to:
- Environment settings  
- Radial menu  
- Restricted keybinds  
- Part Configurator  

Blocked keybinds:
```
{
  "vehicledebugMenu","toggleRadialMenuMulti", "recover_vehicle", "reset_physics", "reset_all_physics",
  "recover_vehicle_alt", "recover_to_last_road", "parts_selector", "reload_vehicle",
  "reload_all_vehicles", "loadHome", "saveHome", "dropPlayerAtCamera", "dropPlayerAtCameraNoReset",
  "toggleConsoleNG", "goto_checkpoint", "toggleConsole", "nodegrabberAction", "nodegrabberGrab",
  "nodegrabberRender", "editorToggle", "objectEditorToggle", "editorSafeModeToggle", "pause",
  "slower_motion", "faster_motion", "toggle_slow_motion", "toggleTraffic", "toggleAITraffic",
  "forceField", "funBoom", "funBreak", "funExtinguish", "funFire", "funHinges", "funTires",
  "funRandomTire"
}
```

---

### `/ropt vsel <state>`
Enables or disables access to the Vehicle Selector.

---

### `/ropt startrace`  
Starts the race by enabling restrictions and disabling access to vehicle selector and part selector.   
- Enables `/ropt restr`
- Enables `/ropt vsel`

---

### `/ropt stoprace`  
Stops the race by disabling restrictions.  
- Disables `/ropt restr`  
- Disables `/ropt vsel`

---

### ~~`/ropt compmode <state>`~~
~~Disables many features, similar to Scenario Mode.~~  
~~This command is deprecated and not recommended.~~

---

### `/ropt reset <player>`
Resets the vehicle of the specified player.  
If no `playerId` is provided, resets all vehicles.

---

### `/ropt status`
Displays the status of all restriction features.

---

### `/ropt adminx`
Toggles admin exception from restrictions.  
Must be used before applying any restrictions.

---

### `/ropt sl <state>`
Enables or disables the speed limiter.

---

### `/ropt slset <speed>`
Sets the speed limit in km/h.

---

### `/ropt flip <player>`
Makes a player's vehicle do a front flip.  
If `playerId` is not specified, all vehicles will flip.

---

### `/ropt nowalk <state>`
Prevents players from using BeamLing (unicycle) and removes existing ones.

---

### `/ropt clearchat`
Clears the chat by sending empty messages.

---

### `/ropt resetchat`
Clears the chat and resets the UI (to finish the clearing process) for everyone.  
At some point a better version of `/ropt clearchat`

---

### `/ropt freeze <state> <player>`
Freezes the player's vehicle.  
If `playerId` is not specified, everyone's vehicle will freeze.

---

### `/ropt help`
Displays a list of all `/ropt` commands.

---

### `/ropt settime <time> <isLocked>`
Sets the time for all players.  
If `<isLocked>` is set to true, players won't be able to change the time.

---

### `/ropt results`
Displays voting results.

---

### `/ropt clearvotes`
Clears all votes.

---

### `/ropt togglenames`
Hides or shows player usernames globally.

This overrides the in-game "Hide Player Names" option.  
Rejoining or changing settings will not bypass this unless the player knows how to use the console and some BeamMP code.

---

### `/ropt popup <player> <text>`
Displays a popup window with a message and “OK” button.

- `text` can include spaces.  
- Popup messages are logged in the server console with sender, receiver, and message content.

---

### `/ropt setprefix <player> <Tag> [r] [g] [b]`
Adds a tag before a player’s name.

### `/ropt setsuffix <player> <Tag> [r] [g] [b]`
Adds a tag after the player’s name.  

- `Tag` must not include spaces.  
- `[r] [g] [b]` are optional RGB values.

Rules:
- Administrators cannot use RGB on themselves or other admins. You may only use `/ropt setsuffix playerId tag` (no RGB).
- You cannot switch between RGB and non-RGB tags for the same type (prefix/suffix).
- You cannot set an RGB prefix if the player already has an RGB suffix.

---

### `/ropt cleartags <player>`
Clears the tag (prefix or suffix) for the specified player. 

---

### `/ropt removeveh <player>`
Removes all vehicles of the specified player.  
If `playerId` is not specified, all vehicles will be removed.

---

### `/ropt aoc`
Enables Admin Only Chat, preventing regular players from typing in the chat.

---

## Staff Tags System

This system automatically assigns a tag for staff when they spawn a vehicle.

Staff roles:
- Owner  
- Admin *(shown as “Administrator”)*  
- Moderator  
- EventManager *(shown as “Event Manager”)*

---

## Commands Available to All Players

### `-vote <username>`
Vote for a specific player.

---

# Admin System

### Commands

- `/ropt addadmin <username> <Role>`  
  Adds a player as an admin.  
  If the role is left empty, the player is granted privileges equivalent to **Event Manager**, but no visible tag will appear next to their name in-game.

- `/ropt removeadmin <username>`  
  Removes a player from the admin list.

- `/ropt adminlist`  
  Lists all current admins and their assigned roles.

---

### Available Roles

- **Owner**
- **Admin** (Displays in-game as `"Administrator"`)
- **Moderator**
- **EventManager** (Displays in-game as `"Event Manager"`)

---

### Permission System

To prevent abuse, a role-based permission system is made.
- Staff can only assign or remove roles **equal to or lower than their own**.
- **Event Managers** cannot set or remove any roles unless they are included in the `privilegedEventManagers` list.  
  Privileged Event Managers can assign the **Event Manager** role, but nothing higher.

---

Admins and roles hardcoded in the code will be automatically restored after every server/plugin restart, regardless if they're inside the .json file.
If no `.json` file exists at startup, one will be generated using the current values from `M.Admins`, `M.roles`, and `M.privilegedEventManagers`.

---

### Note

Setting custom RGB prefixes via commands has been **disabled**, as it could be used to impersonate higher-ranking staff.

