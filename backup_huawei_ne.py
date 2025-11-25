import telnetlib
import time
from datetime import datetime
from ftplib import FTP
import requests
import os
from dotenv import load_dotenv

# Carregar variáveis do .env
load_dotenv()

HUAWEI_IP = os.getenv("HUAWEI_IP")
HUAWEI_PORT = int(os.getenv("HUAWEI_PORT"))
HUAWEI_USER = os.getenv("HUAWEI_USER")
HUAWEI_PASSWORD = os.getenv("HUAWEI_PASSWORD")

FTP_IP = os.getenv("FTP_IP")
FTP_PORT = int(os.getenv("FTP_PORT"))
FTP_USER = os.getenv("FTP_USER")
FTP_PASSWORD = os.getenv("FTP_PASSWORD")

TELEGRAM_TOKEN = os.getenv("TELEGRAM_TOKEN")
CHAT_ID = os.getenv("TELEGRAM_CHAT_ID")

LOCAL_BACKUP_PATH = os.getenv("LOCAL_BACKUP_PATH", "/backups")
LOCAL_LOG_PATH = os.getenv("LOCAL_LOG_PATH", "/logs")

os.makedirs(LOCAL_BACKUP_PATH, exist_ok=True)
os.makedirs(LOCAL_LOG_PATH, exist_ok=True)

# ===========================
#   Funções auxiliares
# ===========================

def write_log(msg):
    """Escreve no arquivo e no terminal"""
    print(msg)
    logfile = f"{LOCAL_LOG_PATH}/backup_{datetime.now().strftime('%d-%m-%Y')}.log"
    with open(logfile, "a") as f:
        f.write(msg + "\n")

def wait(tn, text, timeout=20):
    return tn.read_until(text.encode("ascii"), timeout=timeout)

def send_cmd(tn, cmd, delay=1):
    tn.write(cmd.encode("ascii") + b"\n")
    time.sleep(delay)
    out = tn.read_very_eager().decode("ascii")
    write_log(out)
    return out

def ftp_download(remote, local):
    try:
        ftp = FTP()
        ftp.connect(FTP_IP, FTP_PORT)
        ftp.login(FTP_USER, FTP_PASSWORD)

        with open(local, "wb") as f:
            ftp.retrbinary(f"RETR " + remote, f.write)

        ftp.quit()
        write_log(f"✔ DOWNLOAD OK: {remote}")
    except Exception as e:
        write_log(f"❌ ERRO FTP DOWNLOAD: {e}")

def send_file_telegram(filepath):
    try:
        url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendDocument"
        with open(filepath, "rb") as f:
            data = {"chat_id": CHAT_ID}
            files = {"document": f}
            r = requests.post(url, data=data, files=files)

        if r.status_code == 200:
            write_log(f"✔ Enviado ao Telegram: {filepath}")
        else:
            write_log(f"❌ ERRO Telegram ({r.status_code}): {r.text}")

    except Exception as e:
        write_log(f"❌ EXCEÇÃO Telegram: {e}")

# ===========================
#   Backup Huawei
# ===========================

def run_backup():
    date = datetime.now().strftime("%d%m%Y")

    write_log("===================================")
    write_log("  INICIANDO BACKUP HUAWEI NE")
    write_log("===================================")

    try:
        tn = telnetlib.Telnet(HUAWEI_IP, HUAWEI_PORT, timeout=10)

        # LOGIN
        wait(tn, "Username")
        tn.write(HUAWEI_USER.encode("ascii") + b"\n")

        wait(tn, "Password")
        tn.write(HUAWEI_PASSWORD.encode("ascii") + b"\n")

        wait(tn, ">")
        write_log("✔ Login efetuado com sucesso.")

        # ------------------------------
        # BACKUP VS BRAS
        # ------------------------------
        bras_filename = f"bras_{date}.cfg"

        write_log("📌 BACKUP VS bras")
        send_cmd(tn, f"save {bras_filename}")
        send_cmd(tn, "y")

        # FTP envio bras
        send_cmd(tn, f"ftp {FTP_IP}")
        send_cmd(tn, FTP_USER)
        send_cmd(tn, FTP_PASSWORD)
        send_cmd(tn, f"put {bras_filename}")
        send_cmd(tn, "q")

        # ------------------------------
        # BACKUP VS BGP
        # ------------------------------
        bgp_filename = f"bgp_{date}.cfg"

        write_log("📌 TROCAR PARA VS BGP")
		time.sleep(5)
        send_cmd(tn, "sw")
        send_cmd(tn, "switch vir")
        send_cmd(tn, "switch virtual-system BGP")

        write_log("📌 BACKUP VS BGP")
        send_cmd(tn, f"save {bgp_filename}")
        send_cmd(tn, "y")

        # FTP envio BGP
        send_cmd(tn, f"ftp {FTP_IP}")
        send_cmd(tn, FTP_USER)
        send_cmd(tn, FTP_PASSWORD)
        send_cmd(tn, f"put {bgp_filename}")
        send_cmd(tn, "q")

        tn.write(b"quit\n")
        tn.close()

        # ------------------------------
        # DOWNLOAD DO MIKROTIK
        # ------------------------------
        ftp_download(bras_filename, f"{LOCAL_BACKUP_PATH}/{bras_filename}")
        ftp_download(bgp_filename, f"{LOCAL_BACKUP_PATH}/{bgp_filename}")

        # ------------------------------
        # ENVIO PARA TELEGRAM
        # ------------------------------
        send_file_telegram(f"{LOCAL_BACKUP_PATH}/{bras_filename}")
        send_file_telegram(f"{LOCAL_BACKUP_PATH}/{bgp_filename}")

        write_log("✔ BACKUP FINALIZADO COM SUCESSO")

    except Exception as e:
        write_log(f"❌ ERRO GERAL: {e}")

if __name__ == "__main__":
    run_backup()
