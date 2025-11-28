#!/bin/bash

echo "======================================================"
echo "   INSTALADOR AUTOMÁTICO - BACKUP HUAWEI EM DOCKER"
echo "======================================================"

# -----------------------------
# Atualizar e instalar pacotes
# -----------------------------
echo "[1/8] Atualizando sistema..."
apt update && apt upgrade -y

echo "[2/8] Instalando dependências..."
apt install -y ca-certificates curl gnupg lsb-release sudo

# -----------------------------
# Instalar Docker
# -----------------------------
echo "[3/8] Instalando Docker..."

mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
  $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

echo "[4/8] Docker instalado com sucesso!"
docker --version
docker compose version

# -----------------------------
# Criar diretório do projeto
# -----------------------------
echo "[5/8] Criando diretório /opt/huawei-backup..."

mkdir -p /opt/huawei-backup/backups
mkdir -p /opt/huawei-backup/logs

cd /opt/huawei-backup

# -----------------------------
# Criar arquivos do projeto
# -----------------------------
echo "[6/8] Criando arquivos do sistema..."

# ----------------------------------------------------
# DOCKERFILE CORRIGIDO (FINAL)
# ----------------------------------------------------
cat << 'EOF' > Dockerfile
FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    cron \
    rsyslog \
    telnet \
    ftp \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backup_huawei_ne.py .
COPY .env .

RUN mkdir -p /backups
RUN mkdir -p /logs

RUN echo "0 3 * * 1 root python3 /app/backup_huawei_ne.py >> /var/log/cron.log 2>&1" > /etc/cron.d/backup-cron
RUN chmod 0644 /etc/cron.d/backup-cron
RUN crontab /etc/cron.d/backup-cron

RUN touch /var/log/cron.log
RUN chmod 666 /var/log/cron.log

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
EOF


# ----------------------------------------------------
# DOCKER-COMPOSE
# ----------------------------------------------------
cat << 'EOF' > docker-compose.yml

services:
  huawei-backup:
    build: .
    container_name: huawei-backup
    restart: always
    env_file:
      - .env
    volumes:
      - /opt/huawei-backup/backups:/backups
      - /opt/huawei-backup/logs:/logs
    tty: true
EOF


# ----------------------------------------------------
# ENTRYPOINT.SH CORRETO
# ----------------------------------------------------
cat << 'EOF' > entrypoint.sh
#!/bin/bash

touch /var/log/cron.log
chmod 666 /var/log/cron.log

service rsyslog start
service cron start

echo "=== Serviços Iniciados ==="
echo "Cron e rsyslog estão rodando."
echo "Monitorando /var/log/cron.log..."
echo "==========================="

tail -f /var/log/cron.log
EOF

chmod +x entrypoint.sh


# ----------------------------------------------------
# REQUIREMENTS
# ----------------------------------------------------
cat << 'EOF' > requirements.txt
python-dotenv
requests
EOF


# ----------------------------------------------------
# .ENV MODELO
# ----------------------------------------------------
cat << 'EOF' > .env
# ------------ HUAWEI ------------
HUAWEI_IP=100.64.70.22
HUAWEI_PORT=23
HUAWEI_USER=bkphuawei
HUAWEI_PASSWORD=B3ni0808!@#$

# ------------- FTP --------------
FTP_IP=170.83.184.22
FTP_PORT=21
FTP_USER=1
FTP_PASSWORD=1

# ---------- TELEGRAM -----------
TELEGRAM_TOKEN=SEU_TOKEN_AQUI
TELEGRAM_CHAT_ID=SEU_CHAT_ID_AQUI

# ---------- DIRETÓRIOS ----------
LOCAL_BACKUP_PATH=/backups
LOCAL_LOG_PATH=/logs

# ---------- OPCIONAIS ----------
CMD_DELAY=1
TELNET_TIMEOUT=20
EOF


# ----------------------------------------------------
# SCRIPT PYTHON PRINCIPAL
# ----------------------------------------------------
cat << 'EOF' > backup_huawei_ne.py
import telnetlib
import time
from datetime import datetime
from ftplib import FTP
import requests
import os
from dotenv import load_dotenv

load_dotenv()

HUAWEI_IP = os.getenv("HUAWEI_IP")
HUAWEI_PORT = int(os.getenv("HUAWEI_PORT"))
HUAWEI_USER = os.getenv("HUAWEI_USER")
HUAWEI_PASSWORD = os.getenv("HUAWEI_PASSWORD")

FTP_IP = os.getenv("FTP_IP")
FTP_PORT = int(os.getenv("FTP_PORT"))
FTP_USER = os.getenv("FTP_USER")
FTP_PASSWORD = os.getenv("FTP_PASSWORD")

LOCAL_BACKUP_PATH = os.getenv("LOCAL_BACKUP_PATH")
LOCAL_LOG_PATH = os.getenv("LOCAL_LOG_PATH")

os.makedirs(LOCAL_LOG_PATH, exist_ok=True)

def write_log(text):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_file = f"{LOCAL_LOG_PATH}/backup_{datetime.now().strftime('%d-%m-%Y')}.log"
    with open(log_file, "a") as f:
        f.write(f"[{timestamp}] {text}\n")
    print(text)

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
            ftp.retrbinary(f"RETR {remote}", f.write)

        ftp.quit()
        write_log(f"✔ DOWNLOAD OK: {remote}")
    except Exception as e:
        write_log(f"❌ ERRO FTP DOWNLOAD: {e}")

def run_backup():
    date = datetime.now().strftime("%d%m%Y")
    write_log("===================================")
    write_log(" INICIANDO BACKUP HUAWEI NE")
    write_log("===================================")

    try:
        tn = telnetlib.Telnet(HUAWEI_IP, HUAWEI_PORT, timeout=10)

        wait(tn, "Username")
        tn.write(HUAWEI_USER.encode("ascii") + b"\n")

        wait(tn, "Password")
        tn.write(HUAWEI_PASSWORD.encode("ascii") + b"\n")

        wait(tn, ">")
        write_log("✔ Login realizado com sucesso.")

        # BACKUP ADMIN
        filename_admin = f"admin_{date}.cfg"
        send_cmd(tn, f"save {filename_admin}")
        send_cmd(tn, "y")

        # FTP envio admin
        send_cmd(tn, f"ftp {FTP_IP}")
        send_cmd(tn, FTP_USER)
        send_cmd(tn, FTP_PASSWORD)
        send_cmd(tn, f"put {filename_admin}")
        send_cmd(tn, "q")

        # SWITCH VS BGP
        send_cmd(tn, "sw")
        send_cmd(tn, "switch vir")
        send_cmd(tn, "switch virtual-system BGP")

        # BACKUP BGP
        filename_bgp = f"bgp_{date}.cfg"
        send_cmd(tn, f"save {filename_bgp}")
        send_cmd(tn, "y")

        # FTP envio BGP
        send_cmd(tn, f"ftp {FTP_IP}")
        send_cmd(tn, FTP_USER)
        send_cmd(tn, FTP_PASSWORD)
        send_cmd(tn, f"put {filename_bgp}")
        send_cmd(tn, "q")

        tn.write(b"quit\n")
        tn.close()

        ftp_download(filename_admin, f"{LOCAL_BACKUP_PATH}/{filename_admin}")
        ftp_download(filename_bgp, f"{LOCAL_BACKUP_PATH}/{filename_bgp}")

        write_log("✔ FINALIZADO COM SUCESSO.")

    except Exception as e:
        write_log(f"❌ ERRO GERAL: {e}")

if __name__ == "__main__":
    run_backup()
EOF

echo "[7/8] Construindo imagem..."
docker compose build --no-cache

echo "[8/8] Subindo container..."
docker compose up -d

echo "===================================================="
echo "  INSTALAÇÃO FINALIZADA!"
echo "  ➤ Edite o arquivo: /opt/huawei-backup/.env"
echo "  ➤ Backups em: /opt/huawei-backup/backups"
echo "  ➤ Logs em:     /opt/huawei-backup/logs"
echo "===================================================="
