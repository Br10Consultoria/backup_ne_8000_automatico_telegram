# Backup automático Huawei NE em Docker

Este projeto realiza **backup automático** de equipamentos **Huawei NE** via **Telnet**, envia os arquivos para um servidor **FTP**, baixa os arquivos para o servidor local e registra logs de execução.  
Tudo isso rodando dentro de um **container Docker**, com agendamento via **cron**.

O instalador `instalar_huawei_backup.sh` é responsável por:

- Instalar Docker e dependências;
- Criar a estrutura `/opt/huawei-backup`;
- Gerar automaticamente:
  - `Dockerfile`
  - `docker-compose.yml`
  - `entrypoint.sh`
  - `requirements.txt`
  - `.env` (modelo)
  - `backup_huawei_ne.py`
- Construir a imagem Docker;
- Subir o container `huawei-backup` já pronto para uso.

---

## 1. Requisitos

1. Servidor Linux baseado em Debian/Ubuntu (com `apt`);
2. Acesso **root** (ou usuário com `sudo` sem senha);
3. Acesso à internet (para baixar Docker e dependências);
4. Acesso Telnet à Huawei NE a partir do servidor;
5. Servidor FTP acessível a partir da Huawei e do servidor;
6. Token e Chat ID do bot do Telegram (opcional, para alertas).

---

## 2. Estrutura gerada pelo instalador

Após rodar o instalador, será criada a estrutura:

```bash
/opt/huawei-backup/
├── Dockerfile
├── docker-compose.yml
├── entrypoint.sh
├── requirements.txt
├── .env
├── backup_huawei_ne.py
├── backups/     # (mapeado para dentro do container: /backups)
└── logs/        # (mapeado para dentro do container: /logs)



1. Verificar se o cron foi aplicado corretamente
1.1. Entrar no container
docker exec -it huawei-backup bash

1.2. Verificar o conteúdo do crontab
crontab -l


Você deve ver:

0 3 * * 1 root python3 /app/backup_huawei_ne.py >> /var/log/cron.log 2>&1


Se aparecer a linha acima → cron configurado corretamente.

✅ 2. Verificar se o serviço cron está rodando

Ainda dentro do container:

ps aux | grep cron


Você deve ver algo como:

root     7  ... /usr/sbin/cron -f


Se o processo estiver ativo → cron está em execução.

✅ 3. Verificar se o cron está escrevendo no log

Dentro do container:

tail -f /var/log/cron.log

Esse arquivo mostrará a saída do cron quando o backup automático rodar no horário agendado.

✅ 4. Executar o script Python manualmente para testar

Você pode rodar o backup na hora, sem esperar o cron.

Do host (fora do container):

docker exec -it huawei-backup python3 /app/backup_huawei_ne.py


Ou de dentro do container:

python3 /app/backup_huawei_ne.py

Esse comando deve:

conectar via Telnet na Huawei

salvar o arquivo admin

salvar o arquivo BGP

enviar via FTP

baixar de volta para /backups

registrar tudo nos logs

✅ 5. Verificar se os arquivos de backup foram criados

No host:

ls -l /opt/huawei-backup/backups


Você deve ver arquivos como:

admin_280125.cfg
bgp_280125.cfg
6. Verificar logs do script Python
ls -l /opt/huawei-backup/logs
cat /opt/huawei-backup/logs/backup_DD-MM-YYYY.log


O log exibe:

comandos executados

respostas da NE

erros

confirmações de backup enviado

confirmações de download

✅ 7. Ver logs de inicialização do container

No host:

docker logs -f huawei-backup

Você deve ver:

=== Serviços Iniciados ===
Cron e rsyslog estão rodando.
Monitorando /var/log/cron.log...


Se aparecer isso → container iniciado corretamente.

✅ 8. Comandos úteis
Reiniciar o container:
docker restart huawei-backup

Parar:
docker compose down

Subir novamente:
docker compose up -d

Reconstruir a imagem após mudanças:
docker compose build --no-cache
docker compose up -d
