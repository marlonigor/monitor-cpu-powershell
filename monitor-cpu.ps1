<#
.SYNOPSIS
    Monitor de uso de CPU com registro de alertas em arquivo de log.

.DESCRIPTION
    Script de monitoramento que verifica o uso atual da CPU do sistema.
    Quando o uso ultrapassa 80%, registra um alerta em arquivo de log incluindo:
    - Timestamp do evento
    - Percentual de uso da CPU
    - Top 5 processos que mais consomem CPU
    
    Este script foi projetado para ser executado periodicamente via Task Scheduler,
    sem loop interno, garantindo execução limpa e sem acúmulo de instâncias.

.PARAMETER None
    Este script não aceita parâmetros.

.OUTPUTS
    System.Void
    Grava alertas no arquivo C:\Users\omarl\cpu-log.txt quando CPU > 80%.

.EXAMPLE
    .\monitor-cpu.ps1
    Executa o monitoramento uma vez e encerra.

.NOTES
    File Name      : monitor-cpu.ps1
    Author         : Omar L
    Prerequisite   : PowerShell 5.1+, Performance Counter access
    Created        : 2026-02-06
    Version        : 2.0
    
    Configuração do Task Scheduler:
    - Frequência: A cada 5 minutos
    - MultipleInstances: IgnoreNew
    - Início: Após boot (com delay de 3 minutos)
    
    Modificações:
    v2.0 - 2026-02-06: Removido loop infinito, adicionado filtro de boot
    v1.0 - 2026-02-06: Versão inicial

.LINK
    https://docs.microsoft.com/powershell/module/microsoft.powershell.diagnostics/get-counter
#>

#Requires -Version 5.1

# ============================================================================
# CONFIGURAÇÃO
# ============================================================================

# Caminho do arquivo de log
[string]$LogFile = "C:\Users\omarl\cpu-log.txt"

# Threshold de CPU para alerta (em percentual)
[int]$CpuThreshold = 80

# Tempo mínimo de uptime antes de monitorar (evita falso positivo no boot)
[int]$MinUptimeMinutes = 3

# Número de processos top a registrar
[int]$TopProcessCount = 5

# ============================================================================
# VALIDAÇÕES PRÉ-EXECUÇÃO
# ============================================================================

# Verifica se o sistema acabou de iniciar (evita falso positivo)
try {
    $uptime = (Get-Uptime).TotalMinutes
    if ($uptime -lt $MinUptimeMinutes) {
        Write-Verbose "Sistema com uptime de $([math]::Round($uptime, 2)) minutos. Aguardando estabilização."
        exit 0
    }
} catch {
    Write-Warning "Não foi possível verificar uptime. Continuando execução."
}

# ============================================================================
# COLETA DE MÉTRICAS
# ============================================================================

try {
    # Obtém o uso atual da CPU do sistema
    $cpuCounter = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction Stop
    $cpuUsage = $cpuCounter.CounterSamples.CookedValue
    
} catch {
    Write-Error "Erro ao coletar métrica de CPU: $_"
    exit 1
}

# ============================================================================
# ANÁLISE E REGISTRO
# ============================================================================

if ($cpuUsage -gt $CpuThreshold) {
    
    try {
        # Formata timestamp e mensagem de alerta
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $cpuRounded = [math]::Round($cpuUsage, 2)
        $alertMessage = "$timestamp - ALERTA: CPU em $cpuRounded%"
        
        # Registra alerta principal
        Add-Content -Path $LogFile -Value $alertMessage -ErrorAction Stop
        
        # Coleta top processos por uso de CPU
        $topProcesses = Get-Process | 
                        Sort-Object CPU -Descending | 
                        Select-Object -First $TopProcessCount |
                        Format-Table Name, @{Label="CPU(s)";Expression={$_.CPU}}, @{Label="Memory(MB)";Expression={[math]::Round($_.WorkingSet64/1MB, 2)}} -AutoSize |
                        Out-String
        
        # Registra processos no log
        Add-Content -Path $LogFile -Value $topProcesses -ErrorAction Stop
        Add-Content -Path $LogFile -Value ("-" * 80) -ErrorAction Stop
        
        Write-Verbose "Alerta registrado: CPU em $cpuRounded%"
        
    } catch {
        Write-Error "Erro ao escrever no arquivo de log: $_"
        exit 1
    }
    
} else {
    Write-Verbose "CPU em $([math]::Round($cpuUsage, 2))% - Abaixo do threshold ($CpuThreshold%)"
}

# ============================================================================
# FINALIZAÇÃO
# ============================================================================

exit 0
