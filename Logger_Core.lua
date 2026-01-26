-- ============================================================================
-- RABuffs Logger - Core
-- Extension for RABuffs addon - logs profile state on raid pull events
-- Uses SuperWoW CombatLogAdd() for direct file writing
-- ============================================================================

-- Версия
RABLogger_Version = "1.0.0"

-- Проверка зависимостей
if not RAB_CallRaidBuffCheck then
    message("RABuffs Logger ERROR: RABuffs addon is required!")
    return
end

if not CombatLogAdd then
    StaticPopupDialogs["NO_SUPERWOW_RABLOGGER"] = {
        text = "|cffffff00RABuffs Logger|r requires SuperWoW for file logging.\nGet it from: https://github.com/balakethelock/SuperWoW",
        button1 = TEXT(OKAY),
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        showAlert = 1,
    }
    StaticPopup_Show("NO_SUPERWOW_RABLOGGER")
    -- Продолжаем работу, но без записи в файл
end

-- ============================================================================
-- Инициализация данных
-- ============================================================================

RABLogger_Settings = RABLogger_Settings or {
    enabled = true,
    logToChat = true,           -- Уведомления в чат
    logToFile = true,           -- Запись в файл через CombatLogAdd()
    saveDetailed = true,        -- Детальные данные (имена игроков)
    pullLogPoints = {5},        -- Логировать когда остаётся N секунд (по умолчанию 5)
    
    -- Триггеры для перехвата
    triggers = {
        "pull%s+(%d+)",           -- "pull 6"
        "пулл%s+(%d+)",           -- "пулл 6"
        "тянем%s+(%d+)",          -- "тянем 3"
        "пул%s+(%d+)",            -- "пул 5"
    },
}

-- ============================================================================
-- Утилиты времени
-- ============================================================================

function RABLogger_GetServerTime()
    local hour, minute = GetGameTime()
    return string.format("%02d:%02d", hour, minute)
end

function RABLogger_GetRealTime()
    return date("%H:%M:%S")
end

function RABLogger_GetFullTimestamp()
    return date("%Y-%m-%d %H:%M:%S")
end

-- ============================================================================
-- Основная функция логирования
-- ============================================================================

function RABLogger_LogStateForProfile(profileName, pullNumber, triggerText, sourcePlayer)
    -- Логировать конкретный профиль по имени
    if not profileName or profileName == "" then
        RAB_Print("[RABLogger] Error: Profile name cannot be empty", "warn")
        return
    end
    
    -- Получаем ключ профиля
    local profileKey = RAB_GetProfileKey(profileName)
    
    -- Проверяем существование профиля
    if not RABui_Settings.Layout[profileKey] then
        RAB_Print("[RABLogger] Error: Profile '" .. profileName .. "' does not exist", "warn")
        return
    end
    
    -- Сохраняем текущий профиль и бары
    local originalProfile = RABui_Settings.currentProfile
    local originalBars = RABui_Bars
    
    -- Временно загружаем нужный профиль
    RABui_Bars = {}
    for i, bar in ipairs(RABui_Settings.Layout[profileKey]) do
        RABui_Bars[i] = {}
        for key, val in pairs(bar) do
            RABui_Bars[i][key] = val
        end
    end
    
    -- Логируем этот профиль
    RABLogger_LogState(pullNumber, triggerText, sourcePlayer, profileName)
    
    -- Восстанавливаем оригинальные бары
    RABui_Bars = originalBars
end

function RABLogger_LogState(pullNumber, triggerText, sourcePlayer, forcedProfileName)
    if not RABLogger_Settings.enabled then
        return
    end
    
    -- Проверяем, что RABuffs инициализирован
    if not RABui_Bars or table.getn(RABui_Bars) == 0 then
        return
    end
    
    local entry = {
        -- Временные метки
        timestamp = time(),                          -- Unix timestamp
        realTime = RABLogger_GetRealTime(),         -- Реальное время 14:35:22
        serverTime = RABLogger_GetServerTime(),     -- Игровое время 18:45
        dateTime = RABLogger_GetFullTimestamp(),    -- Полная дата 2024-11-13 14:35:22
        
        -- Данные события
        pullNumber = pullNumber,
        triggerText = triggerText,
        sourcePlayer = sourcePlayer or "Unknown",
        
        -- Контекст персонажа
        realm = GetCVar("realmName"),
        character = UnitName("player"),
        faction = UnitFactionGroup("player"),
        class = UnitClass("player"),
        target = UnitName("target") or "None",      -- Текущая цель игрока
        
        -- Профиль и настройки
        profileName = forcedProfileName or RABui_Settings.currentProfile or "Default",
        
        -- Информация о группе
        groupType = UnitInRaid("player") and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or "SOLO"),
        groupSize = UnitInRaid("player") and GetNumRaidMembers() or GetNumPartyMembers(),
        
        -- Состояние баров
        bars = {},
        
        -- Детальные настройки (опционально)
        settings = nil,
    }
    
    -- Добавляем детальные настройки если включено
    if RABLogger_Settings.saveDetailed then
        entry.settings = {
            updateInterval = RABui_Settings.updateInterval,
            hideincombat = RABui_Settings.hideincombat,
            hideactive = RABui_Settings.hideactive,
            partymode = RABui_Settings.partymode,
        }
    end
    
    -- Собираем состояние каждого бара
    local detailedData = {}
    
    for i, bar in ipairs(RABui_Bars) do
        -- Проверяем валидность бара
        if bar.buffKey and RAB_Buffs[bar.buffKey] then
            -- needraw=true для получения детальных данных по игрокам
            local buffed, fading, total, misc, mhead, hhead, mtext, htext, invert, raw = RAB_CallRaidBuffCheck(bar, true, true)
            
            table.insert(entry.bars, {
                index = i,
                buffKey = bar.buffKey,
                buffName = RAB_Buffs[bar.buffKey].name or bar.buffKey,
                label = bar.label,
                
                -- Текущее состояние
                buffed = buffed or 0,
                fading = fading or 0,
                total = total or 0,
                percentage = total > 0 and floor(buffed * 100 / total) or 0,
                misc = misc,
                
                -- Конфигурация бара
                groups = bar.groups or "",
                classes = bar.classes or "",
                priority = bar.priority or 1,
                selfLimit = bar.selfLimit or false,
            })
            
            -- Собираем детальные данные по игрокам (кто с баффом, кто без)
            if RABLogger_Settings.saveDetailed then
                local withBuff = {}
                local withoutBuff = {}
                
                -- Используем raw данные если есть, иначе собираем сами
                if raw and type(raw) == "table" and table.getn(raw) > 0 then
                    -- Используем данные от RAB_CallRaidBuffCheck
                    for _, playerData in ipairs(raw) do
                        if playerData and playerData.name then
                            local playerName = playerData.name
                            local playerClass = playerData.class or "Unknown"
                            local playerGroup = playerData.group or 0
                            
                            -- Форматируем имя с классом и группой
                            local formattedName = string.format("%s [%s; G%d]", playerName, playerClass, playerGroup)
                            
                            if playerData.buffed then
                                table.insert(withBuff, formattedName)
                            else
                                table.insert(withoutBuff, formattedName)
                            end
                        end
                    end
                else
                    -- Собираем данные напрямую обходом группы
                    for idx, unit, group in RAB_GroupMembers(bar) do
                        if RAB_IsEligible(unit, bar) then
                            local playerName = UnitName(unit)
                            if playerName then
                                local playerClass = RAB_UnitClass(unit) or "Unknown"
                                local formattedName = string.format("%s [%s; G%d]", playerName, playerClass, group or 0)
                                
                                -- Проверяем наличие баффа
                                local hasBuff = false
                                if RAB_Buffs[bar.buffKey].type == "special" then
                                    -- Для special баффов используем их функцию если есть
                                    if RAB_Buffs[bar.buffKey].sfunc then
                                        hasBuff = RAB_Buffs[bar.buffKey].sfunc(unit)
                                    end
                                else
                                    hasBuff = RAB_IsBuffUp(unit, bar.buffKey)
                                end
                                
                                if hasBuff then
                                    table.insert(withBuff, formattedName)
                                else
                                    table.insert(withoutBuff, formattedName)
                                end
                            end
                        end
                    end
                end
                
                -- Добавляем детальные данные для этого бара
                table.insert(detailedData, {
                    buffKey = bar.buffKey,
                    buffName = RAB_Buffs[bar.buffKey].name or bar.buffKey,
                    label = bar.label,
                    withBuff = withBuff,
                    withoutBuff = withoutBuff
                })
            end
        end
    end
    
    -- Сохраняем детальные данные в entry
    if RABLogger_Settings.saveDetailed and table.getn(detailedData) > 0 then
        entry.detailedData = detailedData
    end
    
    -- Записать в файл через CombatLogAdd() если включено и доступно
    if RABLogger_Settings.logToFile and CombatLogAdd then
        RABLogger_WriteToFile(entry)
    end
    
    -- Вывод в чат
    if RABLogger_Settings.logToChat then
        RABLogger_PrintLogEntry(entry)
    end
end

-- ============================================================================
-- Вывод в обычный чат
-- ============================================================================

function RABLogger_PrintLogEntry(entry)
    local targetText = entry.target and entry.target ~= "None" and (" | Target: " .. entry.target) or ""
    DEFAULT_CHAT_FRAME:AddMessage(
        string.format("|cff00ff00[RABLogger]|r Pull %d logged | %s (Server: %s) | %s | %d bars%s", 
            entry.pullNumber,
            entry.realTime,
            entry.serverTime,
            entry.profileName,
            table.getn(entry.bars),
            targetText),
        0.3, 1, 0.3
    )
end

-- ============================================================================
-- Запись в файл через SuperWoW CombatLogAdd()
-- Пишет напрямую в Logs/WoWCombatLog.txt
-- ============================================================================

function RABLogger_WriteToFile(entry)
    -- Заголовок события - основная информация
    local header = string.format("RABLOG_PULL: %s&%s&%s&%d&%s&%s&%s&%s&%s/%d&%s",
        entry.dateTime,           -- Полная дата-время
        entry.realTime,           -- Реальное время
        entry.serverTime,         -- Серверное время
        entry.pullNumber,         -- Номер pull
        entry.profileName,        -- Профиль
        entry.character,          -- Персонаж
        entry.realm,              -- Реалм
        entry.sourcePlayer,       -- Кто вызвал
        entry.groupType,          -- Тип группы
        entry.groupSize,          -- Размер группы
        entry.target or "None"    -- Текущая цель
    )
    
    CombatLogAdd(header)
    
    -- Данные по каждому бару (каждый бар отдельной строкой)
    for _, bar in ipairs(entry.bars) do
        local barLine = string.format("RABLOG_BAR: %d&%s&%s&%d&%d&%d&%d&%s&%s",
            bar.index,
            bar.buffKey,
            bar.label,
            bar.buffed,
            bar.total,
            bar.percentage,
            bar.fading,
            bar.groups,
            bar.classes
        )
        CombatLogAdd(barLine)
    end
    
    -- Детальные данные по игрокам (если есть)
    if entry.detailedData then
        for _, barData in ipairs(entry.detailedData) do
            -- Игроки С баффом
            if barData.withBuff and table.getn(barData.withBuff) > 0 then
                local playersList = table.concat(barData.withBuff, ", ")
                CombatLogAdd(string.format("RABLOG_PLAYERS_WITH: %s&%s", barData.buffKey, playersList))
            end
            
            -- Игроки БЕЗ баффа
            if barData.withoutBuff and table.getn(barData.withoutBuff) > 0 then
                local playersList = table.concat(barData.withoutBuff, ", ")
                CombatLogAdd(string.format("RABLOG_PLAYERS_WITHOUT: %s&%s", barData.buffKey, playersList))
            end
        end
    end
    
    -- Маркер конца записи
    CombatLogAdd(string.format("RABLOG_END: %d", entry.pullNumber))
end

-- ============================================================================
-- Перехват сообщений чата
-- ============================================================================

function RABLogger_ChatHook()
    if not RABLogger_Settings.enabled then
        return
    end
    
    local message = string.lower(arg1)
    local sourcePlayer = arg2
    
    -- Проверяем каждый триггер
    for _, pattern in ipairs(RABLogger_Settings.triggers) do
        local _, _, pullNum = string.find(message, pattern)
        if pullNum then
            pullNum = tonumber(pullNum)
            
            -- Проверяем существование профиля "RAID"
            local profileKey = RAB_GetProfileKey("RAID")
            if RABui_Settings.Layout[profileKey] then
                -- Логируем только профиль RAID
                RABLogger_LogStateForProfile("RAID", pullNum, arg1, sourcePlayer)
            else
                if RABLogger_Settings.logToChat then
                    DEFAULT_CHAT_FRAME:AddMessage(
                        "|cffff0000[RABLogger]|r Profile 'RAID' not found - logging skipped",
                        1, 0.5, 0
                    )
                end
            end
            
            break
        end
    end
end

-- ============================================================================
-- Инициализация
-- ============================================================================

-- ============================================================================
-- Переменные для отслеживания BigWigs pull timer
-- ============================================================================

RABLogger_BigWigsPullNumber = 0
RABLogger_BigWigsRequester = "Unknown"
RABLogger_BigWigsStartTime = 0
RABLogger_BigWigsLoggedAt = {}  -- Какие отметки уже залогированы для текущего pull

-- ============================================================================
-- Интеграция с BigWigs
-- ============================================================================

function RABLogger_RegisterBigWigsHooks()
    -- Регистрируем обработчик addon messages для BigWigs
    RAB_Core_Register("CHAT_MSG_ADDON", "rablogger_bigwigs", RABLogger_BigWigsAddonMessage)
    
    -- Создаём фрейм для отслеживания таймера
    local frame = CreateFrame("Frame", "RABLogger_BigWigsTimer")
    frame:SetScript("OnUpdate", RABLogger_BigWigsTimerUpdate)
    
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff00ff00[RABLogger]|r BigWigs integration enabled - will log on /pull command",
        0.3, 1, 0.3
    )
end

-- Обработчик addon messages от BigWigs
function RABLogger_BigWigsAddonMessage()
    if not RABLogger_Settings.enabled then
        return
    end
    
    -- arg1 = prefix ("BigWigs")
    -- arg2 = message ("PulltimerSync 10" или "PulltimerBroadcastSync 10")
    -- arg3 = channel ("RAID" или "PARTY")
    -- arg4 = sender (имя игрока)
    
    if arg1 == "BigWigs" and arg4 then
        local message = arg2 or ""
        local sender = arg4
        
        -- Парсим сообщение "PulltimerSync 10" или "PulltimerBroadcastSync 10"
        local _, _, duration = string.find(message, "PulltimerSync%s+(%d+)")
        if not duration then
            _, _, duration = string.find(message, "PulltimerBroadcastSync%s+(%d+)")
        end
        
        if duration then
            local dur = tonumber(duration)
            if dur and dur > 0 then
                -- Инициализация pullLogPoints
                if not RABLogger_Settings.pullLogPoints or type(RABLogger_Settings.pullLogPoints) ~= "table" then
                    RABLogger_Settings.pullLogPoints = {5}
                end
                
                local logPoint = RABLogger_Settings.pullLogPoints[1] or 5
                
                -- Если pull короче чем logpoint, логируем СРАЗУ
                if dur <= logPoint then
                    -- Проверяем существование профиля "RAID"
                    local profileKey = RAB_GetProfileKey("RAID")
                    if RABui_Settings.Layout[profileKey] then
                        RABLogger_LogStateForProfile(
                            "RAID",
                            dur,
                            string.format("BigWigs /pull %d (immediate)", dur),
                            sender
                        )
                        
                        if RABLogger_Settings.logToChat then
                            DEFAULT_CHAT_FRAME:AddMessage(
                                string.format("|cff00ff00[RABLogger]|r Logged RAID profile for pull %d immediately (by %s)", dur, sender),
                                0.3, 1, 0.3
                            )
                        end
                    else
                        if RABLogger_Settings.logToChat then
                            DEFAULT_CHAT_FRAME:AddMessage(
                                "|cffff0000[RABLogger]|r Profile 'RAID' not found - logging skipped",
                                1, 0.5, 0
                            )
                        end
                    end
                else
                    -- Pull длиннее logpoint - запоминаем и ждём
                    RABLogger_BigWigsPullNumber = dur
                    RABLogger_BigWigsRequester = sender
                    RABLogger_BigWigsStartTime = GetTime()
                    RABLogger_BigWigsLoggedAt = {}
                    
                    if RABLogger_Settings.logToChat then
                        DEFAULT_CHAT_FRAME:AddMessage(
                            string.format("|cff00ff00[RABLogger]|r BigWigs pull timer: %d sec by %s (will log at %d sec)", dur, sender, logPoint),
                            0.3, 1, 0.3
                        )
                    end
                end
            end
        end
        
        -- Отлов отмены таймера
        if string.find(message, "PulltimerStopSync") then
            RABLogger_BigWigsPullNumber = 0
            RABLogger_BigWigsStartTime = 0
            RABLogger_BigWigsLoggedAt = {}
        end
    end
end

-- OnUpdate обработчик для отслеживания оставшегося времени
function RABLogger_BigWigsTimerUpdate()
    if RABLogger_BigWigsPullNumber == 0 or RABLogger_BigWigsStartTime == 0 then
        return
    end
    
    -- Вычисляем сколько секунд осталось
    local elapsed = GetTime() - RABLogger_BigWigsStartTime
    local remaining = RABLogger_BigWigsPullNumber - elapsed
    
    -- Инициализация pullLogPoints если nil
    if not RABLogger_Settings.pullLogPoints or type(RABLogger_Settings.pullLogPoints) ~= "table" then
        RABLogger_Settings.pullLogPoints = {5}
    end
    
    -- Проверяем каждую точку логирования
    for _, logPoint in ipairs(RABLogger_Settings.pullLogPoints) do
        -- Если осталось примерно logPoint секунд и ещё не логировали
        if remaining <= logPoint and remaining > (logPoint - 0.5) and not RABLogger_BigWigsLoggedAt[logPoint] then
            -- Отмечаем что залогировали
            RABLogger_BigWigsLoggedAt[logPoint] = true
            
            -- Проверяем существование профиля "RAID"
            local profileKey = RAB_GetProfileKey("RAID")
            if RABui_Settings.Layout[profileKey] then
                RABLogger_LogStateForProfile(
                    "RAID",
                    RABLogger_BigWigsPullNumber, 
                    string.format("BigWigs /pull %d (at %d sec)", RABLogger_BigWigsPullNumber, logPoint),
                    RABLogger_BigWigsRequester
                )
                
                if RABLogger_Settings.logToChat then
                    DEFAULT_CHAT_FRAME:AddMessage(
                        string.format("|cff00ff00[RABLogger]|r Logged RAID profile for pull %d at %d sec mark (by %s)", 
                            RABLogger_BigWigsPullNumber, logPoint, RABLogger_BigWigsRequester),
                        0.3, 1, 0.3
                    )
                end
            else
                if RABLogger_Settings.logToChat then
                    DEFAULT_CHAT_FRAME:AddMessage(
                        "|cffff0000[RABLogger]|r Profile 'RAID' not found - logging skipped",
                        1, 0.5, 0
                    )
                end
            end
        end
    end
    
    -- Если таймер закончился, сбрасываем
    if remaining <= 0 then
        RABLogger_BigWigsPullNumber = 0
        RABLogger_BigWigsStartTime = 0
        RABLogger_BigWigsLoggedAt = {}
    end
end

function RABLogger_Init()
    -- Регистрируем обработчики событий через систему RABuffs
    RAB_Core_Register("CHAT_MSG_RAID", "rablogger_pull", RABLogger_ChatHook)
    RAB_Core_Register("CHAT_MSG_RAID_LEADER", "rablogger_pull", RABLogger_ChatHook)
    RAB_Core_Register("CHAT_MSG_RAID_WARNING", "rablogger_pull", RABLogger_ChatHook)
    RAB_Core_Register("CHAT_MSG_PARTY", "rablogger_pull", RABLogger_ChatHook)
    
    -- Подписка на события BigWigs (если установлен)
    RABLogger_RegisterBigWigsHooks()
    
    -- Приветственное сообщение
    DEFAULT_CHAT_FRAME:AddMessage(
        string.format("|cff00ff00RABuffs Logger v%s loaded!|r Type |cffffcc00/rablog help|r for commands", 
            RABLogger_Version),
        0.3, 1, 0.3
    )
    
    -- Информация о файловом логировании
    if CombatLogAdd then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff00ff00[RABLogger]|r SuperWoW detected - logging to |cffaaaaaa Logs/WoWCombatLog.txt|r",
            0.3, 1, 0.3
        )
    else
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffff0000[RABLogger]|r SuperWoW not detected - file logging unavailable!",
            1, 0.3, 0
        )
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffffaa00Install SuperWoW:|r https://github.com/balakethelock/SuperWoW",
            1, 0.8, 0
        )
    end
end

-- Регистрируем инициализацию при входе в мир
RAB_Core_Register("PLAYER_LOGIN", "rablogger_init", function()
    RABLogger_Init()
    return "remove"  -- Отписываемся после первого вызова
end)

-- ============================================================================
-- Slash команды
-- ============================================================================

SLASH_RABLOGGER1 = "/rablog"
SLASH_RABLOGGER2 = "/rablogger"

SlashCmdList["RABLOGGER"] = function(msg)
    local cmd, arg = string.match(msg, "^(%S+)%s*(.*)$")
    cmd = cmd and string.lower(cmd) or ""
    
    if cmd == "" or cmd == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00=== RABuffs Logger v" .. RABLogger_Version .. " ===|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Commands:|r")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00/rablog status|r - Show current settings")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00/rablog test|r - Test logging")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00/rablog toggle|r - Enable/disable logging")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00/rablog logpoint <N>|r - Log at N seconds before pull")
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Triggers:|r")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00/rablog trigger list|r - Show triggers")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00/rablog trigger add <pattern>|r - Add trigger")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00/rablog trigger remove <N>|r - Remove trigger N")
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00Important:|r Addon logs only 'RAID' profile. Create it first!")
        DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00Output:|r Logs/WoWCombatLog.txt (parse with RAB_parse_log.py)")
        
    elseif cmd == "toggle" then
        RABLogger_Settings.enabled = not RABLogger_Settings.enabled
        DEFAULT_CHAT_FRAME:AddMessage(
            string.format("|cff00ff00[RABLogger]|r Logging %s", 
                RABLogger_Settings.enabled and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"),
            1, 1, 0
        )
        
    elseif cmd == "status" then
        RABLogger_ShowStatus()
        
    elseif cmd == "logpoint" then
        -- /rablog logpoint <seconds>
        -- Устанавливает точку логирования (когда осталось X секунд)
        local seconds = tonumber(arg)
        if seconds and seconds > 0 then
            RABLogger_Settings.pullLogPoints = {seconds}
            DEFAULT_CHAT_FRAME:AddMessage(
                string.format("|cff00ff00[RABLogger]|r Pull log point set to %d seconds", seconds),
                0.3, 1, 0.3
            )
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Usage: /rablog logpoint <seconds>|r", 1, 0, 0)
            DEFAULT_CHAT_FRAME:AddMessage("Example: |cffffcc00/rablog logpoint 5|r - log when 5 sec remaining", 1, 1, 0)
            DEFAULT_CHAT_FRAME:AddMessage("Current: " .. (RABLogger_Settings.pullLogPoints[1] or 5) .. " seconds", 1, 1, 0)
        end
        
    elseif cmd == "test" then
        local profileKey = RAB_GetProfileKey("RAID")
        if RABui_Settings.Layout[profileKey] then
            RABLogger_LogStateForProfile("RAID", 0, "TEST", UnitName("player"))
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cff00ff00[RABLogger]|r Test entry logged (RAID profile)",
                1, 1, 0
            )
        else
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffff0000[RABLogger]|r Profile 'RAID' not found!",
                1, 0, 0
            )
            DEFAULT_CHAT_FRAME:AddMessage("Create it in RABuffs addon: |cffffcc00/rab profile save RAID|r", 1, 1, 0)
        end
        
    elseif cmd == "trigger" then
        RABLogger_HandleTriggerCommand(arg)
        
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Unknown command. Type |cffffcc00/rablog help|r", 1, 0, 0)
    end
end

-- ============================================================================
-- Управление триггерами
-- ============================================================================

function RABLogger_HandleTriggerCommand(arg)
    local subcmd, param = string.match(arg, "^(%S+)%s*(.*)$")
    subcmd = subcmd and string.lower(subcmd) or ""
    
    if subcmd == "" or subcmd == "list" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00=== Chat Triggers ===|r")
        for i, trigger in ipairs(RABLogger_Settings.triggers) do
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  %d. |cffffcc00%s|r", i, trigger))
        end
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("Add new: |cff00ff00/rablog trigger add <pattern>|r")
        DEFAULT_CHAT_FRAME:AddMessage("Remove: |cff00ff00/rablog trigger remove <N>|r")
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("Example: |cffffcc00/rablog trigger add go%%s+(%%d+)|r")
        
    elseif subcmd == "add" then
        if param and param ~= "" then
            table.insert(RABLogger_Settings.triggers, param)
            DEFAULT_CHAT_FRAME:AddMessage(
                string.format("|cff00ff00[RABLogger]|r Added trigger: |cffffcc00%s|r", param),
                0.3, 1, 0.3
            )
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Usage: /rablog trigger add <pattern>|r", 1, 0, 0)
            DEFAULT_CHAT_FRAME:AddMessage("Lua pattern examples:", 1, 1, 0)
            DEFAULT_CHAT_FRAME:AddMessage("  |cffffcc00go%%s+(%%d+)|r matches 'go 5'", 1, 1, 0)
            DEFAULT_CHAT_FRAME:AddMessage("  |cffffcc00ready%%s+(%%d+)|r matches 'ready 3'", 1, 1, 0)
        end
        
    elseif subcmd == "remove" then
        local index = tonumber(param)
        if index and RABLogger_Settings.triggers[index] then
            local removed = RABLogger_Settings.triggers[index]
            table.remove(RABLogger_Settings.triggers, index)
            DEFAULT_CHAT_FRAME:AddMessage(
                string.format("|cff00ff00[RABLogger]|r Removed trigger #%d: |cffffcc00%s|r", index, removed),
                1, 1, 0
            )
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Invalid trigger number|r", 1, 0, 0)
        end
        
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Usage:|r /rablog trigger <list|add|remove>", 1, 0, 0)
    end
end

-- ============================================================================
-- Просмотр логов
-- ============================================================================

function RABLogger_ShowLogs(count)
    local total = table.getn(RABLogger_Logs)
    if total == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RABLogger]|r No logs recorded yet", 1, 1, 0)
        return
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00=== RABuffs Logger History ===|r")
    
    local startIdx = math.max(1, total - count + 1)
    for i = startIdx, total do
        local entry = RABLogger_Logs[i]
        
        -- Заголовок записи
        local targetInfo = entry.target and entry.target ~= "None" 
            and ("|cffaaaaaa Target: " .. entry.target .. "|r") or ""
        DEFAULT_CHAT_FRAME:AddMessage(
            string.format("|cffaaaaaa#%d|r [%s / %s] Pull %d - %s %s", 
                i,
                entry.realTime,
                entry.serverTime,
                entry.pullNumber,
                entry.profileName,
                targetInfo)
        )
        
        -- Краткая статистика по барам
        for _, bar in ipairs(entry.bars) do
            local color
            if bar.percentage >= 95 then
                color = "|cff00ff00"  -- зеленый
            elseif bar.percentage >= 80 then
                color = "|cffffff00"  -- желтый
            elseif bar.percentage >= 60 then
                color = "|cffffaa00"  -- оранжевый
            else
                color = "|cffff0000"  -- красный
            end
            
            DEFAULT_CHAT_FRAME:AddMessage(
                string.format("  %-18s: %s%3d/%3d (%3d%%)|r", 
                    bar.label, color, bar.buffed, bar.total, bar.percentage)
            )
        end
        DEFAULT_CHAT_FRAME:AddMessage(" ")  -- пустая строка
    end
    
    DEFAULT_CHAT_FRAME:AddMessage(
        string.format("|cff00ff00Showing %d of %d total logs. Use /rablog detail <N> for more info|r", 
            math.min(count, total), total)
    )
end

-- ============================================================================
-- Детальный просмотр записи
-- ============================================================================

function RABLogger_ShowDetailedLog(index)
    local entry = RABLogger_Logs[index]
    if not entry then
        DEFAULT_CHAT_FRAME:AddMessage(
            string.format("|cffff0000Log entry #%d not found|r", index), 
            1, 0, 0
        )
        return
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00=== Detailed Log Entry #" .. index .. " ===|r")
    DEFAULT_CHAT_FRAME:AddMessage(string.format("Date/Time: %s", entry.dateTime))
    DEFAULT_CHAT_FRAME:AddMessage(string.format("Real Time: %s | Server Time: %s", entry.realTime, entry.serverTime))
    DEFAULT_CHAT_FRAME:AddMessage(string.format("Pull: %d | Trigger: \"%s\" by %s", entry.pullNumber, entry.triggerText, entry.sourcePlayer))
    DEFAULT_CHAT_FRAME:AddMessage(string.format("Character: %s-%s (%s)", entry.character, entry.realm, entry.class))
    DEFAULT_CHAT_FRAME:AddMessage(string.format("Profile: %s", entry.profileName))
    DEFAULT_CHAT_FRAME:AddMessage(string.format("Group: %s (%d players)", entry.groupType, entry.groupSize))
    
    local targetDisplay = entry.target or "None"
    DEFAULT_CHAT_FRAME:AddMessage(string.format("Target: %s", targetDisplay))
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    
    -- Проверяем, сохранены ли детальные данные по игрокам
    if entry.detailedData and table.getn(entry.detailedData) > 0 then
        -- Показываем детальную информацию из сохранённых данных
        for _, barData in ipairs(entry.detailedData) do
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00" .. barData.label .. " (" .. barData.buffName .. "):|r")
            
            if barData.withBuff and table.getn(barData.withBuff) > 0 then
                DEFAULT_CHAT_FRAME:AddMessage("  |cff00ff00С баффом:|r " .. table.concat(barData.withBuff, ", "))
            end
            
            if barData.withoutBuff and table.getn(barData.withoutBuff) > 0 then
                DEFAULT_CHAT_FRAME:AddMessage("  |cffff0000Без баффа:|r " .. table.concat(barData.withoutBuff, ", "))
            end
            
            if table.getn(barData.withBuff) == 0 and table.getn(barData.withoutBuff) == 0 then
                DEFAULT_CHAT_FRAME:AddMessage("  |cffaaaaaa(нет подходящих игроков)|r")
            end
            
            DEFAULT_CHAT_FRAME:AddMessage(" ")
        end
    else
        -- Старый формат - только статистика
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Buffs Status:|r")
        
        for _, bar in ipairs(entry.bars) do
            local statusIcon
            if bar.percentage >= 95 then
                statusIcon = "|cff00ff00[OK]|r"
            elseif bar.percentage >= 80 then
                statusIcon = "|cffffff00[WARN]|r"
            else
                statusIcon = "|cffff0000[LOW]|r"
            end
            
            DEFAULT_CHAT_FRAME:AddMessage(
                string.format("%s %-18s: %3d/%3d (%3d%%) | Fading: %d | Key: %s", 
                    statusIcon, bar.label, bar.buffed, bar.total, bar.percentage, bar.fading, bar.buffKey)
            )
        end
        
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa(Детальные данные недоступны - включите saveDetailed)|r")
    end
end

-- ============================================================================
-- Показать текущий статус настроек
-- ============================================================================

function RABLogger_ShowStatus()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00=== RABuffs Logger Status ===|r")
    DEFAULT_CHAT_FRAME:AddMessage(string.format("Version: |cffffcc00%s|r", RABLogger_Version))
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Current Settings:|r")
    DEFAULT_CHAT_FRAME:AddMessage(string.format("  Logging: %s", 
        RABLogger_Settings.enabled and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"))
    DEFAULT_CHAT_FRAME:AddMessage(string.format("  Chat notifications: %s", 
        RABLogger_Settings.logToChat and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"))
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Output File:|r")
    if CombatLogAdd then
        DEFAULT_CHAT_FRAME:AddMessage("  Location: |cffaaaaaa Logs/WoWCombatLog.txt|r")
        DEFAULT_CHAT_FRAME:AddMessage("  Status: |cff00ff00Writing enabled|r")
    else
        DEFAULT_CHAT_FRAME:AddMessage("  |cffff0000SuperWoW not detected!|r")
        DEFAULT_CHAT_FRAME:AddMessage("  Install from: |cffaaaaaa https://github.com/balakethelock/SuperWoW|r")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffaa00File logging unavailable without SuperWoW|r")
    end
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Active Triggers:|r")
    for i, trigger in ipairs(RABLogger_Settings.triggers) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  %d. |cffaaaaaa%s|r", i, trigger))
    end
    DEFAULT_CHAT_FRAME:AddMessage("  Manage: |cff00ff00/rablog trigger list|r")
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Profile Configuration:|r")
    local profileKey = RAB_GetProfileKey("RAID")
    if RABui_Settings.Layout[profileKey] then
        DEFAULT_CHAT_FRAME:AddMessage("  Profile 'RAID': |cff00ff00FOUND|r")
        DEFAULT_CHAT_FRAME:AddMessage("  Logging is ready!")
    else
        DEFAULT_CHAT_FRAME:AddMessage("  Profile 'RAID': |cffff0000NOT FOUND|r")
        DEFAULT_CHAT_FRAME:AddMessage("  Create it: |cffffcc00/rab profile save RAID|r")
    end
    DEFAULT_CHAT_FRAME:AddMessage(" ")
    
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00BigWigs Pull Timer:|r")
    local logPoints = RABLogger_Settings.pullLogPoints or {5}
    DEFAULT_CHAT_FRAME:AddMessage(string.format("  Log when remaining: |cffffcc00%s sec|r", table.concat(logPoints, ", ")))
    DEFAULT_CHAT_FRAME:AddMessage("  Change: |cff00ff00/rablog logpoint <N>|r")
end

-- ============================================================================
-- Статистика
-- ============================================================================

function RABLogger_ShowStats()
    local total = table.getn(RABLogger_Logs)
    if total == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[RABLogger]|r No logs recorded yet", 1, 1, 0)
        return
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00=== RABuffs Logger Statistics ===|r")
    DEFAULT_CHAT_FRAME:AddMessage(string.format("Total Logs: %d", total))
    
    -- Подсчет по профилям
    local profiles = {}
    for _, entry in ipairs(RABLogger_Logs) do
        profiles[entry.profileName] = (profiles[entry.profileName] or 0) + 1
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Profiles:|r")
    for profile, count in pairs(profiles) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s: %d pulls", profile, count))
    end
    
    -- Первая и последняя запись
    if total > 0 then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("First Log: %s", RABLogger_Logs[1].dateTime))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("Last Log: %s", RABLogger_Logs[total].dateTime))
    end
end

