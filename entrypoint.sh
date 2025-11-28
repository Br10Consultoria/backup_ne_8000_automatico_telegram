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
