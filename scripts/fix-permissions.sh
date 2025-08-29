#!/bin/bash

# Script para corrigir permissões dos diretórios e arquivos
# Sistema de backup FortiGate via SSH - Correção de permissões

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
BACKUP_USER="backup"
BACKUP_GROUP="backup"
BACKUP_UID=1000
BACKUP_GID=1000

# Função para log com timestamp
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Função para mostrar ajuda
show_help() {
    echo "Uso: $0 [OPÇÕES]"
    echo ""
    echo "Opções:"
    echo "  -u, --user USER     Usuário para as permissões (padrão: $BACKUP_USER)"
    echo "  -g, --group GROUP   Grupo para as permissões (padrão: $BACKUP_GROUP)"
    echo "  --uid UID           UID do usuário (padrão: $BACKUP_UID)"
    echo "  --gid GID           GID do grupo (padrão: $BACKUP_GID)"
    echo "  -f, --force         Executar sem confirmação"
    echo "  -c, --container     Corrigir permissões dentro do container"
    echo "  -h, --help          Mostrar esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0                  # Corrigir permissões com configurações padrão"
    echo "  $0 -c               # Corrigir permissões dentro do container"
    echo "  $0 -u myuser -g mygroup  # Usar usuário e grupo específicos"
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
        log "${YELLOW}⚠️  Container não encontrado${NC}"
        return 1
    fi
    return 0
}

# Função para corrigir permissões no host
fix_host_permissions() {
    local user=$1
    local group=$2
    local uid=$3
    local gid=$4
    local force=$5
    
    log "${BLUE}🔧 Corrigindo permissões no host${NC}"
    
    # Verificar se os diretórios existem
    local dirs=("backups" "logs" "config")
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log "${YELLOW}📁 Criando diretório: $dir${NC}"
            mkdir -p "$dir"
        fi
    done
    
    # Mostrar permissões atuais
    log "${BLUE}📋 Permissões atuais:${NC}"
    ls -la backups logs config 2>/dev/null || true
    
    # Confirmar se não for forçado
    if [ "$force" != "true" ]; then
        echo -n "Deseja corrigir as permissões? (s/N): "
        read -r response
        if [[ ! "$response" =~ ^[Ss]$ ]]; then
            log "${YELLOW}⚠️  Operação cancelada pelo usuário${NC}"
            return 0
        fi
    fi
    
    # Verificar se o usuário existe
    if ! id "$user" >/dev/null 2>&1; then
        log "${YELLOW}👤 Usuário $user não existe. Tentando criar...${NC}"
        if command -v useradd >/dev/null 2>&1; then
            sudo useradd -u "$uid" -g "$gid" -m "$user" 2>/dev/null || true
        else
            log "${RED}❌ Não foi possível criar o usuário. Execute manualmente:${NC}"
            log "   sudo useradd -u $uid -g $gid -m $user"
        fi
    fi
    
    # Verificar se o grupo existe
    if ! getent group "$group" >/dev/null 2>&1; then
        log "${YELLOW}👥 Grupo $group não existe. Tentando criar...${NC}"
        if command -v groupadd >/dev/null 2>&1; then
            sudo groupadd -g "$gid" "$group" 2>/dev/null || true
        else
            log "${RED}❌ Não foi possível criar o grupo. Execute manualmente:${NC}"
            log "   sudo groupadd -g $gid $group"
        fi
    fi
    
    # Corrigir propriedade dos diretórios
    log "${YELLOW}🔧 Corrigindo propriedade dos diretórios...${NC}"
    
    if command -v sudo >/dev/null 2>&1; then
        sudo chown -R "$user:$group" backups logs config
        sudo chmod -R 755 backups logs config
        sudo chmod -R 644 backups/* logs/* config/* 2>/dev/null || true
    else
        log "${YELLOW}⚠️  Sudo não disponível. Tentando sem sudo...${NC}"
        chown -R "$user:$group" backups logs config 2>/dev/null || {
            log "${RED}❌ Erro ao alterar propriedade. Execute como root ou com sudo${NC}"
            return 1
        }
        chmod -R 755 backups logs config
        chmod -R 644 backups/* logs/* config/* 2>/dev/null || true
    fi
    
    # Corrigir permissões dos scripts
    if [ -d "scripts" ]; then
        log "${YELLOW}🔧 Corrigindo permissões dos scripts...${NC}"
        chmod +x scripts/*.sh 2>/dev/null || true
    fi
    
    log "${GREEN}✅ Permissões do host corrigidas${NC}"
}

# Função para corrigir permissões no container
fix_container_permissions() {
    local user=$1
    local group=$2
    local force=$3
    
    log "${BLUE}🐳 Corrigindo permissões no container${NC}"
    
    # Verificar se o container está rodando
    if ! check_container; then
        log "${RED}❌ Container não está rodando${NC}"
        return 1
    fi
    
    # Mostrar permissões atuais no container
    log "${BLUE}📋 Permissões atuais no container:${NC}"
    docker compose exec fortigate-backup ls -la /app/backups /app/logs /app/config 2>/dev/null || true
    
    # Confirmar se não for forçado
    if [ "$force" != "true" ]; then
        echo -n "Deseja corrigir as permissões no container? (s/N): "
        read -r response
        if [[ ! "$response" =~ ^[Ss]$ ]]; then
            log "${YELLOW}⚠️  Operação cancelada pelo usuário${NC}"
            return 0
        fi
    fi
    
    # Corrigir permissões no container
    log "${YELLOW}🔧 Executando correção no container...${NC}"
    
    docker compose exec -u root fortigate-backup chown -R "$user:$group" /app/backups /app/logs /app/config
    docker compose exec -u root fortigate-backup chmod -R 755 /app/backups /app/logs /app/config
    docker compose exec -u root fortigate-backup find /app/backups -type f -exec chmod 644 {} \;
    docker compose exec -u root fortigate-backup find /app/logs -type f -exec chmod 644 {} \;
    docker compose exec -u root fortigate-backup find /app/config -type f -exec chmod 644 {} \;
    
    log "${GREEN}✅ Permissões do container corrigidas${NC}"
}

# Função para mostrar status das permissões
show_permissions_status() {
    log "${BLUE}📊 Status atual das permissões:${NC}"
    
    echo "Host:"
    ls -la backups logs config 2>/dev/null || echo "  Diretórios não encontrados"
    
    if check_container >/dev/null 2>&1; then
        echo "Container:"
        docker compose exec fortigate-backup ls -la /app/backups /app/logs /app/config 2>/dev/null || echo "  Erro ao acessar container"
    else
        echo "Container: Não está rodando"
    fi
}

# Função principal
main() {
    local user=$BACKUP_USER
    local group=$BACKUP_GROUP
    local uid=$BACKUP_UID
    local gid=$BACKUP_GID
    local force=false
    local container_only=false
    
    # Parse dos argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--user)
                user="$2"
                shift 2
                ;;
            -g|--group)
                group="$2"
                shift 2
                ;;
            --uid)
                uid="$2"
                shift 2
                ;;
            --gid)
                gid="$2"
                shift 2
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -c|--container)
                container_only=true
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
    
    log "${BLUE}🔧 Iniciando correção de permissões${NC}"
    log "   Usuário: $user ($uid)"
    log "   Grupo: $group ($gid)"
    
    # Verificar Docker se necessário
    if [ "$container_only" = true ]; then
        check_docker
    fi
    
    # Executar correções
    if [ "$container_only" = true ]; then
        fix_container_permissions "$user" "$group" "$force"
    else
        fix_host_permissions "$user" "$group" "$uid" "$gid" "$force"
        
        # Também corrigir no container se estiver rodando
        if check_container >/dev/null 2>&1; then
            log "${BLUE}🐳 Container detectado, corrigindo permissões também no container${NC}"
            fix_container_permissions "$user" "$group" "$force"
        fi
    fi
    
    # Mostrar status final
    show_permissions_status
    
    log "${GREEN}🎉 Correção de permissões finalizada!${NC}"
}

# Verificar se está no diretório correto
if [ ! -f "docker-compose.yml" ] && [ ! -d "backups" ]; then
    log "${RED}❌ Execute este script no diretório raiz do projeto${NC}"
    exit 1
fi

# Executar função principal
main "$@"