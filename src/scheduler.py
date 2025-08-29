#!/usr/bin/env python3
"""
Scheduler simples para executar backups em intervalos definidos
Substitui o cron para evitar problemas de permissões no container
"""

import os
import sys
import time
import subprocess
from datetime import datetime, timedelta
from croniter import croniter

def log_message(message):
    """Log com timestamp"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}")
    sys.stdout.flush()

def run_backup():
    """Executa o backup"""
    try:
        log_message("🚀 Iniciando backup agendado")
        result = subprocess.run(
            [sys.executable, "/app/src/fortigate_backup.py"],
            cwd="/app",
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            log_message("✅ Backup concluído com sucesso")
        else:
            log_message(f"❌ Erro no backup: {result.stderr}")
            
        # Log do resultado
        with open("/app/logs/cron.log", "a") as f:
            f.write(f"\n--- Backup executado em {datetime.now()} ---\n")
            f.write(f"Return code: {result.returncode}\n")
            f.write(f"STDOUT:\n{result.stdout}\n")
            f.write(f"STDERR:\n{result.stderr}\n")
            f.write("-" * 50 + "\n")
            
    except Exception as e:
        log_message(f"❌ Erro ao executar backup: {e}")

def main():
    """Função principal do scheduler"""
    # Ler configuração do .env
    cron_schedule = os.getenv('CRON_SCHEDULE')
    if not cron_schedule:
        log_message("❌ CRON_SCHEDULE não definido")
        sys.exit(1)
    
    log_message(f"📅 Scheduler iniciado com agendamento: {cron_schedule}")
    
    try:
        cron = croniter(cron_schedule, datetime.now())
    except Exception as e:
        log_message(f"❌ Erro no formato do cron: {e}")
        sys.exit(1)
    
    # Loop principal
    while True:
        try:
            # Próxima execução
            next_run = cron.get_next(datetime)
            log_message(f"⏰ Próxima execução: {next_run.strftime('%Y-%m-%d %H:%M:%S')}")
            
            # Aguardar até a próxima execução
            while datetime.now() < next_run:
                time.sleep(30)  # Verificar a cada 30 segundos
            
            # Executar backup
            run_backup()
            
        except KeyboardInterrupt:
            log_message("🛑 Scheduler interrompido")
            break
        except Exception as e:
            log_message(f"❌ Erro no scheduler: {e}")
            time.sleep(60)  # Aguardar 1 minuto antes de tentar novamente

if __name__ == "__main__":
    main()