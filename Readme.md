# RABuffs Logger - Complete Guide

Extension for RABuffs - automatic raid buff state logging.
Based on - https://github.com/pepopo978/Rabuffs

**⚠️ IMPORTANT:** Addon logs **ONLY** the profile named **"RAID"**.

**Why "RAID" profile?**
- Logger is hardcoded to use profile named "RAID" (no configuration needed)
- Create it once in RABuffs addon: `/rab profile save RAID`
- Logger checks if RAID profile exists before every log attempt
- If not found → logging skipped with warning

---

## ⚡ Quick Cheat Sheet

```lua
-- First: Create RAID profile in RABuffs addon
/rab profile save RAID     -- (this is RABuffs command)

-- Then use logger
/rablog status             -- Check settings & RAID profile
/rablog test               -- Test logging
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
4. **⚠️ Create RAID profile in RABuffs addon:** `/rab profile save RAID`

**Requirements:**
- ✅ RABuffs addon (required)
- ✅ **Profile named "RAID"** in RABuffs (required)
- ⭐ SuperWoW (recommended for file writing)
- 🐍 Python 3.6+ (for log parsing)

---

## 🚀 Quick Start

**Step 1: Create RAID profile in RABuffs addon**
```lua
-- 1. Configure buffs in RABuffs (add bars, set groups, etc.)
-- 2. Save as RAID profile:
/rab profile save RAID
```

**Step 2: Verify & test logger**
```lua
/rablog status        -- check RAID profile exists
/rablog test          -- test logging (writes to file)
```

**Step 3: Automatic logging**
```lua
-- BigWigs pull timer
/pull 5               -- automatically logged as pull #5

-- Or via chat triggers
-- "pull 5" in raid chat → automatically logged
```

---

## 📋 All Commands

### Basic Commands
```lua
/rablog status            -- Current settings & RAID profile status
/rablog test              -- Test logging (creates test entry)
/rablog toggle            -- Enable/disable logging
/rablog logpoint <N>      -- Log when N seconds remain before pull
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

**Logpoint Examples:**
```lua
/rablog logpoint 5    -- log when 5 seconds remain before pull
/rablog logpoint 3    -- log when 3 seconds remain
/rablog logpoint 10   -- log when 10 seconds remain
```

---

## 🎯 How Auto-Logging Works

**⚠️ REQUIREMENT:** Profile named "RAID" must exist!

### 1. BigWigs Pull Timer (PRIMARY)

When **someone** does `/pull 10`:
- BigWigs shows timer (10, 9, 8, 7, 6, **5**...)
- Logger waits until **5 seconds** remain (configurable)
- **At that moment** logs RAID profile buff state

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
- "pull 6" → logs RAID profile for pull #6
- "пулл 3" → logs RAID profile for pull #3
- Custom triggers via `/rablog trigger add`

**If RAID profile doesn't exist** → logging is skipped with warning message

---

## 💾 Where Logs are Stored

**File:** `Logs/WoWCombatLog.txt` (requires SuperWoW)

- ✅ Writing is **instant** (no /reload needed)
- ✅ No limits on entries
- ✅ Automatically on each pull
- ✅ Parse with `RAB_parse_log.py`

**⚠️ SuperWoW is REQUIRED:**
- Without SuperWoW, logger cannot write to file
- Download: https://github.com/balakethelock/SuperWoW

---

## 📊 Data Format in File

**Logs/WoWCombatLog.txt:**
```
10/12 09:45:30.123  RABLOG_PULL: DateTime&RealTime&ServerTime&Pull&Profile&Char&Realm&Source&GroupType/Size&Target
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
- SourcePlayer, Target
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

### Example 1: Initial Setup
```lua
-- In RABuffs addon: configure buffs, then save
/rab profile save RAID

-- In Logger: verify
/rablog status        -- should show "Profile 'RAID': FOUND"
```

### Example 2: Testing
```lua
/rablog test          -- create test entry in WoWCombatLog.txt
```

### Example 3: Automatic Logging
```lua
[someone does /pull 6]
-- RAID profile logged automatically at 5 sec mark to file
```

### Example 4: Custom Trigger
```lua
/rablog trigger add go%s+(%d+)
[RL writes "go 5" in raid chat]
-- RAID profile logged automatically
```

---

## 🔍 What Gets Logged

For each pull (from RAID profile only):

**Metadata:**
- Time (real + server)
- Pull number
- Who initiated
- RABuffs profile (always "RAID")
- Group size
- Current target

**For each buff in RAID profile:**
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
    logToChat = true,            -- Chat notifications
    logToFile = true,            -- Write to file (always true)
    saveDetailed = true,         -- Detailed data (player names)
    pullLogPoints = {5},         -- Log when N seconds remain
    
    triggers = {                 -- Chat triggers
        "pull%s+(%d+)",
        "пулл%s+(%d+)",
        ...
    }
}
```

Change via `/run`:
```lua
/run RABLogger_Settings.pullLogPoints = {3}      -- log at 3 sec
/run RABLogger_Settings.logToChat = false        -- disable chat notifications
```

**⚠️ IMPORTANT:** 
- Logger always uses profile named "RAID"
- All logs go to `Logs/WoWCombatLog.txt` (SuperWoW required)

---

## 🐛 Troubleshooting

**"Profile 'RAID' not found" error?**
```lua
-- Create RAID profile in RABuffs addon:
/rab profile save RAID
/rablog status        -- verify it shows "FOUND"
```

**Logs not appearing in file?**
```lua
/rablog status        -- check RAID profile exists & SuperWoW status
/rablog toggle        -- check that ENABLED
/rablog test          -- create test entry
-- Check: Logs/WoWCombatLog.txt should have new entry
```

**BigWigs not logging?**
```lua
/rablog status        -- verify RAID profile exists first!
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
/rablog test
-- Check WoWCombatLog.txt - should have RABLOG_PLAYERS_WITH/WITHOUT entries
```

---

## 📖 What is RABuffs Profile

**Profile in RABuffs addon** = set of bars (strips), each tracking a specific buff.

**Example "RAID" profile structure:**
```lua
{
    [1] = { buffKey="motw", label="Mark", groups="12345678", ... },
    [2] = { buffKey="pwf", label="Fort", groups="12345678", ... },
    [3] = { buffKey="ai", label="Int", groups="12345678", ... },
}
```

**How to create RAID profile:**

1. **In RABuffs addon** - configure your buffs:
   - Add/remove bars
   - Set which groups to track (e.g., "12345678" for all groups)
   - Configure which classes to track
   - Set labels and priorities

2. **Save as RAID profile:**
   ```lua
   /rab profile save RAID
   ```

3. **Verify:**
   ```lua
   /rab profile list        -- should show RAID in list
   /rablog status           -- should show "Profile 'RAID': FOUND"
   ```

**Important:** 
- Logger works **ONLY** with profile named "RAID"
- RAID profile is stored in **RABuffs addon**, not in Logger
- If RAID profile doesn't exist, logging is skipped with warning
- You can update RAID profile anytime - reconfigure and save again

---

## 🎯 Usage Scenarios

### Scenario 1: First Time Setup
```lua
-- 1. In RABuffs: configure buffs → /rab profile save RAID
-- 2. In Logger: /rablog status (verify RAID exists)
-- 3. Test: /rablog test
-- Ready to log automatically!
```

### Scenario 2: Automatic Logging (BigWigs)
```lua
-- Someone does /pull 10
-- Logger automatically logs RAID profile at 5 sec mark
-- Data written to: Logs/WoWCombatLog.txt
```

### Scenario 3: Custom Trigger
```lua
/rablog trigger add go%s+(%d+)
-- Now catches both "pull 5" and "go 5"
-- Both trigger RAID profile logging
```


---

## 📝 Output Format

### In File (WoWCombatLog.txt):
```
RABLOG_PULL: 2025-10-12 09:45:30&...&5&RAID&...&Patchwerk
RABLOG_BAR: 1&motw&Mark&38&40&95&2&&
RABLOG_PLAYERS_WITH: motw&Vovan [Priest; G1], Petya [Warrior; G2]
RABLOG_PLAYERS_WITHOUT: motw&Kolya [Mage; G3], Misha [Rogue; G4]
RABLOG_END: 5
```

### In CSV (Excel):
| Target | BuffLabel | Buffed | Total | Percentage | PlayersWithBuff_Names | PlayersWithoutBuff_Names | PlayersWithoutBuff_Classes | PlayersWithoutBuff_Groups |
|--------|-----------|--------|-------|------------|----------------------|-------------------------|---------------------------|--------------------------|
| Patchwerk | Mark | 38 | 40 | 95 | Vovan, Petya | Kolya, Misha | Mage, Rogue | 3, 4 |

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

### One-Time Setup (first time only):
```lua
-- In RABuffs addon: configure buffs
/rab profile save RAID

-- Verify logger works
/rablog status        -- should show "Profile 'RAID': FOUND"
/rablog test          -- test logging
```

### Before Each Raid:
```lua
/rablog status        -- quick check (RAID profile + SuperWoW)
```

### During Raid:
- Do nothing! 
- RAID profile logged automatically on `/pull`
- Logs written to: `Logs/WoWCombatLog.txt`

### After Raid:
```bash
# Parse logs to CSV
python RAB_parse_log.py -f csv -o raid_12_10.csv
# Open in Excel and analyze
```

---

## 💡 Advanced Features

### Custom Triggers

Add your own chat patterns for auto-logging:

```lua
/rablog trigger add go%s+(%d+)
/rablog trigger add ready%s+(%d+)
/rablog trigger list
```

Now when someone types "go 5" or "ready 10" in raid chat, RAID profile is logged automatically!

### Flexible RAID Profile

Your RAID profile can be configured for different purposes:

**Option 1: Full raid tracking**
- Include all groups (1-8)
- Track all essential buffs

**Option 2: Role-specific tracking**
- Configure only groups 1-5 (healers)
- Track healer-specific buffs
- Rename profile to RAID: `/rab profile save RAID`

**Option 3: Boss-specific**
- Add special buffs (Shadow Protection for Sapphiron)
- Configure relevant groups only
- Save as RAID profile

**Switching setups:**
```lua
-- Save current setup as RAID
/rab profile save RAID

-- Load different setup later
/rab profile load RAID_Backup
-- Modify it
/rab profile save RAID  -- overwrite with new setup
```

---

## ⚡ Quick Reference

| Command | What it does |
|---------|-----------|
| `/rab profile save RAID` | Create RAID profile in RABuffs (required!) |
| `/rablog status` | Check settings & RAID profile status |
| `/rablog test` | Test logging (writes to file) |
| `/rablog toggle` | Enable/disable logging |
| `/rablog logpoint <N>` | Set log timing (N sec before pull) |
| `/rablog trigger add <pat>` | Add chat trigger |
| `/rablog trigger list` | Show all triggers |

---

## 🆘 Support

**BigWigs not working?**
```lua
/run print(BigWigs and "OK" or "NOT FOUND")
```

**No SuperWoW?**
- Download: https://github.com/balakethelock/SuperWoW
- **Required** for file logging (addon won't work without it)

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
