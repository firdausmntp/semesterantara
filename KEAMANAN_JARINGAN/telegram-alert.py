import requests
import re
import time
import json
from datetime import datetime

def send_alert(msg, token, chat_id):
    """Mengirim pesan ke Telegram dengan verify=False untuk bypass SSL verification."""
    url = f'https://api.telegram.org/bot{token}/sendMessage'
    payload = {'chat_id': chat_id, 'text': msg, 'parse_mode': 'Markdown'}
    try:
        response = requests.post(url, data=payload, verify=False, timeout=5)
        if response.status_code != 200:
            print(f"Error mengirim ke Telegram: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"Error koneksi Telegram: {e}")

def format_snort_alert(line):
    """Memformat pesan notifikasi untuk Snort dari log alert_fast."""
    try:
        # Contoh format log: 07/05/25-21:45:22.123456 [**] [1:1000001:1] Test Snort Alert [**] [Priority: 0] {IP} 192.168.1.100 -> 10.0.0.50
        pattern = r'(\d{2}/\d{2}/\d{2}-\d{2}:\d{2}:\d{2}\.\d+).*?\[1:(\d+):(\d+)\]\s(.*?)\s\[\*\*\].*?\{(\w+)\}\s(\S+)\s->\s(\S+)'
        match = re.match(pattern, line.strip())
        if not match:
            return None

        timestamp, sid, rev, signature, proto, src_ip, dest_ip = match.groups()
        # Format waktu ke format yang lebih mudah dibaca
        try:
            time_obj = datetime.strptime(timestamp, '%m/%d/%y-%H:%M:%S.%f')
            formatted_time = time_obj.strftime('%Y-%m-%d %H:%M:%S')
        except:
            formatted_time = timestamp

        msg = (
            f"🚨 *Snort Alert*\n"
            f"🕒 *Time*: {formatted_time}\n"
            f"📜 *Signature*: {signature}\n"
            f"🔢 *SID:Rev*: {sid}:{rev}\n"
            f"🌐 *Source IP*: {src_ip}\n"
            f"🏁 *Destination IP*: {dest_ip}\n"
            f"🔌 *Protocol*: {proto}"
        )
        return msg
    except Exception as e:
        print(f"Error memformat pesan Snort: {e}")
        return None

def format_suricata_alert(data):
    """Memformat pesan notifikasi untuk Suricata dari eve.json."""
    try:
        signature = data['alert']['signature']
        src_ip = data['src_ip']
        dest_ip = data['dest_ip']
        timestamp = data.get('timestamp', 'N/A')
        proto = data.get('proto', 'N/A')
        category = data['alert'].get('category', 'N/A')

        try:
            time_obj = datetime.strptime(timestamp, '%Y-%m-%dT%H:%M:%S.%f%z')
            formatted_time = time_obj.strftime('%Y-%m-%d %H:%M:%S %Z')
        except:
            formatted_time = timestamp

        msg = (
            f"🚨 *Suricata Alert*\n"
            f"🕒 *Time*: {formatted_time}\n"
            f"📜 *Signature*: {signature}\n"
            f"🌐 *Source IP*: {src_ip}\n"
            f"🏁 *Destination IP*: {dest_ip}\n"
            f"🔌 *Protocol*: {proto}\n"
            f"📋 *Category*: {category}"
        )
        return msg
    except KeyError as e:
        print(f"Error memformat pesan Suricata: {e}")
        return None

def monitor_logs(snort_log_path, suricata_log_path, token, chat_id):
    """Memantau log Snort dan Suricata, mengirim alert ke Telegram."""
    print(f"Memulai pemantauan log Snort: {snort_log_path}")
    print(f"Memulai pemantauan log Suricata: {suricata_log_path}")

    # Buka file log Snort
    snort_file = None
    if snort_log_path:
        try:
            snort_file = open(snort_log_path, 'r')
            snort_file.seek(0, 2)  # Pindah ke akhir file
        except FileNotFoundError:
            print(f"File Snort {snort_log_path} tidak ditemukan")
            snort_file = None

    # Buka file log Suricata
    suricata_file = None
    if suricata_log_path:
        try:
            suricata_file = open(suricata_log_path, 'r')
            suricata_file.seek(0, 2)  # Pindah ke akhir file
        except FileNotFoundError:
            print(f"File Suricata {suricata_log_path} tidak ditemukan")
            suricata_file = None

    while True:
        # Proses log Snort
        if snort_file:
            line = snort_file.readline()
            if line:
                msg = format_snort_alert(line)
                if msg:
                    send_alert(msg, token, chat_id)
            else:
                time.sleep(0.1)  # Hindari penggunaan CPU berlebih

        # Proses log Suricata
        if suricata_file:
            line = suricata_file.readline()
            if line:
                try:
                    data = json.loads(line.strip())
                    if 'alert' in data:
                        msg = format_suricata_alert(data)
                        if msg:
                            send_alert(msg, token, chat_id)
                except json.JSONDecodeError:
                    print("Error: Format JSON Suricata tidak valid")
                except Exception as e:
                    print(f"Error memproses log Suricata: {e}")
            else:
                time.sleep(0.1)  # Hindari penggunaan CPU berlebih

def main():
    # Konfigurasi
    token = 'YOUR_BOT_TOKEN'  # Ganti dengan token bot Telegram Anda
    chat_id = 'YOUR_CHAT_ID'  # Ganti dengan chat ID Telegram Anda
    snort_log_path = '/var/log/snort/snort.alert.fast'  # Path ke log alert_fast Snort
    suricata_log_path = '/var/log/suricata/eve.json'  # Path ke log Suricata

    # Jalankan pemantauan log
    monitor_logs(snort_log_path, suricata_log_path, token, chat_id)

if __name__ == "__main__":
    main()
