# 🛡️ FortiGate Backup System

> Sistema automatizado para backup de equipamentos FortiGate via SSH com agendamento inteligente e notificações Telegram.

[![Docker](https://img.shields.io/badge/Docker-Ready-blue?logo=docker)](https://www.docker.com/)
[![Python](https://img.shields.io/badge/Python-3.11+-green?logo=python)](https://www.python.org/)
[![FortiOS](https://img.shields.io/badge/FortiOS-Compatible-red?logo=fortinet)](https://www.fortinet.com/)

## 🚀 Instalação Rápida

```bash
# 1. Clone o repositório
git clone <repository-url>
cd backup-fortigate

# 2. Configure as variáveis de ambiente
cp .env.example .env
nano .env  # Configure suas credenciais

# 3. Configure os dispositivos
nano config/devices.json  # Adicione seus FortiGates

# 4. Inicie o sistema
docker compose up -d --build

# ✅ Pronto! O sistema está rodando com agendamento automático
```

## 📋 Índice

- [🚀 Instalação Rápida](#-instalação-rápida)
- [✨ Características](#-características)
- [📦 Pré-requisitos](#-pré-requisitos)
- [⚙️ Configuração](#️-configuração)
- [🎯 Uso](#-uso)
- [📁 Estrutura do Projeto](#-estrutura-do-projeto)
- [🔧 Comandos Úteis](#-comandos-úteis)
- [⏰ Agendamento Automático](#-agendamento-automático)
- [🔍 Logs e Monitoramento](#-logs-e-monitoramento)
- [🛠️ Solução de Problemas](#️-solução-de-problemas)
- [❓ FAQ](#-faq)
- [🆕 Changelog](#-changelog)

## ✨ Características

### 🔐 Conectividade e Segurança
- ✅ **Conexão SSH segura** com autenticação por usuário/senha
- ✅ **Multi-dispositivo** com suporte a múltiplos FortiGates
- ✅ **Timeout configurável** para conexões SSH
- ✅ **VDOM específico** para ambientes virtualizados

### 🤖 Automação Inteligente
- ✅ **Scheduler Python integrado** (sem dependência de cron do sistema)
- ✅ **Agendamento flexível** via expressões cron
- ✅ **Inicialização automática** do container
- ✅ **Recuperação de falhas** com logs detalhados

### 📱 Notificações e Monitoramento
- ✅ **Notificações Telegram** com resumo consolidado
- ✅ **Estatísticas detalhadas** (sucessos, falhas, duração)
- ✅ **Formato profissional** com emojis e contadores
- ✅ **Logs estruturados** com rotação automática

### 💾 Gestão de Backups
- ✅ **Backup completo** via `show full-configuration`
- ✅ **Coleta de informações do sistema** (opcional)
- ✅ **Limpeza automática** de backups antigos
- ✅ **Volumes persistentes** para dados e logs
- ✅ **Nomenclatura padronizada** dos arquivos

## 📦 Pré-requisitos

### Sistema Host
- **Docker** 20.10+ e **Docker Compose** 2.0+
- **Sistema operacional**: Linux, macOS ou Windows com WSL2
- **Recursos mínimos**: 512MB RAM, 1GB espaço em disco

### Equipamentos FortiGate
- **Acesso SSH** habilitado (porta 22 ou customizada)
- **Usuário administrativo** com privilégios de leitura
- **Conectividade de rede** entre o host Docker e os FortiGates
- **FortiOS** 6.0+ (testado até 7.4)

### Opcional
- **Bot Telegram** para notificações (recomendado para produção)

## ⚙️ Configuração

### 1. Variáveis de Ambiente (`.env`)

```bash
# === AGENDAMENTO ===
CRON_SCHEDULE="0 2 * * *"          # Diário às 02:00

# === TELEGRAM (OPCIONAL) ===
TELEGRAM_BOT_TOKEN=seu_token_aqui
TELEGRAM_CHAT_ID=seu_chat_id_aqui

# === CONFIGURAÇÕES DE BACKUP ===
BACKUP_RETENTION_DAYS=30           # Manter backups por 30 dias
COLLECT_SYSTEM_INFO=true           # Coletar informações do sistema
BACKUP_FORMAT=text                 # Formato do backup

# === CONFIGURAÇÕES SSH ===
SSH_TIMEOUT=30                     # Timeout SSH em segundos

# === CONFIGURAÇÕES DE LOG ===
LOG_LEVEL=INFO                     # DEBUG, INFO, WARNING, ERROR
LOG_TO_FILE=true                   # Salvar logs em arquivo

# === DIRETÓRIOS (NÃO ALTERAR) ===
BACKUP_DIR=/app/backups
LOG_DIR=/app/logs
CONFIG_DIR=/app/config
```

### 2. Dispositivos (`config/devices.json`)

```json
{
  "devices": [
    {
      "name": "fortigate-matriz",
      "host": "192.168.1.100",
      "username": "admin",
      "password": "sua_senha_segura",
      "port": 22,
      "vdom": "root",
      "timeout": 30
    },
    {
      "name": "fortigate-filial",
      "host": "10.0.0.1",
      "username": "backup-user",
      "password": "outra_senha_segura",
      "port": 2222,
      "vdom": "management",
      "timeout": 45
    }
  ]
}
```

#### Parâmetros dos Dispositivos

| Parâmetro | Descrição | Obrigatório | Padrão | Exemplo |
|-----------|-----------|-------------|--------|---------|
| `name` | Identificador único do dispositivo | ✅ | - | `"fortigate-01"` |
| `host` | IP ou hostname do FortiGate | ✅ | - | `"192.168.1.100"` |
| `username` | Usuário SSH com privilégios admin | ✅ | - | `"admin"` |
| `password` | Senha do usuário SSH | ✅ | - | `"senha123"` |
| `port` | Porta SSH | ❌ | `22` | `2222` |
| `vdom` | VDOM para backup | ❌ | `"root"` | `"management"` |
| `timeout` | Timeout SSH em segundos | ❌ | `30` | `45` |

### 3. Configuração do Bot Telegram (Opcional)

1. **Criar bot**: Fale com [@BotFather](https://t.me/botfather) no Telegram
2. **Obter token**: Copie o token fornecido
3. **Obter Chat ID**: 
   - Adicione o bot a um grupo ou chat
   - Envie uma mensagem
   - Acesse: `https://api.telegram.org/bot<TOKEN>/getUpdates`
   - Copie o `chat.id` da resposta

## 🎯 Uso

### Execução Manual

```bash
# Backup de todos os dispositivos
docker compose exec fortigate-backup python src/fortigate_backup.py

# Usando script auxiliar
./scripts/backup-manual.sh

# Testar notificação Telegram
docker compose exec fortigate-backup python -c "from src.fortigate_backup import FortiGateSSHBackup; FortiGateSSHBackup().test_telegram()"
```

### Verificar Status do Sistema

```bash
# Status do agendador
docker compose exec fortigate-backup ./scripts/manage-internal-cron.sh status

# Logs do agendador
docker compose exec fortigate-backup ./scripts/manage-internal-cron.sh logs

# Status dos containers
docker compose ps
```

## 📁 Estrutura do Projeto

```
backup-fortigate/
├── 📁 config/
│   └── devices.json              # Configuração dos dispositivos
├── 📁 src/
│   ├── fortigate_backup.py       # Script principal de backup
│   └── scheduler.py              # Agendador Python integrado
├── 📁 scripts/
│   ├── backup-manual.sh          # Execução manual de backup
│   ├── cleanup.sh                # Limpeza de backups antigos
│   ├── fix-permissions.sh        # Correção de permissões
│   └── manage-internal-cron.sh   # Gerenciamento do agendador
├── 📁 backups/                   # Volume: arquivos de backup
├── 📁 logs/                      # Volume: logs da aplicação
├── 📄 docker-compose.yml         # Configuração Docker Compose
├── 📄 Dockerfile                 # Definição da imagem Docker
├── 📄 requirements.txt           # Dependências Python
├── 📄 .env.example               # Exemplo de variáveis de ambiente
└── 📄 README.md                  # Esta documentação
```

### Volumes Docker

| Volume | Descrição | Localização Host | Localização Container |
|--------|-----------|------------------|----------------------|
| `fortigate-backups` | Arquivos de backup (.conf) | Volume Docker | `/app/backups/` |
| `fortigate-logs` | Logs da aplicação | Volume Docker | `/app/logs/` |
| `fortigate-config` | Configurações do sistema | Volume Docker | `/app/config/` |

### Formato dos Arquivos

- **Backup**: `{nome_dispositivo}_config_{YYYYMMDD}_{HHMMSS}.conf`
- **Logs**: `fortigate_backup_{YYYYMMDD}.log`
- **Scheduler**: `cron.log`

## 🔧 Comandos Úteis

### Gerenciamento do Container

```bash
# Iniciar sistema
docker compose up -d --build

# Parar sistema
docker compose down

# Reiniciar sistema
docker compose restart fortigate-backup

# Reconstruir completamente
docker compose down && docker compose up -d --build

# Status detalhado
docker compose ps
docker compose logs fortigate-backup
```

### Backup e Monitoramento

```bash
# Executar backup manual
docker compose exec fortigate-backup python src/fortigate_backup.py

# Ver logs em tempo real
docker compose logs -f fortigate-backup

# Ver logs específicos do dia
docker compose exec fortigate-backup cat /app/logs/fortigate_backup_$(date +%Y%m%d).log

# Listar backups
docker compose exec fortigate-backup ls -la /app/backups/

# Contar backups por dispositivo
docker compose exec fortigate-backup find /app/backups -name "*_config_*.conf" | cut -d'/' -f4 | cut -d'_' -f1 | sort | uniq -c
```

### Acesso aos Arquivos

```bash
# Copiar backup específico para host
docker compose cp fortigate-backup:/app/backups/arquivo.conf ./

# Copiar todos os backups
docker compose cp fortigate-backup:/app/backups/ ./backups-local/

# Acessar shell do container
docker compose exec fortigate-backup bash

# Verificar espaço em disco
docker compose exec fortigate-backup df -h /app/backups/
```

## ⏰ Agendamento Automático

### Como Funciona

O sistema utiliza um **scheduler Python integrado** que substitui completamente o cron tradicional:

- ✅ **Sem dependências externas**: Não requer cron do sistema host
- ✅ **Inicialização automática**: Ativa junto com o container
- ✅ **Configuração via .env**: Controle total via `CRON_SCHEDULE`
- ✅ **Logs detalhados**: Rastreamento completo das execuções
- ✅ **Recuperação de falhas**: Reinicialização automática em caso de erro

### Configuração do Cronograma

**Formato**: `minuto hora dia mês dia_da_semana`

| Campo | Valores | Descrição |
|-------|---------|----------|
| Minuto | 0-59 | Minuto da hora |
| Hora | 0-23 | Hora do dia (24h) |
| Dia | 1-31 | Dia do mês |
| Mês | 1-12 | Mês do ano |
| Dia da semana | 0-7 | 0 e 7 = domingo |

### Exemplos Práticos

```bash
# Diário às 02:00
CRON_SCHEDULE="0 2 * * *"

# A cada 6 horas
CRON_SCHEDULE="0 */6 * * *"

# Segunda a sexta às 08:00
CRON_SCHEDULE="0 8 * * 1-5"

# Semanal (domingo às 03:00)
CRON_SCHEDULE="0 3 * * 0"

# Duas vezes por dia (09:00 e 21:00)
CRON_SCHEDULE="0 9,21 * * *"

# Todo dia 1º do mês às 00:00
CRON_SCHEDULE="0 0 1 * *"
```

### Gerenciamento

```bash
# Verificar status do agendador
docker compose exec fortigate-backup ./scripts/manage-internal-cron.sh status

# Ver logs do agendador
docker compose exec fortigate-backup ./scripts/manage-internal-cron.sh logs

# Alterar cronograma (edite .env e reinicie)
nano .env
docker compose restart fortigate-backup
```

## 🔍 Logs e Monitoramento

### Tipos de Logs

1. **Container Logs**: Saída padrão do Docker
2. **Application Logs**: Logs estruturados da aplicação
3. **Scheduler Logs**: Logs específicos do agendador

### Comandos de Monitoramento

```bash
# Logs do container (tempo real)
docker compose logs -f fortigate-backup --tail=50

# Logs da aplicação (arquivo)
docker compose exec fortigate-backup tail -f /app/logs/fortigate_backup_$(date +%Y%m%d).log

# Logs do scheduler
docker compose exec fortigate-backup tail -f /app/logs/cron.log

# Listar todos os arquivos de log
docker compose exec fortigate-backup ls -la /app/logs/

# Verificar últimos backups
docker compose exec fortigate-backup find /app/backups -name "*.conf" -mtime -1 -exec ls -la {} \;
```

### Notificações Telegram

#### ✅ Sucesso Completo
```
✅ Backup FortiGate - Sucesso

📊 Resumo:
• Sucessos: 2
• Falhas: 0
• Duração: 0:00:13.808195
• Data: 29/08/2025 02:00:12

✅ Dispositivos com Sucesso:
• fortigate-matriz (15 arquivos)
• fortigate-filial (8 arquivos)
```

#### ⚠️ Sucesso Parcial
```
⚠️ Backup FortiGate - Parcial

📊 Resumo:
• Sucessos: 1
• Falhas: 1
• Duração: 0:00:25.123456
• Data: 29/08/2025 02:00:12

✅ Dispositivos com Sucesso:
• fortigate-matriz (15 arquivos)

❌ Dispositivos com Falha:
• fortigate-filial (Timeout de conexão)
```

## 🛠️ Solução de Problemas

### Diagnóstico Rápido

```bash
# 1. Verificar status geral
docker compose ps
docker compose exec fortigate-backup ./scripts/manage-internal-cron.sh status

# 2. Verificar logs recentes
docker compose logs --tail=20 fortigate-backup

# 3. Testar conectividade
docker compose exec fortigate-backup ping 192.168.1.100

# 4. Testar configuração
docker compose exec fortigate-backup python -c "import json; print(json.load(open('config/devices.json')))"
```

### Problemas Comuns

#### 🔴 Container não inicia

**Sintomas**: Container em estado `Exited` ou `Restarting`

**Soluções**:
```bash
# Verificar logs de inicialização
docker compose logs fortigate-backup

# Verificar arquivo .env
cat .env | grep -v "^#" | grep -v "^$"

# Reconstruir imagem
docker compose down && docker compose up -d --build

# Verificar recursos do sistema
docker system df
docker system prune -f
```

#### 🔴 Erro de conexão SSH

**Sintomas**: `Connection refused`, `Timeout`, `Authentication failed`

**Soluções**:
```bash
# Testar conectividade de rede
docker compose exec fortigate-backup ping -c 3 192.168.1.100

# Testar porta SSH
docker compose exec fortigate-backup nc -zv 192.168.1.100 22

# Testar SSH manualmente
docker compose exec fortigate-backup ssh -o ConnectTimeout=10 admin@192.168.1.100

# Verificar configuração do dispositivo
cat config/devices.json | jq '.devices[0]'
```

#### 🔴 Scheduler não funciona

**Sintomas**: Backups não executam automaticamente

**Soluções**:
```bash
# Verificar status do scheduler
docker compose exec fortigate-backup ./scripts/manage-internal-cron.sh status

# Verificar variável CRON_SCHEDULE
docker compose exec fortigate-backup env | grep CRON_SCHEDULE

# Verificar logs do scheduler
docker compose exec fortigate-backup ./scripts/manage-internal-cron.sh logs

# Reiniciar container
docker compose restart fortigate-backup
```

#### 🔴 Problemas de volume/permissão

**Sintomas**: `Permission denied`, arquivos não salvos

**Soluções**:
```bash
# Verificar volumes
docker volume ls | grep fortigate
docker volume inspect fortigate-backups

# Corrigir permissões
docker compose exec fortigate-backup ./scripts/fix-permissions.sh

# Verificar espaço em disco
docker compose exec fortigate-backup df -h /app/

# Recriar volumes (⚠️ APAGA DADOS)
docker compose down
docker volume rm fortigate-backups fortigate-logs fortigate-config
docker compose up -d --build
```

### Debug Avançado

```bash
# Habilitar logs de debug
echo "LOG_LEVEL=DEBUG" >> .env
docker compose restart fortigate-backup

# Executar backup com debug
docker compose exec fortigate-backup python -c "
import logging
logging.basicConfig(level=logging.DEBUG)
from src.fortigate_backup import FortiGateSSHBackup
FortiGateSSHBackup().run_backup()
"

# Verificar dependências Python
docker compose exec fortigate-backup pip list

# Verificar sistema interno
docker compose exec fortigate-backup python -c "import sys; print(sys.version); import os; print(os.getcwd())"
```

## ❓ FAQ

### 🤔 Posso usar sem Docker?
**R**: Não recomendado. O sistema foi projetado para Docker, garantindo isolamento e facilidade de deploy.

### 🤔 Funciona com FortiGate em cluster?
**R**: Sim, configure cada nó do cluster como um dispositivo separado no `devices.json`.

### 🤔 Posso fazer backup de VDOMs específicos?
**R**: Sim, configure o parâmetro `vdom` no `devices.json` para cada dispositivo.

### 🤔 Como alterar o fuso horário?
**R**: O container usa UTC por padrão. Para alterar, adicione `TZ=America/Sao_Paulo` no arquivo `.env`.

### 🤔 Posso executar múltiplas instâncias?
**R**: Sim, mas use portas e nomes de container diferentes no `docker-compose.yml`.

### 🤔 Como fazer backup de configurações específicas?
**R**: Atualmente o sistema faz backup completo. Para comandos específicos, modifique o `fortigate_backup.py`.

### 🤔 O sistema funciona com FortiManager?
**R**: Não, este sistema conecta diretamente aos FortiGates via SSH.

### 🤔 Como configurar proxy/firewall?
**R**: Configure as regras de firewall para permitir SSH do container para os FortiGates.

## 🆕 Changelog

### v3.0.0 - Scheduler Python Integrado (Atual)
- 🚀 **BREAKING**: Substituição completa do cron por scheduler Python
- ✅ **Novo**: Agendador integrado sem dependências externas
- ✅ **Novo**: Inicialização automática com o container
- ✅ **Novo**: Script `manage-internal-cron.sh` atualizado
- ✅ **Removido**: Scripts obsoletos `setup-cron.sh` e `remove-cron.sh`
- ✅ **Melhorado**: Documentação completamente reescrita
- ✅ **Melhorado**: Estrutura de logs mais clara
- ✅ **Melhorado**: Troubleshooting expandido com FAQ

### v2.1.0 - Notificações Aprimoradas
- ✅ **Novo**: Formato consolidado de notificações Telegram
- ✅ **Novo**: Estatísticas detalhadas (sucessos, falhas, duração)
- ✅ **Novo**: Contagem automática de arquivos por dispositivo
- ✅ **Melhorado**: Emojis informativos para status
- ✅ **Melhorado**: Formatação HTML estruturada

### v2.0.0 - Migração para SSH
- 🚀 **BREAKING**: Substituição da API REST por SSH
- ✅ **Novo**: Conexão SSH segura com usuário/senha
- ✅ **Novo**: Arquivos `.conf` para backups
- ✅ **Novo**: Comando `show full-configuration`
- ✅ **Novo**: Suporte a VDOM específico
- ✅ **Melhorado**: Compatibilidade com diferentes versões FortiOS
- ✅ **Melhorado**: Segurança aprimorada

---

<div align="center">

**🛡️ FortiGate Backup System**

*Sistema automatizado para backup seguro de equipamentos FortiGate*

[![Fortinet](https://img.shields.io/badge/Powered%20by-Fortinet-red?logo=fortinet)](https://www.fortinet.com/)
[![Docker](https://img.shields.io/badge/Containerized%20with-Docker-blue?logo=docker)](https://www.docker.com/)
[![Python](https://img.shields.io/badge/Built%20with-Python-green?logo=python)](https://www.python.org/)

</div>