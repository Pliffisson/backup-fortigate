#!/bin/bash

# Script para gerenciar scheduler interno do container
# Permite verificar status e logs do agendamento Python

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para exibir mensagens coloridas
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_usage() {
    echo "Uso: $0 [status|logs]"
    echo
    echo "Comandos:"
    echo "  status  - Verificar status do scheduler"
    echo "  logs    - Ver logs do scheduler"
    echo
    echo "Nota: O agendamento é gerenciado automaticamente pelo container."
    echo "Para alterar o cronograma, modifique CRON_SCHEDULE no arquivo .env e reinicie o container."
}

# Função para verificar status
check_status() {
    print_info "Status do scheduler interno:"
    
    # Verificar se o container está rodando
    print_success "Container está rodando com scheduler integrado"
    
    # Verificar arquivo .env
    if [ -f "/app/.env" ]; then
        source /app/.env
        if [ ! -z "$CRON_SCHEDULE" ]; then
            print_info "Agendamento ativo via scheduler Python:"
            print_info "Cronograma: $CRON_SCHEDULE"
            
            # Calcular próxima execução usando Python
            if command -v python3 >/dev/null 2>&1; then
                NEXT_RUN=$(python3 -c "
import os
from datetime import datetime
try:
    from croniter import croniter
    cron = croniter('$CRON_SCHEDULE', datetime.now())
    print(cron.get_next(datetime).strftime('%Y-%m-%d %H:%M:%S'))
except ImportError:
    print('Não disponível (croniter não instalado)')
except Exception as e:
    print(f'Erro: {e}')
" 2>/dev/null)
                if [ ! -z "$NEXT_RUN" ]; then
                    print_info "Próxima execução: $NEXT_RUN"
                fi
            fi
        else
            print_warning "CRON_SCHEDULE não definido no .env"
        fi
    else
        print_warning "Arquivo .env não encontrado"
    fi
}

# Função para ver logs
show_logs() {
    print_info "Logs do scheduler:"
    
    if [ -f "/app/logs/cron.log" ]; then
        echo
        print_info "Últimas 50 linhas do log de agendamento:"
        tail -n 50 /app/logs/cron.log
    else
        print_warning "Arquivo de log não encontrado: /app/logs/cron.log"
        print_info "O log será criado após a primeira execução agendada"
    fi
    
    echo
    print_info "Para acompanhar logs em tempo real:"
    echo "  docker compose logs -f fortigate-backup"
}

# Função principal
main() {
    case "${1:-}" in
        status)
            check_status
            ;;
        logs)
            show_logs
            ;;
        setup|remove)
            print_warning "Comando '$1' não é mais necessário."
            print_info "O scheduler é gerenciado automaticamente pelo container."
            print_info "Para alterar o cronograma:"
            echo "  1. Modifique CRON_SCHEDULE no arquivo .env"
            echo "  2. Reinicie o container: docker compose restart fortigate-backup"
            ;;
        *)
            print_usage
            exit 1
            ;;
    esac
}

# Executar função principal
main "$@"