-- ============================================================================
-- RABuffs Logger - Export
-- Экспорт и форматирование данных
-- ============================================================================

-- ============================================================================
-- Информация об экспорте
-- ============================================================================

function RABLogger_ShowExportInfo()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00=== RABuffs Logger Export Info ===|r")
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    
    if CombatLogAdd then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Method 1: Direct File Logging (SuperWoW)|r |cff00ff00[RECOMMENDED]|r")
        DEFAULT_CHAT_FRAME:AddMessage("Location: |cffaaaaaa Logs/WoWCombatLog.txt|r")
        DEFAULT_CHAT_FRAME:AddMessage("Enable: |cff00ff00/rablog file|r")
        DEFAULT_CHAT_FRAME:AddMessage("Status: " .. (RABLogger_Settings.logToFile and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"))
        DEFAULT_CHAT_FRAME:AddMessage("When: |cff00ff00Instant|r - writes immediately on each pull")
        DEFAULT_CHAT_FRAME:AddMessage("Parse: |cffffcc00python parse_combatlog.py|r")
        DEFAULT_CHAT_FRAME:AddMessage(" ")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000SuperWoW not detected!|r")
        DEFAULT_CHAT_FRAME:AddMessage("Get SuperWoW: |cffaaaaaa https://github.com/balakethelock/SuperWoW|r")
        DEFAULT_CHAT_FRAME:AddMessage("This enables direct file writing (instant, no /reload needed)")
        DEFAULT_CHAT_FRAME:AddMessage(" ")
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Method 2: SavedVariables (fallback)|r")
    DEFAULT_CHAT_FRAME:AddMessage("Location: |cffaaaaaa WTF/Account/<ACCOUNT>/SavedVariables/RABuffs_Logger.lua|r")
    DEFAULT_CHAT_FRAME:AddMessage("Enable: |cff00ff00/rablog memory|r")
    DEFAULT_CHAT_FRAME:AddMessage("Status: " .. (RABLogger_Settings.saveToMemory and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"))
    DEFAULT_CHAT_FRAME:AddMessage("When: On |cffffcc00/reload|r or logout")
    DEFAULT_CHAT_FRAME:AddMessage("Parse: |cffffcc00python parse_logs.py|r")
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Method 3: In-game view|r")
    DEFAULT_CHAT_FRAME:AddMessage("Use |cff00ff00/rablog show|r to view logs in chat")
    DEFAULT_CHAT_FRAME:AddMessage("Manual copy if needed")
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Current Stats:|r")
    DEFAULT_CHAT_FRAME:AddMessage(string.format("Logs in memory: |cff00ff00%d|r / %d max", 
        table.getn(RABLogger_Logs), RABLogger_Settings.maxEntries))
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("Type |cffffcc00/rablog status|r for full configuration")
end

-- ============================================================================
-- Генерация текстового экспорта
-- ============================================================================

function RABLogger_GenerateTextExport()
    local output = {}
    
    table.insert(output, "================================================================================")
    table.insert(output, "RABuffs Logger Export")
    table.insert(output, string.format("Generated: %s", date("%Y-%m-%d %H:%M:%S")))
    table.insert(output, string.format("Total Entries: %d", table.getn(RABLogger_Logs)))
    table.insert(output, "================================================================================")
    table.insert(output, "")
    
    for i, entry in ipairs(RABLogger_Logs) do
        table.insert(output, string.format("--- Entry #%d ---", i))
        table.insert(output, string.format("DateTime: %s", entry.dateTime))
        table.insert(output, string.format("Real Time: %s | Server Time: %s", entry.realTime, entry.serverTime))
        table.insert(output, string.format("Pull: %d | Triggered by: %s", entry.pullNumber, entry.sourcePlayer))
        table.insert(output, string.format("Character: %s-%s (%s)", entry.character, entry.realm, entry.class))
        table.insert(output, string.format("Profile: %s | Group: %s (%d players)", 
            entry.profileName, entry.groupType, entry.groupSize))
        table.insert(output, string.format("Target: %s", entry.target or "None"))
        table.insert(output, "")
        table.insert(output, "Buffs:")
        
        for _, bar in ipairs(entry.bars) do
            table.insert(output, string.format("  %-20s: %3d/%3d (%3d%%) [Fading: %d] <%s>", 
                bar.label, bar.buffed, bar.total, bar.percentage, bar.fading, bar.buffKey))
        end
        
        table.insert(output, "")
    end
    
    return table.concat(output, "\n")
end

-- ============================================================================
-- Генерация CSV экспорта
-- ============================================================================

function RABLogger_GenerateCSVExport()
    local output = {}
    
    -- Заголовок
    table.insert(output, "EntryID,DateTime,RealTime,ServerTime,PullNumber,Character,Realm,Profile,GroupType,GroupSize,SourcePlayer,Target,BuffLabel,BuffKey,Buffed,Total,Percentage,Fading")
    
    -- Данные
    for i, entry in ipairs(RABLogger_Logs) do
        for _, bar in ipairs(entry.bars) do
            table.insert(output, string.format("%d,%s,%s,%s,%d,%s,%s,%s,%s,%d,%s,%s,%s,%s,%d,%d,%d,%d",
                i,
                entry.dateTime,
                entry.realTime,
                entry.serverTime,
                entry.pullNumber,
                entry.character,
                entry.realm,
                entry.profileName,
                entry.groupType,
                entry.groupSize,
                entry.sourcePlayer,
                entry.target or "None",
                bar.label,
                bar.buffKey,
                bar.buffed,
                bar.total,
                bar.percentage,
                bar.fading
            ))
        end
    end
    
    return table.concat(output, "\n")
end

-- ============================================================================
-- Генерация JSON-подобного экспорта
-- ============================================================================

function RABLogger_EscapeString(str)
    if not str then return "null" end
    str = string.gsub(str, "\\", "\\\\")
    str = string.gsub(str, '"', '\\"')
    str = string.gsub(str, "\n", "\\n")
    return '"' .. str .. '"'
end

function RABLogger_GenerateJSONExport()
    local output = {}
    
    table.insert(output, "{")
    table.insert(output, '  "version": "1.0.0",')
    table.insert(output, string.format('  "exported": "%s",', date("%Y-%m-%dT%H:%M:%S")))
    table.insert(output, string.format('  "totalEntries": %d,', table.getn(RABLogger_Logs)))
    table.insert(output, '  "logs": [')
    
    for i, entry in ipairs(RABLogger_Logs) do
        table.insert(output, "    {")
        table.insert(output, string.format('      "id": %d,', i))
        table.insert(output, string.format('      "timestamp": %d,', entry.timestamp))
        table.insert(output, string.format('      "dateTime": %s,', RABLogger_EscapeString(entry.dateTime)))
        table.insert(output, string.format('      "realTime": %s,', RABLogger_EscapeString(entry.realTime)))
        table.insert(output, string.format('      "serverTime": %s,', RABLogger_EscapeString(entry.serverTime)))
        table.insert(output, string.format('      "pullNumber": %d,', entry.pullNumber))
        table.insert(output, string.format('      "character": %s,', RABLogger_EscapeString(entry.character)))
        table.insert(output, string.format('      "realm": %s,', RABLogger_EscapeString(entry.realm)))
        table.insert(output, string.format('      "profileName": %s,', RABLogger_EscapeString(entry.profileName)))
        table.insert(output, string.format('      "groupType": %s,', RABLogger_EscapeString(entry.groupType)))
        table.insert(output, string.format('      "groupSize": %d,', entry.groupSize))
        table.insert(output, '      "bars": [')
        
        for j, bar in ipairs(entry.bars) do
            table.insert(output, "        {")
            table.insert(output, string.format('          "index": %d,', bar.index))
            table.insert(output, string.format('          "buffKey": %s,', RABLogger_EscapeString(bar.buffKey)))
            table.insert(output, string.format('          "label": %s,', RABLogger_EscapeString(bar.label)))
            table.insert(output, string.format('          "buffed": %d,', bar.buffed))
            table.insert(output, string.format('          "total": %d,', bar.total))
            table.insert(output, string.format('          "percentage": %d,', bar.percentage))
            table.insert(output, string.format('          "fading": %d', bar.fading))
            
            if j < table.getn(entry.bars) then
                table.insert(output, "        },")
            else
                table.insert(output, "        }")
            end
        end
        
        table.insert(output, "      ]")
        
        if i < table.getn(RABLogger_Logs) then
            table.insert(output, "    },")
        else
            table.insert(output, "    }")
        end
    end
    
    table.insert(output, "  ]")
    table.insert(output, "}")
    
    return table.concat(output, "\n")
end

-- ============================================================================
-- Вспомогательные функции для работы с SavedVariables
-- ============================================================================

function RABLogger_GetSavedVariablesPath()
    local accountName = "ACCOUNT_NAME"  -- Пользователь должен заменить
    return string.format("WTF/Account/%s/SavedVariables/RABuffs_Logger.lua", accountName)
end

function RABLogger_PrintSavedVariablesInfo()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00=== SavedVariables Info ===|r")
    DEFAULT_CHAT_FRAME:AddMessage("File: |cffaaaaaa WTF/Account/<YOUR_ACCOUNT>/SavedVariables/RABuffs_Logger.lua|r")
    DEFAULT_CHAT_FRAME:AddMessage("Contains: |cffffcc00RABLogger_Logs|r and |cffffcc00RABLogger_Settings|r tables")
    DEFAULT_CHAT_FRAME:AddMessage("Updated: On /reload or logout")
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    DEFAULT_CHAT_FRAME:AddMessage("To convert to readable format:")
    DEFAULT_CHAT_FRAME:AddMessage("1. Use provided Python/Lua parser script")
    DEFAULT_CHAT_FRAME:AddMessage("2. Or manually read Lua table structure")
end

