#!/bin/bash
set -e

# Função para log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🚀 Iniciando FortiGate Backup System"

# Verificar se arquivo .env existe, senão usar o exemplo
if [ ! -f "/app/.env" ]; then
    log "⚠️  Arquivo .env não encontrado, usando .env.example"
    cp /app/.env.example /app/.env
fi

# Verificar se arquivo de dispositivos existe
if [ ! -f "/app/config/devices.json" ]; then
    log "❌ Arquivo config/devices.json não encontrado!"
    log "   Copie o arquivo de exemplo e configure seus dispositivos"
    exit 1
fi

# Criar diretórios se não existirem
mkdir -p /app/backups /app/logs

# Ler variáveis do .env de forma segura
if [ -f "/app/.env" ]; then
    # Extrair CRON_SCHEDULE do arquivo .env
    CRON_SCHEDULE=$(grep '^CRON_SCHEDULE=' /app/.env | cut -d'=' -f2- | tr -d '"')
    if [ ! -z "$CRON_SCHEDULE" ]; then
        log "⏰ Configurando agendamento automático: $CRON_SCHEDULE"
        log "✅ Scheduler configurado com sucesso"
    else
        log "ℹ️  CRON_SCHEDULE não definido - modo manual"
    fi
fi

# Executar comando passado como argumento ou manter container rodando
if [ "$#" -eq 0 ]; then
    log "🔄 Container em modo daemon"
    if [ ! -z "$CRON_SCHEDULE" ]; then
        log "⏰ Agendamento ativo: $CRON_SCHEDULE"
        log "📋 Para ver logs: docker compose logs -f fortigate-backup"
        log "📋 Para executar manual: docker compose exec fortigate-backup python src/fortigate_backup.py"
        # Iniciar scheduler em background
        python src/scheduler.py
    else
        log "💡 Use: docker compose exec fortigate-backup python src/fortigate_backup.py"
        # Manter container rodando
        tail -f /dev/null
    fi
else
    log "▶️  Executando comando: $@"
    exec "$@"
fi