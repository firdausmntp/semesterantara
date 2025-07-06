#!/bin/bash
# File: ids_analyzer.sh

SNORT_LOG="/var/log/snort/alert"
SURICATA_LOG="/var/log/suricata/fast.log"
SURICATA_JSON="/var/log/suricata/eve.json"

show_menu() {
    echo "=== IDS LOG ANALYZER ==="
    echo "1. Analyze Snort Alerts"
    echo "2. Analyze Suricata Alerts"
    echo "3. Generate Attack Report"
    echo "4. Real-time Alert Monitor"
    echo "5. Alert Statistics"
    echo "6. Export Alerts to CSV"
    echo "7. Clear All Logs"
    echo "8. Exit"
    echo "========================"
}

analyze_snort() {
    echo "📊 SNORT ALERT ANALYSIS"
    echo "======================="
    
    if [ ! -f "$SNORT_LOG" ]; then
        echo "❌ Snort log file not found!"
        return
    fi
    
    echo "Total alerts: $(wc -l < $SNORT_LOG)"
    echo
    echo "Top 10 Alert Types:"
    grep -o '\[.*\]' $SNORT_LOG | sort | uniq -c | sort -nr | head -10
    echo
    echo "Top 10 Source IPs:"
    awk '{print $NF}' $SNORT_LOG | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort | uniq -c | sort -nr | head -10
    echo
    echo "Recent alerts (last 10):"
    tail -10 $SNORT_LOG
}

analyze_suricata() {
    echo "📊 SURICATA ALERT ANALYSIS"
    echo "========================="
    
    if [ ! -f "$SURICATA_LOG" ]; then
        echo "❌ Suricata log file not found!"
        return
    fi
    
    echo "Total alerts: $(wc -l < $SURICATA_LOG)"
    echo
    echo "Top 10 Alert Types:"
    cut -d']' -f2 $SURICATA_LOG | cut -d'[' -f1 | sort | uniq -c | sort -nr | head -10
    echo
    echo "Recent alerts (last 10):"
    tail -10 $SURICATA_LOG
}

generate_report() {
    echo "📋 GENERATING ATTACK REPORT"
    echo "=========================="
    
    REPORT_FILE="ids_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "IDS ATTACK REPORT"
        echo "Generated: $(date)"
        echo "=================="
        echo
        
        if [ -f "$SNORT_LOG" ]; then
            echo "SNORT ALERTS:"
            echo "Total: $(wc -l < $SNORT_LOG)"
            echo "Top alerts:"
            grep -o '\[.*\]' $SNORT_LOG | sort | uniq -c | sort -nr | head -5
            echo
        fi
        
        if [ -f "$SURICATA_LOG" ]; then
            echo "SURICATA ALERTS:"
            echo "Total: $(wc -l < $SURICATA_LOG)"
            echo "Recent alerts:"
            tail -10 $SURICATA_LOG
            echo
        fi
        
    } > $REPORT_FILE
    
    echo "✅ Report generated: $REPORT_FILE"
}

realtime_monitor() {
    echo "📺 REAL-TIME ALERT MONITOR"
    echo "Press Ctrl+C to stop"
    echo "========================="
    
    if [ -f "$SNORT_LOG" ] && [ -f "$SURICATA_LOG" ]; then
        tail -f $SNORT_LOG $SURICATA_LOG
    elif [ -f "$SNORT_LOG" ]; then
        tail -f $SNORT_LOG
    elif [ -f "$SURICATA_LOG" ]; then
        tail -f $SURICATA_LOG
    else
        echo "❌ No log files found!"
    fi
}

alert_statistics() {
    echo "📈 ALERT STATISTICS"
    echo "=================="
    
    # Snort stats
    if [ -f "$SNORT_LOG" ]; then
        echo "SNORT:"
        echo "- Total alerts: $(wc -l < $SNORT_LOG)"
        echo "- Alerts today: $(grep "$(date +%m/%d)" $SNORT_LOG | wc -l)"
        echo "- Port scan alerts: $(grep -i "port scan" $SNORT_LOG | wc -l)"
        echo "- SSH alerts: $(grep -i "ssh" $SNORT_LOG | wc -l)"
        echo
    fi
    
    # Suricata stats
    if [ -f "$SURICATA_LOG" ]; then
        echo "SURICATA:"
        echo "- Total alerts: $(wc -l < $SURICATA_LOG)"
        echo "- Alerts today: $(grep "$(date +%m/%d)" $SURICATA_LOG | wc -l)"
        echo "- Port scan alerts: $(grep -i "port scan" $SURICATA_LOG | wc -l)"
        echo "- SSH alerts: $(grep -i "ssh" $SURICATA_LOG | wc -l)"
        echo
    fi
}

export_csv() {
    echo "📤 EXPORTING ALERTS TO CSV"
    echo "========================="
    
    CSV_FILE="ids_alerts_$(date +%Y%m%d_%H%M%S).csv"
    
    echo "Timestamp,IDS,Alert,Source_IP,Destination_IP" > $CSV_FILE
    
    if [ -f "$SNORT_LOG" ]; then
        awk '{print $1 " " $2 ",Snort," $0}' $SNORT_LOG >> $CSV_FILE
    fi
    
    if [ -f "$SURICATA_LOG" ]; then
        awk '{print $1 " " $2 ",Suricata," $0}' $SURICATA_LOG >> $CSV_FILE
    fi
    
    echo "✅ CSV exported: $CSV_FILE"
}

clear_logs() {
    echo "🗑️  CLEARING ALL LOGS"
    echo "===================="
    
    read -p "Are you sure? This will delete all IDS logs (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        sudo rm -f $SNORT_LOG $SURICATA_LOG $SURICATA_JSON
        echo "✅ All logs cleared!"
    else
        echo "❌ Operation cancelled"
    fi
}

# Main menu loop
while true; do
    show_menu
    read -p "Choose option (1-8): " choice
    
    case $choice in
        1) analyze_snort ;;
        2) analyze_suricata ;;
        3) generate_report ;;
        4) realtime_monitor ;;
        5) alert_statistics ;;
        6) export_csv ;;
        7) clear_logs ;;
        8) echo "👋 Goodbye!"; exit 0 ;;
        *) echo "❌ Invalid option" ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
    clear
done