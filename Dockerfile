# Dockerfile para FortiGate Backup System
# Adaptado do projeto backup-datacom para FortiGate

FROM python:3.11-slim

# Metadados
LABEL maintainer="FortiGate Backup System"
LABEL description="Sistema automatizado para backup de equipamentos FortiGate via API REST"
LABEL version="1.0.0"

# Variáveis de ambiente
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV TZ=America/Sao_Paulo

# Criar usuário não-root para segurança
RUN groupadd -r backup 2>/dev/null || true && \
    useradd -r -g backup backup 2>/dev/null || true

# Instalar dependências do sistema
RUN apt-get update && apt-get install -y \
    tzdata \
    curl \
    cron \
    && rm -rf /var/lib/apt/lists/*

# Configurar timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Criar diretórios de trabalho
WORKDIR /app

# Criar diretórios necessários
RUN mkdir -p /app/src /app/config /app/backups /app/logs /app/scripts

# Copiar arquivo de dependências
COPY requirements.txt .

# Instalar dependências Python
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copiar código fonte
COPY src/ ./src/
COPY config/ ./config/
COPY scripts/ ./scripts/

# Copiar arquivo de configuração de exemplo se não existir config específico
COPY .env.example .env.example

# Tornar scripts executáveis
RUN chmod +x /app/scripts/*.sh

# Configuração com cron interno para agendamento automático

# Ajustar permissões dos diretórios
RUN chown -R backup:backup /app && \
    chmod -R 755 /app/backups /app/logs /app/config && \
    chmod -R 644 /app/src/*.py

# Copiar script de entrada
COPY entrypoint.sh /app/entrypoint.sh

# Tornar script de entrada executável
RUN chmod +x /app/entrypoint.sh

# Mudar para usuário não-root
USER backup

# Expor porta para monitoramento (opcional)
EXPOSE 8080

# Volumes para persistência de dados
VOLUME ["/app/backups", "/app/logs", "/app/config"]

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import sys; sys.exit(0)" || exit 1

# Ponto de entrada
ENTRYPOINT ["/app/entrypoint.sh"]

# Comando padrão
CMD []