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
