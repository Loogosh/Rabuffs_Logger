#!/usr/bin/env python3
"""
RABuffs Logger - WoWCombatLog Parser
Parses Logs/WoWCombatLog.txt for RABLOG_PULL and RABLOG_BAR entries
Written by SuperWoW's CombatLogAdd() function
"""

import re
import json
import csv
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any
import argparse


def parse_combatlog_file(filepath: Path) -> List[Dict[str, Any]]:
    """
    Parse WoWCombatLog.txt for RABLOG entries
    
    Format:
    11/13 20:15:30.123  RABLOG_PULL: DateTime&RealTime&ServerTime&PullNum&Profile&Char&Realm&Source&GroupType/Size&Target
    11/13 20:15:30.125  RABLOG_BAR: idx&key&label&buffed&total&pct&fade&groups&classes
    11/13 20:15:30.126  RABLOG_BAR: ...
    11/13 20:15:30.127  RABLOG_END: PullNum
    """
    
    logs = []
    current_entry = None
    last_clear_index = -1  # Индекс последнего RABLOG_CLEAR
    temp_logs = []  # Временный список всех логов
    
    with filepath.open('r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            line = line.strip()
            
            # RABLOG_PULL: header line
            if 'RABLOG_PULL:' in line:
                # Format: MM/DD HH:MM:SS.mmm  RABLOG_PULL: data
                match = re.search(r'(\d+/\d+ \d+:\d+:\d+\.\d+)\s+RABLOG_PULL:\s+(.+)', line)
                if match:
                    log_timestamp = match.group(1)
                    data = match.group(2).split('&')
                    
                    if len(data) >= 9:
                        # Save previous entry if exists
                        if current_entry:
                            logs.append(current_entry)
                        
                        # Parse group type and size
                        group_parts = data[8].split('/')
                        group_type = group_parts[0] if len(group_parts) > 0 else "UNKNOWN"
                        group_size = int(group_parts[1]) if len(group_parts) > 1 else 0
                        
                        # Parse target (added in newer version)
                        target = data[9] if len(data) > 9 else "None"
                        
                        current_entry = {
                            'logTimestamp': log_timestamp,
                            'dateTime': data[0],
                            'realTime': data[1],
                            'serverTime': data[2],
                            'pullNumber': int(data[3]),
                            'profileName': data[4],
                            'character': data[5],
                            'realm': data[6],
                            'sourcePlayer': data[7],
                            'groupType': group_type,
                            'groupSize': group_size,
                            'target': target,
                            'bars': []
                        }
            
            # RABLOG_BAR: bar data line
            elif 'RABLOG_BAR:' in line and current_entry:
                match = re.search(r'RABLOG_BAR:\s+(.+)', line)
                if match:
                    data = match.group(1).split('&')
                    
                    if len(data) >= 7:
                        bar_entry = {
                            'index': int(data[0]),
                            'buffKey': data[1],
                            'label': data[2],
                            'buffed': int(data[3]),
                            'total': int(data[4]),
                            'percentage': int(data[5]),
                            'fading': int(data[6]),
                            'groups': data[7] if len(data) > 7 else '',
                            'classes': data[8] if len(data) > 8 else '',
                            'playersWithBuff': [],
                            'playersWithoutBuff': []
                        }
                        current_entry['bars'].append(bar_entry)
            
            # RABLOG_PLAYERS_WITH: players who have the buff
            elif 'RABLOG_PLAYERS_WITH:' in line and current_entry:
                match = re.search(r'RABLOG_PLAYERS_WITH:\s+(.+)', line)
                if match:
                    data = match.group(1).split('&', 1)
                    if len(data) >= 2:
                        buff_key = data[0]
                        players = data[1]
                        # Find corresponding bar and add players
                        for bar in current_entry['bars']:
                            if bar['buffKey'] == buff_key:
                                bar['playersWithBuff'] = players
                                break
            
            # RABLOG_PLAYERS_WITHOUT: players who don't have the buff
            elif 'RABLOG_PLAYERS_WITHOUT:' in line and current_entry:
                match = re.search(r'RABLOG_PLAYERS_WITHOUT:\s+(.+)', line)
                if match:
                    data = match.group(1).split('&', 1)
                    if len(data) >= 2:
                        buff_key = data[0]
                        players = data[1]
                        # Find corresponding bar and add players
                        for bar in current_entry['bars']:
                            if bar['buffKey'] == buff_key:
                                bar['playersWithoutBuff'] = players
                                break
            
            # RABLOG_CLEAR: clear marker
            elif 'RABLOG_CLEAR:' in line:
                # Маркер очистки - запоминаем индекс
                last_clear_index = len(temp_logs)
                # Сохраняем текущую entry если есть
                if current_entry:
                    temp_logs.append(current_entry)
                    current_entry = None
            
            # RABLOG_END: end marker
            elif 'RABLOG_END:' in line and current_entry:
                temp_logs.append(current_entry)
                current_entry = None
    
    # Add last entry if not closed
    if current_entry:
        temp_logs.append(current_entry)
    
    # Возвращаем только записи после последнего CLEAR
    if last_clear_index >= 0:
        logs = temp_logs[last_clear_index:]
        print(f"ℹ Found CLEAR marker at position {last_clear_index}, showing {len(logs)} entries after clear")
    else:
        logs = temp_logs
    
    return logs


def collect_unique_players(logs: List[Dict]) -> Dict[str, str]:
    """
    Collect unique players with their classes from all logs.
    
    Returns:
        Dict with player names as keys and class name as values
        Example: {'PlayerName': 'Warrior'}
    """
    players = {}
    
    for entry in logs:
        for bar in entry.get('bars', []):
            # Process players with buff
            players_with_raw = bar.get('playersWithBuff', '')
            if players_with_raw:
                for player in players_with_raw.split(', '):
                    # Parse format: "PlayerName [Class; G#]"
                    match = re.match(r'(.+?)\s*\[(.+?);\s*G(\d+)\]', player.strip())
                    if match:
                        name = match.group(1)
                        player_class = match.group(2)
                        # Store only if not already present (keep first occurrence)
                        if name not in players:
                            players[name] = player_class
            
            # Process players without buff
            players_without_raw = bar.get('playersWithoutBuff', '')
            if players_without_raw:
                for player in players_without_raw.split(', '):
                    match = re.match(r'(.+?)\s*\[(.+?);\s*G(\d+)\]', player.strip())
                    if match:
                        name = match.group(1)
                        player_class = match.group(2)
                        if name not in players:
                            players[name] = player_class
    
    return players


def export_text(logs: List[Dict], output_file: Path):
    """Export logs as formatted text with player details"""
    lines = []
    lines.append("=" * 80)
    lines.append("RABuffs Logger Export (from WoWCombatLog.txt)")
    lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"Total Entries: {len(logs)}")
    lines.append("=" * 80)
    lines.append("")
    
    # === НОВАЯ СЕКЦИЯ: Список игроков ===
    players = collect_unique_players(logs)
    if players:
        lines.append("=" * 80)
        lines.append(f"PLAYER ROSTER ({len(players)} players)")
        lines.append("=" * 80)
        lines.append("")
        
        # Группируем игроков по классам
        players_by_class = {}
        for name, player_class in players.items():
            if player_class not in players_by_class:
                players_by_class[player_class] = []
            players_by_class[player_class].append(name)
        
        # Сортируем классы по имени, внутри каждого класса сортируем игроков
        for class_name in sorted(players_by_class.keys()):
            player_names = sorted(players_by_class[class_name])
            lines.append(f"{class_name} : {', '.join(player_names)}")
        
        lines.append("")
        lines.append("=" * 80)
        lines.append("")
    
    for i, entry in enumerate(logs, 1):
        lines.append(f"--- Entry #{i} ---")
        lines.append(f"Log Timestamp: {entry.get('logTimestamp', 'N/A')}")
        lines.append(f"DateTime: {entry.get('dateTime', 'N/A')}")
        lines.append(f"Real Time: {entry.get('realTime', 'N/A')} | Server Time: {entry.get('serverTime', 'N/A')}")
        lines.append(f"Pull: {entry.get('pullNumber', 'N/A')} | Triggered by: {entry.get('sourcePlayer', 'N/A')}")
        lines.append(f"Character: {entry.get('character', 'N/A')}-{entry.get('realm', 'N/A')}")
        lines.append(f"Profile: {entry.get('profileName', 'N/A')} | Group: {entry.get('groupType', 'N/A')} ({entry.get('groupSize', 0)} players)")
        lines.append(f"Target: {entry.get('target', 'None')}")
        lines.append("")
        lines.append("Buffs Status:")
        
        for bar in entry.get('bars', []):
            # Основная статистика
            pct = bar.get('percentage', 0)
            status = "✓" if pct >= 95 else "⚠" if pct >= 80 else "✗"
            lines.append(f"  [{status}] {bar.get('label', 'N/A'):20s}: {bar.get('buffed', 0):3d}/{bar.get('total', 0):3d} ({pct:3d}%) [Fading: {bar.get('fading', 0)}]")
            
            # Детальная информация по игрокам (только имена для текста)
            players_with_raw = bar.get('playersWithBuff', '')
            players_without_raw = bar.get('playersWithoutBuff', '')
            
            # Извлекаем только имена (без [Class; G#])
            if players_with_raw:
                names_with = extract_player_names(players_with_raw)
                if names_with:
                    lines.append(f"      С баффом: {names_with}")
            
            if players_without_raw:
                names_without = extract_player_names(players_without_raw)
                if names_without:
                    lines.append(f"      БЕЗ баффа: {names_without}")
            
            # Разделитель между барами
            if players_with_raw or players_without_raw:
                lines.append("")
        
        lines.append("")
    
    output_file.write_text('\n'.join(lines), encoding='utf-8')
    print(f"✓ Text export saved to: {output_file}")


def export_csv(logs: List[Dict], output_file: Path):
    """Export logs as CSV with player details in separate columns"""
    with output_file.open('w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        
        # Header
        writer.writerow([
            'EntryID', 'LogTimestamp', 'DateTime', 'RealTime', 'ServerTime', 
            'PullNumber', 'Character', 'Realm', 'Profile', 'GroupType', 'GroupSize',
            'SourcePlayer', 'Target', 'BuffLabel', 'BuffKey', 'Buffed', 'Total',
            'Percentage', 'Fading', 'TargetGroups', 'TargetClasses',
            'PlayersWithBuff_Names', 'PlayersWithBuff_Classes', 'PlayersWithBuff_Groups',
            'PlayersWithoutBuff_Names', 'PlayersWithoutBuff_Classes', 'PlayersWithoutBuff_Groups'
        ])
        
        # Data
        for i, entry in enumerate(logs, 1):
            for bar in entry.get('bars', []):
                # Парсим игроков с баффом
                players_with_raw = bar.get('playersWithBuff', '')
                with_names, with_classes, with_groups = parse_player_list(players_with_raw)
                
                # Парсим игроков без баффа
                players_without_raw = bar.get('playersWithoutBuff', '')
                without_names, without_classes, without_groups = parse_player_list(players_without_raw)
                
                writer.writerow([
                    i,
                    entry.get('logTimestamp', ''),
                    entry.get('dateTime', ''),
                    entry.get('realTime', ''),
                    entry.get('serverTime', ''),
                    entry.get('pullNumber', 0),
                    entry.get('character', ''),
                    entry.get('realm', ''),
                    entry.get('profileName', ''),
                    entry.get('groupType', ''),
                    entry.get('groupSize', 0),
                    entry.get('sourcePlayer', ''),
                    entry.get('target', 'None'),
                    bar.get('label', ''),
                    bar.get('buffKey', ''),
                    bar.get('buffed', 0),
                    bar.get('total', 0),
                    bar.get('percentage', 0),
                    bar.get('fading', 0),
                    bar.get('groups', ''),
                    bar.get('classes', ''),
                    with_names,       # Только имена
                    with_classes,     # Только классы
                    with_groups,      # Только группы
                    without_names,    # Только имена
                    without_classes,  # Только классы
                    without_groups    # Только группы
                ])
    
    print(f"✓ CSV export saved to: {output_file}")


def extract_player_names(player_string: str) -> str:
    """
    Extract only player names from format: "Name1 [Class1; G1], Name2 [Class2; G2]"
    Returns: "Name1, Name2"
    """
    if not player_string or player_string.strip() == '':
        return ''
    
    names = []
    players = player_string.split(', ')
    
    for player in players:
        # Parse format: "PlayerName [Class; G#]"
        match = re.match(r'(.+?)\s*\[', player.strip())
        if match:
            names.append(match.group(1))
        else:
            # Если формат не распознан, берём всё до первого пробела
            name = player.strip().split()[0] if player.strip() else ''
            if name:
                names.append(name)
    
    return ', '.join(names)


def parse_player_list(player_string: str) -> tuple:
    """
    Parse player list from format: "Name1 [Class1; G1], Name2 [Class2; G2]"
    Returns: (names, classes, groups) as comma-separated strings
    """
    if not player_string or player_string.strip() == '':
        return '', '', ''
    
    names = []
    classes = []
    groups = []
    
    # Split by comma
    players = player_string.split(', ')
    
    for player in players:
        # Parse format: "PlayerName [Class; G#]"
        match = re.match(r'(.+?)\s*\[(.+?);\s*G(\d+)\]', player.strip())
        if match:
            names.append(match.group(1))
            classes.append(match.group(2))
            groups.append(match.group(3))
    
    return ', '.join(names), ', '.join(classes), ', '.join(groups)


def export_json(logs: List[Dict], output_file: Path):
    """Export logs as JSON"""
    data = {
        'version': '1.0.0',
        'source': 'WoWCombatLog.txt',
        'exported': datetime.now().isoformat(),
        'totalEntries': len(logs),
        'logs': logs
    }
    
    output_file.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding='utf-8')
    print(f"✓ JSON export saved to: {output_file}")


def show_statistics(logs: List[Dict]):
    """Show basic statistics about the logs"""
    if not logs:
        print("No logs found")
        return
    
    print("\n" + "=" * 60)
    print("Statistics")
    print("=" * 60)
    
    print(f"Total entries: {len(logs)}")
    
    # Count by profile
    profiles = {}
    for entry in logs:
        profile = entry.get('profileName', 'Unknown')
        profiles[profile] = profiles.get(profile, 0) + 1
    
    print("\nPulls by Profile:")
    for profile, count in sorted(profiles.items(), key=lambda x: x[1], reverse=True):
        print(f"  {profile}: {count}")
    
    # Average buff coverage
    buff_stats = {}
    for entry in logs:
        for bar in entry.get('bars', []):
            label = bar.get('label', 'Unknown')
            if label not in buff_stats:
                buff_stats[label] = {'total': 0, 'count': 0}
            buff_stats[label]['total'] += bar.get('percentage', 0)
            buff_stats[label]['count'] += 1
    
    print("\nAverage Buff Coverage:")
    for label, stats in sorted(buff_stats.items(), key=lambda x: x[1]['total']/x[1]['count'], reverse=True):
        avg = stats['total'] / stats['count']
        print(f"  {label:20s}: {avg:5.1f}%")
    
    # Time range
    if logs:
        print(f"\nFirst entry: {logs[0].get('dateTime', 'N/A')}")
        print(f"Last entry: {logs[-1].get('dateTime', 'N/A')}")
    
    print("=" * 60 + "\n")


def main():
    parser = argparse.ArgumentParser(
        description='Parse WoWCombatLog.txt for RABuffs Logger entries and export to various formats'
    )
    parser.add_argument(
        '-i', '--input',
        type=Path,
        help='Input WoWCombatLog.txt file (default: Logs/WoWCombatLog.txt)'
    )
    parser.add_argument(
        '-o', '--output',
        type=Path,
        help='Output file (default: rabuffs_combatlog.{format})'
    )
    parser.add_argument(
        '-f', '--format',
        choices=['text', 'csv', 'json', 'all'],
        default='text',
        help='Export format (default: text)'
    )
    parser.add_argument(
        '-s', '--stats',
        action='store_true',
        help='Show statistics only (no export)'
    )
    
    args = parser.parse_args()
    
    # Find input file
    if args.input:
        input_file = args.input
    else:
        # Try to auto-detect
        possible_paths = [
            Path('Logs/WoWCombatLog.txt'),
            Path('../Logs/WoWCombatLog.txt'),
            Path('../../Logs/WoWCombatLog.txt'),
            Path('WoWCombatLog.txt'),
        ]
        
        input_file = None
        for path in possible_paths:
            if path.exists():
                input_file = path
                break
        
        if not input_file:
            print("❌ Could not find WoWCombatLog.txt")
            print("Please specify path with --input")
            print("\nNote: File is located in WoW/Logs/WoWCombatLog.txt")
            print("Combat logging is always active in SuperWoW")
            return
    
    if not input_file.exists():
        print(f"❌ File not found: {input_file}")
        return
    
    print(f"📂 Reading: {input_file}")
    print(f"   File size: {input_file.stat().st_size / 1024 / 1024:.2f} MB")
    
    # Parse logs
    try:
        logs = parse_combatlog_file(input_file)
        print(f"✓ Found {len(logs)} RABLOG entries")
    except Exception as e:
        print(f"❌ Error parsing file: {e}")
        import traceback
        traceback.print_exc()
        return
    
    if not logs:
        print("⚠ No RABLOG entries found in file")
        print("\nMake sure:")
        print("1. RABuffs Logger is loaded")
        print("2. File logging is enabled: /rablog file")
        print("3. You've triggered some pulls or used: /rablog test")
        return
    
    # Show statistics if requested
    if args.stats:
        show_statistics(logs)
        return
    
    # Export
    if args.format == 'all':
        formats = ['text', 'csv', 'json']
    else:
        formats = [args.format]
    
    for fmt in formats:
        if args.output:
            output_file = args.output
        else:
            output_file = Path(f'rabuffs_combatlog.{fmt}')
        
        if fmt == 'text':
            output_file = output_file.with_suffix('.txt')
            export_text(logs, output_file)
        elif fmt == 'csv':
            output_file = output_file.with_suffix('.csv')
            export_csv(logs, output_file)
        elif fmt == 'json':
            output_file = output_file.with_suffix('.json')
            export_json(logs, output_file)
    
    # Show quick statistics
    show_statistics(logs)


if __name__ == '__main__':
    main()

