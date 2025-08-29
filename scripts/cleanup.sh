#!/bin/bash

# Script para limpeza de backups antigos dos FortiGates
# Sistema de backup FortiGate via SSH - Limpeza de arquivos antigos

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações padrão
DEFAULT_RETENTION_DAYS=30
BACKUP_DIR="./backups"
LOG_DIR="./logs"

# Função para log com timestamp
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Função para mostrar ajuda
show_help() {
    echo "Uso: $0 [OPÇÕES]"
    echo ""
    echo "Opções:"
    echo "  -d, --days DIAS     Número de dias para manter os backups (padrão: $DEFAULT_RETENTION_DAYS)"
    echo "  -f, --force         Executar sem confirmação"
    echo "  -l, --logs-only     Limpar apenas logs, manter backups"
    echo "  -b, --backups-only  Limpar apenas backups, manter logs"
    echo "  -h, --help          Mostrar esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0 -d 7             # Manter apenas últimos 7 dias"
    echo "  $0 -f               # Executar sem confirmação"
    echo "  $0 -l -d 3          # Limpar logs com mais de 3 dias"
}

# Função para verificar se o Docker está rodando
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        log "${RED}❌ Docker não está rodando ou não está acessível${NC}"
        exit 1
    fi
}

# Função para limpar backups antigos
cleanup_backups() {
    local retention_days=$1
    local force=$2
    
    log "${BLUE}🧹 Iniciando limpeza de backups antigos (>${retention_days} dias)${NC}"
    
    # Contar arquivos que serão removidos
    local count
    if docker compose ps | grep -q "fortigate-backup"; then
        count=$(docker compose exec fortigate-backup find /app/backups -name "*.conf" -type f -mtime +${retention_days} | wc -l)
    else
        count=$(find "$BACKUP_DIR" -name "*.conf" -type f -mtime +${retention_days} 2>/dev/null | wc -l || echo "0")
    fi
    
    if [ "$count" -eq 0 ]; then
        log "${GREEN}✅ Nenhum backup antigo encontrado${NC}"
        return 0
    fi
    
    log "${YELLOW}📋 Encontrados $count arquivos de backup para remoção${NC}"
    
    # Confirmar se não for forçado
    if [ "$force" != "true" ]; then
        echo -n "Deseja continuar? (s/N): "
        read -r response
        if [[ ! "$response" =~ ^[Ss]$ ]]; then
            log "${YELLOW}⚠️  Operação cancelada pelo usuário${NC}"
            return 0
        fi
    fi
    
    # Executar limpeza
    if docker compose ps | grep -q "fortigate-backup"; then
        docker compose exec fortigate-backup find /app/backups -name "*.conf" -type f -mtime +${retention_days} -delete
        docker compose exec fortigate-backup find /app/backups -name "*_info.json" -type f -mtime +${retention_days} -delete
    else
        find "$BACKUP_DIR" -name "*.conf" -type f -mtime +${retention_days} -delete 2>/dev/null || true
        find "$BACKUP_DIR" -name "*_info.json" -type f -mtime +${retention_days} -delete 2>/dev/null || true
    fi
    
    log "${GREEN}✅ Limpeza de backups concluída${NC}"
}

# Função para limpar logs antigos
cleanup_logs() {
    local retention_days=$1
    local force=$2
    
    log "${BLUE}🧹 Iniciando limpeza de logs antigos (>${retention_days} dias)${NC}"
    
    # Contar arquivos que serão removidos
    local count
    if docker compose ps | grep -q "fortigate-backup"; then
        count=$(docker compose exec fortigate-backup find /app/logs -name "*.log" -type f -mtime +${retention_days} | wc -l)
    else
        count=$(find "$LOG_DIR" -name "*.log" -type f -mtime +${retention_days} 2>/dev/null | wc -l || echo "0")
    fi
    
    if [ "$count" -eq 0 ]; then
        log "${GREEN}✅ Nenhum log antigo encontrado${NC}"
        return 0
    fi
    
    log "${YELLOW}📋 Encontrados $count arquivos de log para remoção${NC}"
    
    # Confirmar se não for forçado
    if [ "$force" != "true" ]; then
        echo -n "Deseja continuar? (s/N): "
        read -r response
        if [[ ! "$response" =~ ^[Ss]$ ]]; then
            log "${YELLOW}⚠️  Operação cancelada pelo usuário${NC}"
            return 0
        fi
    fi
    
    # Executar limpeza
    if docker compose ps | grep -q "fortigate-backup"; then
        docker compose exec fortigate-backup find /app/logs -name "*.log" -type f -mtime +${retention_days} -delete
    else
        find "$LOG_DIR" -name "*.log" -type f -mtime +${retention_days} -delete 2>/dev/null || true
    fi
    
    log "${GREEN}✅ Limpeza de logs concluída${NC}"
}

# Função para mostrar estatísticas
show_stats() {
    log "${BLUE}📊 Estatísticas atuais:${NC}"
    
    if docker compose ps | grep -q "fortigate-backup"; then
        echo "Backups:"
        docker compose exec fortigate-backup find /app/backups -name "*.conf" -type f | wc -l | xargs echo "  Arquivos de configuração:"
        docker compose exec fortigate-backup du -sh /app/backups 2>/dev/null | cut -f1 | xargs echo "  Espaço utilizado:"
        
        echo "Logs:"
        docker compose exec fortigate-backup find /app/logs -name "*.log" -type f | wc -l | xargs echo "  Arquivos de log:"
        docker compose exec fortigate-backup du -sh /app/logs 2>/dev/null | cut -f1 | xargs echo "  Espaço utilizado:"
    else
        echo "Backups:"
        find "$BACKUP_DIR" -name "*.conf" -type f 2>/dev/null | wc -l | xargs echo "  Arquivos de configuração:"
        du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 | xargs echo "  Espaço utilizado:" || echo "  Espaço utilizado: N/A"
        
        echo "Logs:"
        find "$LOG_DIR" -name "*.log" -type f 2>/dev/null | wc -l | xargs echo "  Arquivos de log:"
        du -sh "$LOG_DIR" 2>/dev/null | cut -f1 | xargs echo "  Espaço utilizado:" || echo "  Espaço utilizado: N/A"
    fi
}

# Função principal
main() {
    local retention_days=$DEFAULT_RETENTION_DAYS
    local force=false
    local logs_only=false
    local backups_only=false
    
    # Parse dos argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--days)
                retention_days="$2"
                shift 2
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -l|--logs-only)
                logs_only=true
                shift
                ;;
            -b|--backups-only)
                backups_only=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Opção desconhecida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validar retention_days
    if ! [[ "$retention_days" =~ ^[0-9]+$ ]] || [ "$retention_days" -lt 1 ]; then
        log "${RED}❌ Número de dias deve ser um inteiro positivo${NC}"
        exit 1
    fi
    
    log "${BLUE}🧹 Iniciando limpeza com retenção de $retention_days dias${NC}"
    
    # Verificar Docker se necessário
    if docker compose ps >/dev/null 2>&1; then
        check_docker
    fi
    
    # Executar limpeza baseada nas opções
    if [ "$logs_only" = true ]; then
        cleanup_logs "$retention_days" "$force"
    elif [ "$backups_only" = true ]; then
        cleanup_backups "$retention_days" "$force"
    else
        cleanup_backups "$retention_days" "$force"
        cleanup_logs "$retention_days" "$force"
    fi
    
    # Mostrar estatísticas finais
    show_stats
    
    log "${GREEN}🎉 Limpeza finalizada!${NC}"
}

# Verificar se está no diretório correto
if [ ! -f "docker-compose.yml" ] && [ ! -d "$BACKUP_DIR" ]; then
    log "${RED}❌ Execute este script no diretório raiz do projeto${NC}"
    exit 1
fi

# Executar função principal
main "$@"