# Sistema de Monitoramento de CPU

## 📋 Visão Geral

Sistema automatizado de monitoramento de uso de CPU para Windows, implementado em PowerShell. Registra alertas quando o uso da CPU ultrapassa 80%, incluindo timestamp e os processos que mais consomem recursos.

## 🏗️ Arquitetura

### Componentes

1. **Script de Monitoramento** (`monitor-cpu.ps1`)
   - Execução única (sem loops)
   - Coleta métricas via Performance Counter
   - Registra alertas em arquivo de log

2. **Task Scheduler** (Windows)
   - Controla periodicidade de execução
   - Previne instâncias duplicadas
   - Gerencia permissões e contexto de execução

### Fluxo de Execução

```
┌─────────────────────────────────────────────────────────────┐
│ Task Scheduler (a cada 5 minutos)                           │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 1. Verificação de Uptime (> 3 minutos?)                     │
│    └─ Se não: Exit 0 (evita falso positivo no boot)        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Coleta de Métricas                                        │
│    └─ Get-Counter: \Processor(_Total)\% Processor Time      │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Análise: CPU > 80%?                                       │
│    ├─ SIM: Registra alerta + top 5 processos               │
│    └─ NÃO: Exit 0 (sem ação)                                │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Finalização (Exit 0 ou Exit 1)                           │
└─────────────────────────────────────────────────────────────┘
```

## ⚙️ Configuração

### Requisitos

- **Sistema Operacional**: Windows 10/11 ou Windows Server 2016+
- **PowerShell**: Versão 5.1 ou superior
- **Permissões**: Acesso ao Performance Counter
- **Disk**: Mínimo 1 MB livre para logs

### Instalação

#### 1. Script de Monitoramento

```powershell
# O script já está instalado em:
C:\Users\omarl\monitor-cpu.ps1
```

#### 2. Task Scheduler (Requer PowerShell como Administrador)

```powershell
$scriptPath = "C:\Users\omarl\monitor-cpu.ps1"
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -File `"$scriptPath`""

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 5)
$trigger.Repetition.Duration = ""

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName "MonitorCPU" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Monitor de uso de CPU" `
    -Force
```

### Parâmetros Configuráveis

Edite as variáveis no início do script `monitor-cpu.ps1`:

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `$LogFile` | `C:\Users\omarl\cpu-log.txt` | Caminho do arquivo de log |
| `$CpuThreshold` | `80` | Percentual de CPU para alerta |
| `$MinUptimeMinutes` | `3` | Tempo mínimo após boot antes de monitorar |
| `$TopProcessCount` | `5` | Número de processos a registrar |

## 📊 Formato do Log

### Estrutura

```
2026-02-06 01:15:32 - ALERTA: CPU em 85.47%

Name               CPU(s) Memory(MB)
----               ------ ----------
chrome             145.32      523.45
node                89.12      312.78
vscode              45.67      289.34
Teams               32.89      456.12
Slack               28.45      178.90

--------------------------------------------------------------------------------
```

### Rotação de Logs

O sistema não implementa rotação automática. Para gerenciar o tamanho do arquivo:

```powershell
# Visualizar tamanho do log
(Get-Item C:\Users\omarl\cpu-log.txt).Length / 1MB

# Arquivar logs antigos
$date = Get-Date -Format "yyyyMMdd"
Move-Item C:\Users\omarl\cpu-log.txt C:\Users\omarl\cpu-log-$date.txt
```

## 🔧 Operação

### Comandos Úteis

#### Visualizar Logs Recentes

```powershell
# Últimas 20 linhas
Get-Content C:\Users\omarl\cpu-log.txt -Tail 20

# Alertas do dia atual
Get-Content C:\Users\omarl\cpu-log.txt | Select-String (Get-Date -Format "yyyy-MM-dd")
```

#### Gerenciar Tarefa Agendada

```powershell
# Ver status
Get-ScheduledTask -TaskName "MonitorCPU"

# Ver próxima execução
(Get-ScheduledTaskInfo -TaskName "MonitorCPU").NextRunTime

# Desabilitar temporariamente
Disable-ScheduledTask -TaskName "MonitorCPU"

# Reabilitar
Enable-ScheduledTask -TaskName "MonitorCPU"

# Executar manualmente (para teste)
Start-ScheduledTask -TaskName "MonitorCPU"

# Remover tarefa
Unregister-ScheduledTask -TaskName "MonitorCPU" -Confirm:$false
```

#### Teste Manual do Script

```powershell
# Executar com output verbose
powershell.exe -File C:\Users\omarl\monitor-cpu.ps1 -Verbose

# Verificar exit code
$LASTEXITCODE
```

## 🐛 Troubleshooting

### Problema: Tarefa não executa

**Diagnóstico:**
```powershell
Get-ScheduledTask -TaskName "MonitorCPU" | Get-ScheduledTaskInfo
```

**Soluções:**
1. Verificar se tarefa está habilitada: `Enable-ScheduledTask -TaskName "MonitorCPU"`
2. Verificar permissões de execução do script
3. Verificar logs do Task Scheduler: `Event Viewer > Microsoft > Windows > TaskScheduler`

### Problema: Log não é criado

**Diagnóstico:**
```powershell
# Testar permissões de escrita
Add-Content C:\Users\omarl\cpu-log.txt "Teste - $(Get-Date)"
```

**Soluções:**
1. Verificar permissões de escrita no diretório
2. Verificar se o caminho existe
3. Executar script manualmente com `-Verbose` para ver erros

### Problema: Muitos falsos positivos

**Soluções:**
1. Aumentar `$CpuThreshold` no script (ex: de 80 para 90)
2. Aumentar `$MinUptimeMinutes` para ignorar mais tempo após boot
3. Adicionar filtro de horário (ex: apenas horário comercial)

## 📈 Melhorias Futuras

### Possíveis Extensões

1. **Notificações**: Enviar email ou notificação Windows quando CPU > threshold
2. **Dashboard**: Integração com ferramentas de visualização (Grafana, PowerBI)
3. **Rotação Automática**: Implementar rotação de logs baseada em tamanho/data
4. **Análise de Tendências**: Gerar relatórios semanais/mensais de uso
5. **Alertas Inteligentes**: Machine Learning para detectar padrões anormais
6. **Multi-Métrica**: Monitorar também RAM, Disco, Rede

### Exemplo: Adicionar Notificação por Email

```powershell
# Adicionar ao final da seção "ANÁLISE E REGISTRO"
if ($cpuUsage -gt $CpuThreshold) {
    # ... código existente ...
    
    # Enviar email
    $mailParams = @{
        To = "admin@example.com"
        From = "monitor@example.com"
        Subject = "ALERTA: CPU em $cpuRounded%"
        Body = $alertMessage
        SmtpServer = "smtp.example.com"
    }
    Send-MailMessage @mailParams
}
```

## 📝 Convenções de Código

### Padrões Adotados

- **Comentários**: Baseado em Comment-Based Help do PowerShell
- **Nomenclatura**: PascalCase para variáveis, verbos aprovados do PowerShell
- **Tratamento de Erros**: Try-Catch com ErrorAction Stop
- **Exit Codes**: 0 = sucesso, 1 = erro
- **Encoding**: UTF-8 para suporte a caracteres especiais

### Versionamento

Formato: `MAJOR.MINOR`
- **MAJOR**: Mudanças incompatíveis com versão anterior
- **MINOR**: Novas funcionalidades compatíveis

## 📄 Licença

Este é um projeto interno. Todos os direitos reservados.

## 👥 Contato

**Autor**: Omar L  
**Criado**: 2026-02-06  
**Versão**: 2.0

---

**Última atualização**: 2026-02-06
