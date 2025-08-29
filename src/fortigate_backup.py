#!/usr/bin/env python3
"""
FortiGate Backup System via SSH
Sistema automatizado para backup de equipamentos FortiGate via SSH
Adaptado do projeto backup-datacom para FortiGate usando SSH
"""

import os
import sys
import json
import logging
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional
import paramiko
from scp import SCPClient
from dotenv import load_dotenv

class TelegramNotifier:
    """Classe para envio de notificações via Telegram"""
    
    def __init__(self, bot_token: str, chat_id: str):
        self.bot_token = bot_token
        self.chat_id = chat_id
        self.base_url = f"https://api.telegram.org/bot{bot_token}"
    
    def send_message(self, message: str) -> bool:
        """Envia mensagem via Telegram"""
        try:
            import requests
            url = f"{self.base_url}/sendMessage"
            data = {
                "chat_id": self.chat_id,
                "text": message,
                "parse_mode": "HTML"
            }
            response = requests.post(url, data=data, timeout=10)
            return response.status_code == 200
        except Exception as e:
            logging.error(f"Erro ao enviar mensagem Telegram: {e}")
            return False

class FortiGateSSHBackup:
    """Classe principal para backup de FortiGate via SSH"""
    
    def __init__(self, config_file: str = "config/devices.json"):
        # Carregar variáveis de ambiente
        load_dotenv()
        
        # Configurações
        self.config_file = config_file
        self.backup_dir = Path(os.getenv('BACKUP_DIR', '/app/backups'))
        self.log_dir = Path(os.getenv('LOG_DIR', '/app/logs'))
        self.retention_days = int(os.getenv('BACKUP_RETENTION_DAYS', '30'))
        self.ssh_timeout = int(os.getenv('SSH_TIMEOUT', '30'))
        self.backup_format = os.getenv('BACKUP_FORMAT', 'text')  # text ou binary
        
        # Criar diretórios se não existirem
        self.backup_dir.mkdir(exist_ok=True)
        self.log_dir.mkdir(exist_ok=True)
        
        # Configurar logging
        self._setup_logging()
        
        # Configurar Telegram
        self.telegram = None
        if os.getenv('TELEGRAM_BOT_TOKEN') and os.getenv('TELEGRAM_CHAT_ID'):
            self.telegram = TelegramNotifier(
                os.getenv('TELEGRAM_BOT_TOKEN'),
                os.getenv('TELEGRAM_CHAT_ID')
            )
        
        # Carregar dispositivos
        self.devices = self._load_devices()
    
    def _setup_logging(self):
        """Configurar sistema de logging"""
        log_level = getattr(logging, os.getenv('LOG_LEVEL', 'INFO').upper())
        log_format = '%(asctime)s - %(levelname)s - %(message)s'
        
        # Configurar logging para arquivo
        if os.getenv('LOG_TO_FILE', 'true').lower() == 'true':
            log_file = self.log_dir / f"fortigate_backup_{datetime.now().strftime('%Y%m%d')}.log"
            logging.basicConfig(
                level=log_level,
                format=log_format,
                handlers=[
                    logging.FileHandler(log_file),
                    logging.StreamHandler(sys.stdout)
                ]
            )
        else:
            logging.basicConfig(level=log_level, format=log_format)
    
    def _load_devices(self) -> List[Dict]:
        """Carregar configuração dos dispositivos"""
        try:
            with open(self.config_file, 'r', encoding='utf-8') as f:
                config = json.load(f)
                return config.get('devices', [])
        except FileNotFoundError:
            logging.error(f"Arquivo de configuração não encontrado: {self.config_file}")
            return []
        except json.JSONDecodeError as e:
            logging.error(f"Erro ao decodificar JSON: {e}")
            return []
    
    def _create_ssh_connection(self, device: Dict) -> Optional[paramiko.SSHClient]:
        """Criar conexão SSH com o dispositivo"""
        try:
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            ssh.connect(
                hostname=device['host'],
                port=device.get('port', 22),
                username=device['username'],
                password=device['password'],
                timeout=device.get('timeout', self.ssh_timeout),
                allow_agent=False,
                look_for_keys=False
            )
            
            logging.info(f"Conexão SSH estabelecida com {device['name']} ({device['host']})")
            return ssh
            
        except Exception as e:
            logging.error(f"Erro ao conectar SSH em {device['name']}: {e}")
            return None
    
    def _execute_command(self, ssh: paramiko.SSHClient, command: str) -> Optional[str]:
        """Executar comando via SSH"""
        try:
            import time
            
            stdin, stdout, stderr = ssh.exec_command(command, timeout=self.ssh_timeout)
            
            # Aguardar um pouco para o comando processar
            time.sleep(1)
            
            # Aguardar execução
            exit_status = stdout.channel.recv_exit_status()
            
            output = stdout.read().decode('utf-8', errors='ignore')
            error = stderr.read().decode('utf-8', errors='ignore')
            
            if exit_status == 0 or output.strip():
                return output.strip()
            else:
                logging.error(f"Erro na execução do comando '{command}': {error}")
                return None
                
        except Exception as e:
            logging.error(f"Erro ao executar comando '{command}': {e}")
            return None
    
    def _backup_configuration(self, device: Dict) -> bool:
        """Fazer backup da configuração do FortiGate"""
        ssh = None
        try:
            logging.info(f"Iniciando backup de configuração: {device['name']}")
            
            # Estabelecer conexão SSH
            ssh = self._create_ssh_connection(device)
            if not ssh:
                return False
            
            # Gerar timestamp para o arquivo
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            
            # Executar comando de backup
            vdom = device.get('vdom', 'root')
            if self.backup_format == 'binary':
                backup_command = f"execute backup config flash backup_{timestamp}.conf"
            else:
                backup_command = "show full-configuration"
            
            logging.info(f"Executando comando: {backup_command}")
            config_output = self._execute_command(ssh, backup_command)
            
            if not config_output:
                logging.error(f"Falha ao obter configuração de {device['name']}")
                return False
            
            # Salvar configuração em arquivo
            backup_filename = f"{device['name']}_config_{timestamp}.conf"
            backup_path = self.backup_dir / backup_filename
            
            with open(backup_path, 'w', encoding='utf-8') as f:
                f.write(f"# Backup de configuração do FortiGate\n")
                f.write(f"# Dispositivo: {device['name']} ({device['host']})\n")
                f.write(f"# Data: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
                f.write(f"# VDOM: {vdom}\n")
                f.write("#" + "="*50 + "\n\n")
                f.write(config_output)
            
            logging.info(f"Backup salvo: {backup_path}")
            
            # Coletar informações do sistema se habilitado
            if os.getenv('COLLECT_SYSTEM_INFO', 'true').lower() == 'true':
                self._collect_system_information(ssh, device, timestamp)
            
            return True
            
        except Exception as e:
            import traceback
            logging.error(f"Erro durante backup de {device['name']}: {e}")
            logging.error(f"Traceback completo: {traceback.format_exc()}")
            return False
        finally:
            if ssh:
                ssh.close()
    
    def _collect_system_information(self, ssh: paramiko.SSHClient, device: Dict, timestamp: str):
        """Coletar informações do sistema"""
        try:
            logging.info(f"Coletando informações do sistema: {device['name']}")
            
            # Comandos para coletar informações do sistema
            system_commands = {
                'system_status': 'get system status',
                'system_performance': 'get system performance status',
                'interface_status': 'get system interface',
                'routing_table': 'get router info routing-table all',
                'arp_table': 'get system arp',
                'session_list': 'get system session list',
                'ha_status': 'get system ha status',
                'license_info': 'get system status | grep License'
            }
            
            system_info = {}
            for info_type, command in system_commands.items():
                output = self._execute_command(ssh, command)
                if output:
                    system_info[info_type] = output
            
            # Salvar informações do sistema
            if system_info:
                system_filename = f"{device['name']}_system_{timestamp}.txt"
                system_path = self.backup_dir / system_filename
                
                with open(system_path, 'w', encoding='utf-8') as f:
                    f.write(f"# Informações do Sistema - FortiGate\n")
                    f.write(f"# Dispositivo: {device['name']} ({device['host']})\n")
                    f.write(f"# Data: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
                    f.write("#" + "="*50 + "\n\n")
                    
                    for info_type, output in system_info.items():
                        f.write(f"\n{'='*20} {info_type.upper()} {'='*20}\n")
                        f.write(output)
                        f.write("\n")
                
                logging.info(f"Informações do sistema salvas: {system_path}")
            
        except Exception as e:
            logging.error(f"Erro ao coletar informações do sistema de {device['name']}: {e}")
    
    def backup_device(self, device: Dict, send_individual_notification: bool = True) -> bool:
        """Fazer backup de um dispositivo específico"""
        try:
            logging.info(f"Iniciando backup do dispositivo: {device['name']} ({device['host']})")
            
            # Validar configuração do dispositivo
            required_fields = ['name', 'host', 'username', 'password']
            for field in required_fields:
                if field not in device:
                    logging.error(f"Campo obrigatório '{field}' não encontrado na configuração do dispositivo")
                    return False
            
            # Executar backup
            success = self._backup_configuration(device)
            
            if success:
                logging.info(f"Backup concluído com sucesso: {device['name']}")
                if self.telegram and send_individual_notification:
                    self.telegram.send_message(
                        f"✅ <b>Backup Concluído</b>\n"
                        f"Dispositivo: {device['name']}\n"
                        f"Host: {device['host']}\n"
                        f"Data: {datetime.now().strftime('%d/%m/%Y %H:%M:%S')}"
                    )
            else:
                logging.error(f"Backup falhou para: {device['name']}")
                if self.telegram and send_individual_notification:
                    self.telegram.send_message(
                        f"❌ <b>Backup Falhou</b>\n"
                        f"Dispositivo: {device['name']}\n"
                        f"Host: {device['host']}\n"
                        f"Data: {datetime.now().strftime('%d/%m/%Y %H:%M:%S')}"
                    )
            
            return success
            
        except Exception as e:
            logging.error(f"Erro inesperado durante backup de {device.get('name', 'Unknown')}: {e}")
            return False
    
    def backup_all_devices(self) -> Dict[str, bool]:
        """Fazer backup de todos os dispositivos configurados"""
        start_time = datetime.now()
        logging.info("Iniciando backup de todos os dispositivos FortiGate")
        
        if not self.devices:
            logging.warning("Nenhum dispositivo configurado para backup")
            return {}
        
        results = {}
        successful_backups = 0
        failed_backups = 0
        successful_devices = []
        failed_devices = []
        
        for device in self.devices:
            device_name = device.get('name', 'Unknown')
            try:
                success = self.backup_device(device, send_individual_notification=False)
                results[device_name] = success
                if success:
                    successful_backups += 1
                    # Contar arquivos de backup para este dispositivo
                    backup_count = len(list(self.backup_dir.glob(f"{device_name}_config_*.conf")))
                    successful_devices.append(f"• {device_name} ({backup_count} arquivo{'s' if backup_count != 1 else ''})")
                else:
                    failed_backups += 1
                    failed_devices.append(f"• {device_name}")
            except Exception as e:
                logging.error(f"Erro ao processar dispositivo {device_name}: {e}")
                results[device_name] = False
                failed_backups += 1
                failed_devices.append(f"• {device_name}")
        
        # Calcular duração
        end_time = datetime.now()
        duration = end_time - start_time
        duration_str = str(duration).split('.')[0]  # Remove microsegundos
        
        # Log do resumo
        total_devices = len(self.devices)
        logging.info(f"Backup concluído. Sucessos: {successful_backups}/{total_devices}")
        
        # Notificação Telegram do resumo no formato da imagem
        if self.telegram:
            if successful_backups == total_devices:
                # Todos os backups foram bem-sucedidos
                message = f"✅ <b>Backup FortiGate - Sucesso</b>\n\n"
                message += f"📊 <b>Resumo:</b>\n"
                message += f"• Sucessos: {successful_backups}\n"
                message += f"• Falhas: {failed_backups}\n"
                message += f"• Duração: {duration_str}\n"
                message += f"• Data: {end_time.strftime('%d/%m/%Y %H:%M:%S')}\n\n"
                
                if successful_devices:
                    message += f"✅ <b>Dispositivos com Sucesso:</b>\n"
                    message += "\n".join(successful_devices)
            else:
                # Houve falhas
                status_emoji = "⚠️" if successful_backups > 0 else "❌"
                status_text = "Parcial" if successful_backups > 0 else "Falha"
                message = f"{status_emoji} <b>Backup FortiGate - {status_text}</b>\n\n"
                message += f"📊 <b>Resumo:</b>\n"
                message += f"• Sucessos: {successful_backups}\n"
                message += f"• Falhas: {failed_backups}\n"
                message += f"• Duração: {duration_str}\n"
                message += f"• Data: {end_time.strftime('%d/%m/%Y %H:%M:%S')}\n\n"
                
                if successful_devices:
                    message += f"✅ <b>Dispositivos com Sucesso:</b>\n"
                    message += "\n".join(successful_devices) + "\n\n"
                
                if failed_devices:
                    message += f"❌ <b>Dispositivos com Falha:</b>\n"
                    message += "\n".join(failed_devices)
            
            self.telegram.send_message(message)
        
        return results
    
    def cleanup_old_backups(self):
        """Limpar backups antigos baseado no período de retenção"""
        try:
            logging.info(f"Iniciando limpeza de backups antigos (>{self.retention_days} dias)")
            
            cutoff_date = datetime.now() - timedelta(days=self.retention_days)
            removed_files = 0
            
            for backup_file in self.backup_dir.glob('*'):
                if backup_file.is_file():
                    file_mtime = datetime.fromtimestamp(backup_file.stat().st_mtime)
                    if file_mtime < cutoff_date:
                        backup_file.unlink()
                        removed_files += 1
                        logging.info(f"Arquivo removido: {backup_file.name}")
            
            logging.info(f"Limpeza concluída. {removed_files} arquivos removidos")
            
        except Exception as e:
            logging.error(f"Erro durante limpeza de backups: {e}")
    
    def test_telegram(self):
        """Testar notificação Telegram"""
        if self.telegram:
            message = f"🧪 <b>Teste de Notificação</b>\nSistema FortiGate Backup SSH\nData: {datetime.now().strftime('%d/%m/%Y %H:%M:%S')}"
            success = self.telegram.send_message(message)
            if success:
                logging.info("Teste do Telegram enviado com sucesso")
            else:
                logging.error("Falha no teste do Telegram")
        else:
            logging.warning("Telegram não configurado")

def main():
    """Função principal"""
    try:
        # Inicializar sistema de backup
        backup_system = FortiGateSSHBackup()
        
        # Executar backup de todos os dispositivos
        backup_system.backup_all_devices()
        
        # Limpar backups antigos
        backup_system.cleanup_old_backups()
        
    except KeyboardInterrupt:
        logging.info("Backup interrompido pelo usuário")
    except Exception as e:
        logging.error(f"Erro inesperado: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()