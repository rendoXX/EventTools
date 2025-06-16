# EventTools
A BeamMP plugin that provides various commands for organizing events.

Initial base taken from [@Neverless's RaceOptions script](https://github.com/OfficialLambdax/BeamMP-ServerScripts/tree/main/RaceOptions), licensed under the MIT License.

## SubCommand: `/ropt`

### Example Usage
`/ropt restr enable`


- `state`: `enable` or `disable`  
  - `enable`: Limits the action  
  - `disable`: Removes the limitation  
- `playerId`: *(optional)* Used to target a specific player. If omitted, the command applies to everyone. Not all commands support this.  
- `speed`: Speed in **km/h**  
- `time`: Time in format `HH:MM` (24h)  

> World Editor is always disabled.

---

## Commands

### `/ropt restr <state>`
Disables access to:
- Environment settings
- Radial menu
- Keybinds with restricted actions

Blocked keybinds:
```
{
"toggleRadialMenuMulti", "recover_vehicle", "reset_physics", "reset_all_physics",
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

### `/ropt reset <playerId>`
Resets the player's vehicle.  
If `playerId` is not specified, everyone's vehicle will reset.

---

### `/ropt pcfg <state>`
Disables access to the Part Configurator.

---

### `/ropt vsel <state>`
Disables access to the Vehicle Selector.

---

### `/ropt compmode <state>`
Disables many features, similar to Scenario mode.  
This command is deprecated and not recommended.

---

### `/ropt status`
Lists all restriction features and their states.

---

### `/ropt adminx`
Toggles admin exception from restrictions.  
Must be used before applying any restrictions.

---

### `/ropt sl <state>`
Enables or disables a speed limit.

---

### `/ropt slset <speed>`
Sets the speed limit in km/h.

---

### `/ropt flip <playerId>`
Makes the player’s vehicle perform a front flip.  
If `playerId` is not specified, all vehicles will flip.

---

### `/ropt nowalk <state>`
Prevents players from spawning a unicycle (BeamLing) and removes any existing ones.

---

### `/ropt clearchat`
Sends 20 empty messages to clear the chat.

---

### `/ropt freeze <state> <playerId>`
Freezes the player’s vehicle, preventing movement.  
If `playerId` is not specified, everyone's vehicle will freeze.

---

### `/ropt help`
Displays a list of all available `/ropt` commands.

---

### `/ropt settime <time>`
Sets the time for all players.  
Players can still change the time afterward unless `/ropt restr` is enabled.

---

### `/ropt results`
Lists voting results.

---

### `/ropt clearvotes`
Clears all existing votes.

---

## Commands Available to All Players

### `-vote <username>`
Vote for a specific player.

### `/ropt togglenames`
Hides or shows player usernames for everyone.

This setting overrides the in-game "Show Player Names" checkbox.  
Rejoining or changing settings will not bypass this unless the player knows how to use the console and some BeamMP code.

---

### `/ropt popup <playerId> <text>`
Displays a popup window on the selected player's screen with your message and an “OK” button.

- `text` can contain spaces.
- Popup messages are logged in the server console with sender, receiver, and message content.

---

### `/ropt setprefix <playerId> <Tag> [r] [g] [b]`
Sets a tag before the username of a player.

- `Tag` must not contain spaces.
- `[r] [g] [b]` are optional RGB values.

**Rules:**
- Administrators cannot use RGB on themselves or other admins. You may only use `/ropt setsuffix playerId tag` (no RGB).
- You cannot switch between RGB and non-RGB tags for the same type (prefix/suffix).
- You cannot set an RGB prefix if the player already has an RGB suffix.

---

### `/ropt setsuffix <playerId> <Tag> [r] [g] [b]`
Sets a tag after the username of a player.

- Same syntax and restrictions as `/ropt setprefix`.

---

## Staff Tags System

This system automatically assigns a colored client-side tag for all staff members when they spawn a vehicle.

Staff roles:
- Moderator
- Administrator
- Owner