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

# cron
RUN echo "0 3 * * 1 root python3 /app/backup_huawei_ne.py >> /var/log/cron.log 2>&1" > /etc/cron.d/backup-cron
RUN chmod 0644 /etc/cron.d/backup-cron
RUN crontab /etc/cron.d/backup-cron

# preparar arquivo de log
RUN touch /var/log/cron.log
RUN chmod 666 /var/log/cron.log

# adicionar entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
