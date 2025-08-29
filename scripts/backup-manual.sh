#!/bin/bash

# Script para backup manual dos FortiGates via SSH
# Sistema de backup FortiGate usando SSH com usuário e senha

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log com timestamp
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Função para verificar se o Docker está rodando
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        log "${RED}❌ Docker não está rodando ou não está acessível${NC}"
        exit 1
    fi
}

# Função para verificar se o container existe
check_container() {
    if ! docker compose ps | grep -q "fortigate-backup"; then
        log "${YELLOW}⚠️  Container não encontrado. Iniciando serviços...${NC}"
        docker compose up -d
        sleep 5
    fi
}

# Função principal
main() {
    log "${BLUE}🔒 Iniciando backup manual dos FortiGates via SSH${NC}"
    
    # Verificar Docker
    check_docker
    
    # Verificar container
    check_container
    
    # Executar backup SSH
    log "${YELLOW}📋 Executando backup via SSH...${NC}"
    
    if docker compose exec fortigate-backup python src/fortigate_backup.py; then
        log "${GREEN}✅ Backup concluído com sucesso!${NC}"
    else
        log "${RED}❌ Erro durante o backup${NC}"
        exit 1
    fi
    
    # Mostrar estatísticas
    log "${BLUE}📊 Estatísticas dos backups:${NC}"
    docker compose exec fortigate-backup find /app/backups -name "*.conf" -type f | wc -l | xargs echo "Arquivos de configuração:"
    docker compose exec fortigate-backup du -sh /app/backups | cut -f1 | xargs echo "Espaço utilizado:"
    
    log "${GREEN}🎉 Backup manual finalizado!${NC}"
}

# Verificar se está no diretório correto
if [ ! -f "docker-compose.yml" ]; then
    log "${RED}❌ Execute este script no diretório raiz do projeto${NC}"
    exit 1
fi

# Executar função principal
main "$@"