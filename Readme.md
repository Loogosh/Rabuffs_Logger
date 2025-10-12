# RABuffs Logger - Complete Guide

Extension for RABuffs - automatic raid buff state logging.
Based on - https://github.com/pepopo978/Rabuffs
---

## ⚡ Quick Cheat Sheet

```lua
/rablog status        -- Check settings
/rablog show 1        -- Last pull
/rablog detail 1      -- Details with player names
/rablog logpoint 5    -- Log 5 sec before pull (default)
```

**Files:**
- `RAB_parse_log.py` - parser
- `RAB_parse.bat` - Windows helper  
- `Readme.md` - this guide

**Parsing:** Copy `RAB_parse_log.py` + `RAB_parse.bat` to folder with `WoWCombatLog.txt`, run bat.

---

## 📦 Installation

1. Put `RABuffs_Logger` folder in `Interface/AddOns/`
2. You should have both folders:
   ```
   AddOns/
   ├── RABuffs/           (original)
   └── RABuffs_Logger/    (extension)
   ```
3. `/reload` in game

**Requirements:**
- ✅ RABuffs (required)
- ⭐ SuperWoW (recommended for file writing)
- 🐍 Python 3.6+ (for log parsing)

---

## 🚀 Quick Start

```lua
/rablog status        -- check settings
/rablog test 1        -- test entry
/rablog show 1        -- view

-- BigWigs pull timer
/pull 5               -- automatically logged as pull #5

-- Manual logging
/rablog log Naxx40 6  -- log "Naxx40" profile as pull 6
```

---

## 📋 All Commands

### View Logs
```lua
/rablog show [N]          -- Last N entries (default 5)
/rablog detail <N>        -- Detailed info for entry N (with player names)
/rablog stats             -- Statistics
/rablog status            -- Current settings
```

### Manual Logging
```lua
/rablog test [N]                  -- Current profile (pull N)
/rablog log <profile> <N>         -- Specific profile by name
/rablog logall <N>                -- ALL profiles at once
```

**Examples:**
```lua
/rablog test 999                  -- test
/rablog log Naxx40 6              -- Naxx40 profile
/rablog logall 6                  -- all profiles
```

### Trigger Management
```lua
/rablog trigger list              -- Show all triggers
/rablog trigger add <pattern>     -- Add trigger
/rablog trigger remove <N>        -- Remove trigger N
```

**Trigger Examples:**
```lua
/rablog trigger add go%s+(%d+)           -- "go 5"
/rablog trigger add ready%s+(%d+)        -- "ready 3"
/rablog trigger add boss%s+(%d+)         -- "boss 1"
```

**Default (already included):**
- `pull%s+(%d+)` → "pull 6"
- `пулл%s+(%d+)` → "пулл 3"
- `тянем%s+(%d+)` → "тянем 5"
- `пул%s+(%d+)` → "пул 10"

### Profile Filter
```lua
/rablog profile list              -- Show filter
/rablog profile add <name>         -- Add profile to auto-logging
/rablog profile remove <name>      -- Remove profile from auto-logging
/rablog profile clear             -- Clear (log only current)
```

**Examples:**
```lua
/rablog profile add Naxx_Healers
/rablog profile add Naxx_Tanks
-- Now on pull both profiles are logged!

/rablog profile clear             -- return to current only
```

### Settings
```lua
/rablog toggle        -- Enable/disable logging
/rablog file          -- Enable/disable file writing (SuperWoW)
/rablog memory        -- Enable/disable SavedVariables
/rablog clear         -- Clear memory + marker in file
/rablog logpoint <N>  -- Log when N seconds remain (default 5)
/rablog export        -- Export instructions
/rablog help          -- Help
```

**Important about `/rablog clear`:**
- Clears memory (SavedVariables)
- Adds `RABLOG_CLEAR` marker to file
- Parser shows **only entries after** last clear
- Old data remains in file but not processed

**Logpoint Examples:**
```lua
/rablog logpoint 5    -- log when 5 seconds remain
/rablog logpoint 3    -- log when 3 seconds remain
/rablog logpoint 10   -- log when 10 seconds remain
```

---

## 🎯 How Auto-Logging Works

### 1. BigWigs Pull Timer (PRIMARY)

When **someone** does `/pull 10`:
- BigWigs shows timer (10, 9, 8, 7, 6, **5**...)
- Logger waits until **5 seconds** remain (configurable)
- **At that moment** logs buff state

**Why wait 5 seconds?**
- Players have time to apply missing buffs
- Captures **final** state before pull
- More accurate data for analysis

**Change logging point:**
```lua
/rablog logpoint 3    -- log 3 seconds before pull
/rablog logpoint 10   -- log 10 seconds before pull
```

### 2. Chat Triggers

When someone writes in raid/party chat:
- "pull 6" → logs pull #6
- "пулл 3" → logs pull #3
- Custom triggers via `/rablog trigger add`

---

## 💾 Where Logs are Stored

### With SuperWoW (recommended):
**File:** `Logs/WoWCombatLog.txt`
- ✅ Writing is **instant** (no /reload needed)
- ✅ No limits
- ✅ Automatically on each pull

### Without SuperWoW (fallback):
**File:** `WTF/Account/<ACCOUNT>/SavedVariables/RABuffs_Logger.lua`
- ⚠️ Needs `/reload` or game exit
- ⚠️ Maximum 200 entries

---

## 📊 Data Format in File

**Logs/WoWCombatLog.txt:**
```
10/12 09:45:30.123  RABLOG_PULL: DateTime&RealTime&ServerTime&Pull&Profile&Char&Realm&Source&GroupType/Size
10/12 09:45:30.124  RABLOG_BAR: idx&buffKey&label&buffed&total&pct&fade&groups&classes
10/12 09:45:30.125  RABLOG_PLAYERS_WITH: buffKey&Name1 [Class1; G1], Name2 [Class2; G2]
10/12 09:45:30.126  RABLOG_PLAYERS_WITHOUT: buffKey&Name3 [Class3; G3], Name4 [Class4; G4]
10/12 09:45:30.127  RABLOG_END: PullNumber
```

**Structure:**
- `RABLOG_PULL` = event header
- `RABLOG_BAR` = buff statistics
- `RABLOG_PLAYERS_WITH` = who HAS buff
- `RABLOG_PLAYERS_WITHOUT` = who LACKS buff
- `RABLOG_END` = end of entry

---

## 🔧 Parsing to CSV/JSON

### Windows (simple way)

1. Copy to folder with `WoWCombatLog.txt`:
   - `RAB_parse_log.py`
   - `RAB_parse.bat`

2. Double-click `RAB_parse.bat`

3. Choose format:
   - `1` = Text (readable)
   - `2` = CSV (for Excel)
   - `3` = JSON
   - `4` = All formats
   - `5` = Statistics

### Manually

```bash
python RAB_parse_log.py -i WoWCombatLog.txt -f csv -o raid.csv
python RAB_parse_log.py -i WoWCombatLog.txt --stats
```

### CSV Output

**Columns:**
- EntryID, DateTime, RealTime, ServerTime
- PullNumber, Character, Realm, Profile
- BuffLabel, Buffed, Total, Percentage, Fading
- **PlayersWithBuff_Names** - names of players with buff
- **PlayersWithBuff_Classes** - classes
- **PlayersWithBuff_Groups** - groups
- **PlayersWithoutBuff_Names** - names without buff
- **PlayersWithoutBuff_Classes** - classes
- **PlayersWithoutBuff_Groups** - groups

**In Excel:**
- Filter by names
- Analyze by classes
- Group by raid groups

---

## 🎮 Usage Examples

### Example 1: Basic Usage
```lua
/rablog status        -- check
[playing, someone does /pull 6]
/rablog show 1        -- view
```

### Example 2: Custom Trigger
```lua
/rablog trigger add go%s+(%d+)
[RL writes "go 5" in chat]
-- automatically logged
```

### Example 3: Specific Profile
```lua
/rablog log Sapphiron 14
-- Logs "Sapphiron" profile without switching to it
```

### Example 4: Multiple Profiles Simultaneously
```lua
/rablog profile add Naxx_Healers
/rablog profile add Naxx_Tanks
[someone does /pull 6]
-- BOTH profiles logged automatically!
```

### Example 5: All Profiles
```lua
/rablog logall 0
-- Snapshot of all profiles at one point in time
```

---

## 🔍 What Gets Logged

For each pull:

**Metadata:**
- Time (real + server)
- Pull number
- Who initiated
- RABuffs profile
- Group size

**For each buff:**
- Statistics: 38/40 (95%)
- **Names WITH buff:** Vovan, Petya, Ivan
- **Names WITHOUT buff:** Kolya, Misha
- **Classes:** Priest, Warrior, Mage
- **Groups:** 1, 2, 3

---

## ⚙️ Settings

```lua
RABLogger_Settings = {
    enabled = true,              -- Enable/disable logging
    logToFile = true,            -- Write to file (SuperWoW)
    saveToMemory = true,         -- Save to SavedVariables
    saveDetailed = true,         -- Detailed data (player names)
    logToChat = true,            -- Chat notifications
    maxEntries = 200,            -- Max entries in memory
    
    triggers = {                 -- Chat triggers
        "pull%s+(%d+)",
        "пулл%s+(%d+)",
        ...
    },
    
    profileFilter = {}           -- Profile filter (empty = current)
}
```

Change via `/rablog` commands or manually via `/run`:
```lua
/run RABLogger_Settings.maxEntries = 500
```

---

## 🐛 Troubleshooting

**Logs not appearing?**
```lua
/rablog toggle        -- check that ENABLED
/rablog test 999      -- create test entry
/rablog show 1        -- should appear
```

**BigWigs not logging?**
```lua
/reload               -- refresh code
/pull 5               -- try again
```

If doesn't help - check in game:
```lua
/run print(BigWigs and "BigWigs OK" or "BigWigs NOT FOUND")
```

**Parser can't find file?**
```bash
# Copy files to same folder as WoWCombatLog.txt
# Run: RAB_parse.bat
```

**No player names in output?**

Check that `saveDetailed = true`:
```lua
/run print(RABLogger_Settings.saveDetailed)
```

If `nil` or `false`:
```lua
/run RABLogger_Settings.saveDetailed = true
/reload
/rablog test 5
/rablog detail 1      -- now should have names
```

---

## 📖 What is RABuffs Profile

**Profile** = set of bars (strips), each tracking a specific buff.

**Example "Naxx40" profile:**
```lua
{
    [1] = { buffKey="motw", label="Mark", groups="12345678", ... },
    [2] = { buffKey="pwf", label="Fort", groups="12345678", ... },
    [3] = { buffKey="ai", label="Int", groups="12345678", ... },
}
```

**RABuffs Commands:**
```lua
/rab profile list             -- show all profiles
/rab profile save Naxx40      -- create "Naxx40" profile
/rab profile load Naxx40      -- load "Naxx40" profile
```

**Why log different profiles?**

You might have:
- Profile for all 40 players
- Profile only for healers (groups 1-5)
- Profile only for tanks
- Profile for specific boss (Sapphiron with Shadow Protection)

Logger can log **multiple profiles simultaneously** on one pull!

---

## 🎯 Usage Scenarios

### Scenario 1: Single Profile (simple)
```lua
-- Don't configure anything
-- On /pull 6 current profile is logged
```

### Scenario 2: Custom Trigger
```lua
/rablog trigger add go%s+(%d+)
-- Now catches both "pull 5" and "go 5"
```

### Scenario 3: Multiple Profiles
```lua
/rablog profile add Naxx_Healers
/rablog profile add Naxx_Tanks
-- On /pull 6 BOTH profiles are logged
```

### Scenario 4: All Profiles (full snapshot)
```lua
/rablog logall 0
-- Logs ALL profiles at one point in time
```

---

## 📝 Output Format

### In Game (/rablog detail 1):
```
Pull 5 - Naxx40

Mark of the Wild (motw):
  With buff: Vovan, Petya
  Without buff: Kolya, Misha

Fortitude (pwf):
  With buff: Vovan, Petya, Kolya, Misha
  Without buff: (all have it)
```

### In File (WoWCombatLog.txt):
```
RABLOG_PULL: 2025-10-12 09:45:30&...&5&Naxx40&...
RABLOG_BAR: 1&motw&Mark&38&40&95&2&&
RABLOG_PLAYERS_WITH: motw&Vovan [Priest; G1], Petya [Warrior; G2]
RABLOG_PLAYERS_WITHOUT: motw&Kolya [Mage; G3], Misha [Rogue; G4]
RABLOG_END: 5
```

### In CSV (Excel):
| BuffLabel | Buffed | Total | Percentage | PlayersWithBuff_Names | PlayersWithoutBuff_Names | PlayersWithoutBuff_Classes | PlayersWithoutBuff_Groups |
|-----------|--------|-------|------------|----------------------|-------------------------|---------------------------|--------------------------|
| Mark | 38 | 40 | 95 | Vovan, Petya | Kolya, Misha | Mage, Rogue | 3, 4 |

---

## 🔢 Timestamps

Each entry contains **3 types of time:**

- **Real Time** (09:45:30) - your computer's time
- **Server Time** (18:45) - in-game server time
- **DateTime** (2025-10-12 09:45:30) - full date + time

Why:
- Correlate with external logs (real time)
- Match with in-game events (server time)
- Precise calculations (unix timestamp)

---

## 📚 File Structure

```
RABuffs_Logger/
├── RABuffs_Logger.toc          # Addon metadata
├── Logger_Core.lua             # Core logic
├── Logger_Export.lua           # Export functions
│
├── RAB_parse_log.py            # Log parser
├── RAB_parse.bat               # Windows helper
│
└── Readme.md                   # This guide
```

---

## 🚀 Typical Raid

### Before Raid:
```lua
/rablog status        -- check
/rablog clear         -- clear (optional)
```

### During Raid:
- Do nothing! 
- Logs are written automatically on `/pull`

### After Raid:
```lua
/rablog stats         -- statistics
```

```bash
# Parse to CSV
python RAB_parse_log.py -f csv -o raid_12_10.csv
# Open in Excel
```

---

## 💡 Advanced Features

### Multi-Profile Analysis

You have 3 profiles:
- **Naxx_All** - all bars for all players
- **Naxx_Healers** - only healers (groups 1-5)
- **Naxx_Tanks** - only tanks

```lua
/rablog profile add Naxx_All
/rablog profile add Naxx_Healers
/rablog profile add Naxx_Tanks
```

On `/pull 6` → **3 entries** (one for each profile)!

**In CSV:**
```csv
PullNumber,Profile,BuffLabel,Buffed,Total,PlayersWithoutBuff_Names
6,Naxx_All,Mark,40,40,
6,Naxx_Healers,Mark,8,8,
6,Naxx_Tanks,Mark,5,5,
```

Analyze coverage separately for tanks/healers/all!

### Logging by Profile Name

```lua
-- Current profile: Default
-- But want to log Sapphiron

/rablog log Sapphiron 14

-- Current profile DOESN'T change
-- But Sapphiron is logged
```

### Snapshot All Profiles

```lua
/rablog logall 0
-- Logs ALL profiles as pull #0
-- Full state snapshot
```

---

## ⚡ Quick Reference

| Command | What it does |
|---------|-----------|
| `/rablog test 1` | Test |
| `/rablog show 5` | Last 5 |
| `/rablog detail 1` | Details with names |
| `/rablog stats` | Statistics |
| `/rablog status` | Settings |
| `/rablog log <prof> <N>` | Log profile |
| `/rablog trigger add <pat>` | Add trigger |
| `/rablog profile add <name>` | Add to filter |
| `/rablog toggle` | Enable/disable |
| `/rablog clear` | Clear |

---

## 🆘 Support

**BigWigs not working?**
```lua
/run print(BigWigs and "OK" or "NOT FOUND")
```

**No SuperWoW?**
- Download: https://github.com/balakethelock/SuperWoW
- Or use SavedVariables (needs /reload)

**No Python?**
- Download: https://www.python.org/downloads/
- During installation: "Add Python to PATH" ✓

---

## 📌 Version

**RABuffs Logger v1.0.0**

Compatible with:
- RABuffs 0.12.0+
- BigWigs (any version)
- SuperWoW (optional)
- WoW Classic 1.12

---

## 🔄 Updating

**Update RABuffs:**
- Replace `RABuffs/` folder → Logger continues working

**Update Logger:**
- Replace `RABuffs_Logger/` folder → settings are preserved

---

Extension for **RABuffs by Pepo** | Uses **SuperWoW API** for file writing
