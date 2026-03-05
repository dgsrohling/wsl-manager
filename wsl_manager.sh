#!/bin/bash

# ==============================================================================
#
#   WSL-MANAGER — Remote Windows Administration via Bash + PowerShell
#   A paradigm demonstration by Dionisio Rohling (D. Rohling)
#   Computer Engineer
#
#   Concept: Use Bash as the orchestration layer and PowerShell as the
#   execution engine for remote Windows administration — all from WSL.
#
#   GitHub: https://github.com/drohling/wsl-manager
#
# ==============================================================================

# ------------------------------------------------------------------------------
# ANSI COLORS
# ------------------------------------------------------------------------------
green='\033[0;32m'
yellow='\033[0;33m'
red='\033[0;31m'
NC='\033[0m'

# ------------------------------------------------------------------------------
# BINARY PATHS — adjust to your environment
# ------------------------------------------------------------------------------
POWERSHELL='/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'
PSEXEC='/mnt/c/Windows/System32/PsExec64.exe'

# ------------------------------------------------------------------------------
# NAS / FILE SERVER — adjust to your environment
# ------------------------------------------------------------------------------
NAS='\\fileserver\Install'

# ------------------------------------------------------------------------------
# CORE FUNCTIONS
# ------------------------------------------------------------------------------

# Print colored message: msg <color_var> <text>
msg() {
    local color="$1"; shift
    echo -e "${!color}${*}${NC}"
}

# Log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> wsl-manager.log
}

# Check host connectivity — sets $status to "online" or "offline"
check_host() {
    if ping -c 2 "$1" &>/dev/null; then
        status="online"
    else
        status="offline"
    fi
}

# Print host offline error
offline_err() {
    msg red "[!] Host '$1' is unreachable."
}

# Simple yes/no confirmation using select
confirm() {
    local prompt="${1:-Are you sure?}"
    echo "$prompt"
    select yn in "Yes" "No"; do
        case $yn in
            Yes) return 0 ;;
            No)  return 1 ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# SHOW HELP
# ------------------------------------------------------------------------------
show_help() {
    cat <<EOF

  WSL-MANAGER — Remote Windows Administration via Bash + PowerShell
  by D. Rohling | Computer Engineer

  Usage: wm <option> <hostname> [args]

  HOST CONTROL
    -ping  <host>          Check host connectivity
    -off   <host>          Shutdown remote host
    -rb    <host>          Restart remote host
    -cmd   <host>          Open remote CMD via PsExec

  INFORMATION
    -info  <host>          OS info, architecture, hostname
    -who   <host>          Currently logged-on user
    -procs <host>          List running processes
    -progs <host>          List installed programs
    -disks <host>          Disk usage

  SERVICES
    -svc-start <host> <service>   Start a Windows service remotely
    -svc-stop  <host> <service>   Stop a Windows service remotely
    -svc-list  <host>             List all running services
    -winrm     <host>             Start WinRM on remote host

  MAINTENANCE
    -gpupdate  <host>      Force Group Policy update
    -dns-reg   <host>      Register DNS and apply GPUpdate
    -sfc       <host>      Run sfc /scannow remotely
    -clean-spool <host>    Clear print spooler

  REMOTE INSTALL (examples)
    -install   <host> <app>    Install app from NAS share (see APPS below)

  Available apps: chrome | firefox | pdf24 | libreoffice | anydesk

  ACTIVE DIRECTORY
    -find-pc   <name>      Find computer in AD
    -find-user <name>      Find user in AD
    -os-count              Count machines by OS in domain

  OTHER
    -msg  <host> <"text">  Send a message to the remote user
    -printers <host>       List installed printers
    -del-printers <host>   Remove all printers from host

EOF
}

# ------------------------------------------------------------------------------
# MAIN
# ------------------------------------------------------------------------------

if [ -z "$2" ] && [[ "$1" != "-os-count" && "$1" != "--help" && "$1" != "-h" ]]; then
    show_help
    exit 0
fi

case "$1" in

    # --------------------------------------------------------------------------
    # HOST CONTROL
    # --------------------------------------------------------------------------

    # Ping with colored output
    -ping)
        check_host "$2"
        if [ "$status" = "online" ]; then
            msg green "[✓] $2 is ONLINE"
            ping -c 3 "$2" | grep -E "bytes|avg"
        else
            offline_err "$2"
        fi
        ;;

    # Shutdown remote host
    -off)
        check_host "$2"
        if [ "$status" = "online" ]; then
            confirm "Shut down '$2'?" && {
                "$PSEXEC" '\\'$2 shutdown -s -t 0 /f >/dev/null 2>/dev/null
                msg yellow "[!] Shutdown command sent to $2."
                log "Shutdown sent to $2"
            }
        else
            offline_err "$2"
        fi
        ;;

    # Restart remote host
    -rb)
        check_host "$2"
        if [ "$status" = "online" ]; then
            confirm "Restart '$2'?" && {
                "$PSEXEC" '\\'$2 shutdown -r -t 0 /f >/dev/null 2>/dev/null
                msg yellow "[!] Restart command sent to $2."
                log "Restart sent to $2"
            }
        else
            offline_err "$2"
        fi
        ;;

    # Open remote CMD session via PsExec
    -cmd)
        check_host "$2"
        if [ "$status" = "online" ]; then
            msg yellow "[!] Opening remote CMD on $2..."
            "$PSEXEC" '\\'$2 cmd
        else
            offline_err "$2"
        fi
        ;;

    # --------------------------------------------------------------------------
    # INFORMATION
    # --------------------------------------------------------------------------

    # OS info — calls PowerShell Invoke-Command via WinRM
    -info)
        check_host "$2"
        if [ "$status" = "online" ]; then
            msg yellow "[i] System info for: $2"
            echo "--------------------------------------"
            #
            # KEY CONCEPT:
            # Bash expands $2 before passing the string to PowerShell.
            # Single quotes around the -ScriptBlock protect PS syntax from Bash.
            #
            "$POWERSHELL" Invoke-Command -ComputerName "$2" \
                '-ScriptBlock {
                    Get-CimInstance Win32_OperatingSystem |
                    Select-Object CSName, Caption, OSArchitecture, Version
                }' | sed \
                    -e 's/CSName/Hostname    /' \
                    -e 's/Caption/OS          /' \
                    -e 's/OSArchitecture/Architecture/' \
                    -e 's/Version/Build       /'
            echo "--------------------------------------"
        else
            offline_err "$2"
        fi
        ;;

    # Currently logged-on user
    -who)
        check_host "$2"
        if [ "$status" = "online" ]; then
            logged_user=$("$POWERSHELL" \
                Get-WmiObject -Class Win32_ComputerSystem -ComputerName "$2" \
                '|' Select-Object -ExpandProperty UserName)
            msg yellow "[i] User logged on $2: $logged_user"
        else
            offline_err "$2"
        fi
        ;;

    # List running processes
    -procs)
        check_host "$2"
        if [ "$status" = "online" ]; then
            msg yellow "[i] Processes on $2:"
            "$PSEXEC" '\\'$2 tasklist
        else
            offline_err "$2"
        fi
        ;;

    # List installed programs
    -progs)
        check_host "$2"
        if [ "$status" = "online" ]; then
            msg yellow "[i] Installed programs on $2:"
            "$PSEXEC" '\\'$2 net start winrm >/dev/null 2>/dev/null
            "$POWERSHELL" Invoke-Command -ComputerName "$2" '-ScriptBlock {
                $reg64 = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
                         Select-Object DisplayName, DisplayVersion
                $reg32 = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
                         Select-Object DisplayName, DisplayVersion
                ($reg64 + $reg32) | Where-Object DisplayName |
                Sort-Object DisplayName -Unique | Format-Table -AutoSize
            }'
        else
            offline_err "$2"
        fi
        ;;

    # Disk usage
    -disks)
        check_host "$2"
        if [ "$status" = "online" ]; then
            msg yellow "[i] Disk usage on $2:"
            "$POWERSHELL" Invoke-Command -ComputerName "$2" '-ScriptBlock {
                Get-PSDrive -PSProvider FileSystem |
                Select-Object Name,
                    @{N="Used(GB)";  E={[math]::Round($_.Used/1GB,2)}},
                    @{N="Free(GB)";  E={[math]::Round($_.Free/1GB,2)}},
                    @{N="Total(GB)"; E={[math]::Round(($_.Used+$_.Free)/1GB,2)}} |
                Format-Table -AutoSize
            }'
        else
            offline_err "$2"
        fi
        ;;

    # --------------------------------------------------------------------------
    # SERVICES
    # --------------------------------------------------------------------------

    # Start a Windows service remotely
    -svc-start)
        # $2 = host, $3 = service name
        if [ -z "$3" ]; then
            msg red "[!] Usage: wm -svc-start <host> <service>"
            exit 1
        fi
        check_host "$2"
        if [ "$status" = "online" ]; then
            msg yellow "[!] Starting service '$3' on $2..."
            "$PSEXEC" '\\'$2 net start "$3" >/dev/null 2>/dev/null
            msg green "[✓] Service '$3' started on $2."
            log "Service '$3' started on $2"
        else
            offline_err "$2"
        fi
        ;;

    # Stop a Windows service remotely
    -svc-stop)
        if [ -z "$3" ]; then
            msg red "[!] Usage: wm -svc-stop <host> <service>"
            exit 1
        fi
        check_host "$2"
        if [ "$status" = "online" ]; then
            confirm "Stop service '$3' on '$2'?" && {
                "$PSEXEC" '\\'$2 net stop "$3" >/dev/null 2>/dev/null
                msg yellow "[!] Service '$3' stopped on $2."
                log "Service '$3' stopped on $2"
            }
        else
            offline_err "$2"
        fi
        ;;

    # List running services
    -svc-list)
        check_host "$2"
        if [ "$status" = "online" ]; then
            msg yellow "[i] Running services on $2:"
            "$POWERSHELL" Invoke-Command -ComputerName "$2" \
                '-ScriptBlock { Get-Service | Where-Object Status -eq Running | Select-Object Name, DisplayName }'
        else
            offline_err "$2"
        fi
        ;;

    # Start WinRM on remote host (prerequisite for Invoke-Command)
    -winrm)
        check_host "$2"
        if [ "$status" = "online" ]; then
            "$PSEXEC" '\\'$2 net start winrm >/dev/null 2>/dev/null
            msg green "[✓] WinRM started on $2."
        else
            offline_err "$2"
        fi
        ;;

    # --------------------------------------------------------------------------
    # MAINTENANCE
    # --------------------------------------------------------------------------

    # Force Group Policy update
    -gpupdate)
        check_host "$2"
        if [ "$status" = "online" ]; then
            confirm "Force GPUpdate on '$2'?" && {
                "$POWERSHELL" Invoke-GPUpdate -Computer "$2" -Force >/dev/null 2>/dev/null
                msg green "[✓] GPUpdate applied on $2."
            }
        else
            offline_err "$2"
        fi
        ;;

    # Register DNS and apply GPUpdate
    -dns-reg)
        check_host "$2"
        if [ "$status" = "online" ]; then
            msg yellow "[!] Registering DNS on $2..."
            "$PSEXEC" '\\'$2 net start winrm >/dev/null 2>/dev/null
            "$POWERSHELL" psexec '\\'$2 ipconfig /registerdns >/dev/null 2>/dev/null
            msg yellow "[!] Applying GPUpdate..."
            "$POWERSHELL" Invoke-GPUpdate -Computer "$2" -Force >/dev/null 2>/dev/null
            msg green "[✓] DNS registered. Allow up to 15 minutes to propagate."
        else
            offline_err "$2"
        fi
        ;;

    # Run sfc /scannow remotely
    -sfc)
        check_host "$2"
        if [ "$status" = "online" ]; then
            confirm "Run 'sfc /scannow' on '$2'?" && {
                msg yellow "[!] Running SFC on $2, please wait..."
                "$PSEXEC" '\\'$2 net start winrm >/dev/null 2>/dev/null
                "$POWERSHELL" Invoke-Command -ComputerName "$2" \
                    '-ScriptBlock { sfc.exe /scannow }'
                msg green "[✓] SFC completed on $2."
            }
        else
            offline_err "$2"
        fi
        ;;

    # Clear print spooler
    -clean-spool)
        check_host "$2"
        if [ "$status" = "online" ]; then
            msg yellow "[!] Clearing print spooler on $2..."
            "$PSEXEC" '\\'$2 net stop spooler >/dev/null 2>/dev/null
            "$POWERSHELL" psexec '\\'$2 powershell \
                Remove-Item -Path '$env:windir\system32\spool\PRINTERS\*.*' >/dev/null 2>/dev/null
            "$PSEXEC" '\\'$2 net start spooler >/dev/null 2>/dev/null
            msg green "[✓] Spooler cleared and restarted on $2."
        else
            offline_err "$2"
        fi
        ;;

    # --------------------------------------------------------------------------
    # REMOTE INSTALL
    #
    # Concept: copy installer from NAS to remote C:, execute silently via
    # PsExec, then run a cleanup script to remove the installer.
    #
    # This is the core pattern of the paradigm:
    #   1. Bash checks connectivity and drives the flow
    #   2. PowerShell Copy-Item handles UNC file copy
    #   3. PsExec executes the installer on the remote host
    #   4. A PS1 cleanup script removes leftovers
    # --------------------------------------------------------------------------

    -install)
        # $2 = host, $3 = app name
        if [ -z "$3" ]; then
            msg red "[!] Usage: wm -install <host> <app>"
            msg yellow "    Available: chrome | firefox | pdf24 | libreoffice | anydesk"
            exit 1
        fi

        check_host "$2"
        if [ "$status" != "online" ]; then
            offline_err "$2"
            exit 1
        fi

        case "$3" in

            chrome)
                msg yellow "[!] Installing Google Chrome on $2..."
                "$POWERSHELL" Copy-Item \
                    -Path "$NAS\Browsers\Chrome\googlechromestandaloneenterprise64.msi" \
                    -Destination '\\'$2'\c$\chrome.msi' >/dev/null 2>/dev/null
                "$PSEXEC" '\\'$2 \
                    'c:\Windows\System32\msiexec.exe /i c:\chrome.msi /qn' >/dev/null 2>/dev/null
                # Cleanup — remove installer from remote C:
                "$POWERSHELL" Remove-Item -Path '\\'$2'\c$\chrome.msi' -Force >/dev/null 2>/dev/null
                msg green "[✓] Google Chrome installed on $2."
                ;;

            firefox)
                msg yellow "[!] Installing Mozilla Firefox on $2..."
                "$POWERSHELL" Copy-Item \
                    -Path "$NAS\Browsers\Firefox\Firefox_Setup.msi" \
                    -Destination '\\'$2'\c$\firefox.msi' >/dev/null 2>/dev/null
                "$PSEXEC" '\\'$2 \
                    'c:\Windows\System32\msiexec.exe /i c:\firefox.msi /qn' >/dev/null 2>/dev/null
                "$POWERSHELL" Remove-Item -Path '\\'$2'\c$\firefox.msi' -Force >/dev/null 2>/dev/null
                msg green "[✓] Mozilla Firefox installed on $2."
                ;;

            pdf24)
                msg yellow "[!] Installing PDF24 on $2..."
                "$POWERSHELL" Copy-Item \
                    -Path "$NAS\PDF\pdf24.msi" \
                    -Destination '\\'$2'\c$\pdf24.msi' >/dev/null 2>/dev/null
                "$PSEXEC" '\\'$2 \
                    'c:\Windows\System32\msiexec.exe /i c:\pdf24.msi /qn' >/dev/null 2>/dev/null
                "$POWERSHELL" Remove-Item -Path '\\'$2'\c$\pdf24.msi' -Force >/dev/null 2>/dev/null
                msg green "[✓] PDF24 installed on $2."
                ;;

            libreoffice)
                msg yellow "[!] Installing LibreOffice on $2..."
                "$POWERSHELL" Copy-Item \
                    -Path "$NAS\Office\LibreOffice\LibreOffice_x64.msi" \
                    -Destination '\\'$2'\c$\libreoffice.msi' >/dev/null 2>/dev/null
                "$PSEXEC" '\\'$2 \
                    'c:\Windows\System32\msiexec.exe /i c:\libreoffice.msi RebootYesNo=No /qn' \
                    >/dev/null 2>/dev/null
                "$POWERSHELL" Remove-Item -Path '\\'$2'\c$\libreoffice.msi' -Force >/dev/null 2>/dev/null
                msg green "[✓] LibreOffice installed on $2."
                ;;

            anydesk)
                msg yellow "[!] Installing AnyDesk on $2..."
                "$POWERSHELL" Copy-Item \
                    -Path "$NAS\RemoteAccess\AnyDesk.exe" \
                    -Destination '\\'$2'\c$\AnyDesk.exe' >/dev/null 2>/dev/null
                "$PSEXEC" '\\'$2 \
                    'c:\AnyDesk.exe --install "C:\Program Files (x86)\AnyDesk" --start-with-win --create-shortcuts --create-desktop-icon --silent' \
                    >/dev/null 2>/dev/null
                "$POWERSHELL" Remove-Item -Path '\\'$2'\c$\AnyDesk.exe' -Force >/dev/null 2>/dev/null
                msg green "[✓] AnyDesk installed on $2."
                ;;

            *)
                msg red "[!] Unknown app: $3"
                msg yellow "    Available: chrome | firefox | pdf24 | libreoffice | anydesk"
                ;;
        esac
        ;;

    # --------------------------------------------------------------------------
    # ACTIVE DIRECTORY
    # --------------------------------------------------------------------------

    # Find computer in AD
    -find-pc)
        msg yellow "[i] Searching for computer '$2' in AD..."
        "$POWERSHELL" Get-ADComputer -Filter '{Name -like "*'$2'*"}' \
            '|' Select-Object Name, DNSHostName, Enabled \
            | sed -e 's/Name/Computer/' -e 's/DNSHostName/DNS/' -e 's/Enabled/Active/'
        ;;

    # Find user in AD
    -find-user)
        msg yellow "[i] Searching for user '$2' in AD..."
        "$POWERSHELL" Get-ADUser -Filter '{Name -like "*'$2'*"}' \
            '|' Select-Object Name, SamAccountName, Enabled \
            | sed -e 's/Name/Full Name/' -e 's/SamAccountName/Username/' -e 's/Enabled/Active/'
        ;;

    # Count machines by OS version in the domain
    -os-count)
        msg yellow "[i] OS distribution across the domain:"
        "$POWERSHELL" -NonInteractive \
            'Get-ADComputer -Filter * -Property OperatingSystem |
             Group-Object OperatingSystem |
             Select-Object Name, Count |
             Sort-Object Count -Descending |
             Format-Table -AutoSize'
        ;;

    # --------------------------------------------------------------------------
    # MESSAGING AND PRINTERS
    # --------------------------------------------------------------------------

    # Send a message to the remote user's screen
    -msg)
        # $2 = host, $3 = message (quote it: "your message here")
        if [ -z "$3" ]; then
            msg red "[!] Usage: wm -msg <host> \"Your message here\""
            exit 1
        fi
        check_host "$2"
        if [ "$status" = "online" ]; then
            "$POWERSHELL" msg /server:"$2" '*' "$3"
            msg green "[✓] Message sent to $2."
        else
            offline_err "$2"
        fi
        ;;

    # List installed printers
    -printers)
        check_host "$2"
        if [ "$status" = "online" ]; then
            msg yellow "[i] Printers on $2:"
            "$PSEXEC" '\\'$2 net start winrm >/dev/null 2>/dev/null
            "$POWERSHELL" Invoke-Command -ComputerName "$2" \
                '-ScriptBlock { Get-Printer | Select-Object Name, DriverName, PortName }'
        else
            offline_err "$2"
        fi
        ;;

    # Remove all printers (except PDF/virtual ones)
    -del-printers)
        check_host "$2"
        if [ "$status" = "online" ]; then
            confirm "Remove all physical printers from '$2'?" && {
                msg yellow "[!] Removing printers on $2..."
                "$PSEXEC" '\\'$2 net start winrm >/dev/null 2>/dev/null
                "$POWERSHELL" Invoke-Command -ComputerName "$2" \
                    '-ScriptBlock {
                        Get-Printer |
                        Where-Object { $_.Name -notmatch "PDF|OneNote|Fax|XPS" } |
                        Remove-Printer
                    }' >/dev/null 2>/dev/null
                msg green "[✓] Printers removed from $2."
                log "Printers removed from $2"
            }
        else
            offline_err "$2"
        fi
        ;;

    # --------------------------------------------------------------------------
    # HELP / INVALID
    # --------------------------------------------------------------------------

    -h|--help)
        show_help
        ;;

    *)
        msg red "[!] Unknown option: $1"
        show_help
        ;;

esac
