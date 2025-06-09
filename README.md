# EventTools
A BeamMP plugin that provides various commands for organizing events.

Initial base taken from [@Neverless's RaceOptions script](https://github.com/OfficialLambdax/BeamMP-ServerScripts/tree/main/RaceOptions), licensed under the MIT License.

## SubCommand: `/ropt`

### Example Usage
`/ropt restr state enable`


- `state`: `enable` or `disable`  
  - `enable`: Limits the action  
  - `disable`: Removes the limitation  
- `playerId`: *(optional)* Used to target a specific player. If omitted, the command applies to everyone. Not all commands support this.  
- `speed`: Speed in **km/h**  
- `settime`: Time in format `HH:MM` (24h)  

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

### `/ropt <settime>`
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
