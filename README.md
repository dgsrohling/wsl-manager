# wsl-manager

> **Remote Windows administration using Bash as the orchestrator and PowerShell as the execution engine — all from WSL.**
> by [Dionisio Rohling](https://github.com/drohling) — Computer Engineer

---

## The Paradigm

Most tools that combine Bash and PowerShell go in one direction: they call Linux commands *from inside PowerShell*. This project inverts that:

```
┌──────────────────────────────────────────────────────────────┐
│                        WSL (Linux)                           │
│                                                              │
│   wsl-manager.sh  ──────►  powershell.exe  ──────►  Host    │
│         │                       │                   │        │
│    Bash controls           PS executes          Windows      │
│    ─────────────           ───────────          ───────      │
│    Connectivity            WinRM sessions       Services     │
│    Flow control            Invoke-Command       Registry     │
│    User interaction        File copy (UNC)      AD queries   │
│    Logging / output        PsExec calls         Processes    │
│    Text processing         GPUpdate / DNS       Printers     │
└──────────────────────────────────────────────────────────────┘
```

**Bash handles:** connectivity checks, argument parsing, flow control, user interaction (`select`, `read`), colored output, logging, text processing (`sed`, `awk`, `grep`).

**PowerShell handles:** everything that requires a Windows context — WinRM sessions, Active Directory, UNC file operations, service management, and remote process execution via PsExec.

The result is a fast, readable administration tool that leverages the best of both worlds — with zero agents installed on the target machines.

---

## Why this combination?

| Need | Best tool |
|---|---|
| Connectivity check | `ping` (Bash) |
| Flow control & interaction | Bash (`case`, `select`, `if`) |
| Colored terminal output | ANSI escape codes (Bash) |
| Log entries with timestamps | `date` + append (Bash) |
| Text parsing from command output | `sed`, `awk`, `grep` (Bash) |
| Remote Windows session | `Invoke-Command` (PowerShell) |
| Copy file to UNC path `\\host\c$` | `Copy-Item` (PowerShell) |
| Execute process on remote host | `PsExec` (called via PowerShell) |
| Active Directory queries | `Get-ADComputer`, `Get-ADUser` (PowerShell) |
| Remote service management | `net start/stop` via PsExec |

---

## Requirements

| Component | Notes |
|---|---|
| WSL | Any Linux distro. Tested on Debian. |
| Windows PowerShell 5.1 | At `/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe` |
| PsExec64.exe | From [Sysinternals](https://learn.microsoft.com/en-us/sysinternals/downloads/psexec). Place at `C:\Windows\System32\`. |
| WinRM enabled on targets | Required for `Invoke-Command`. Enable with: `winrm quickconfig` |
| Network access to hosts | ICMP and SMB must be allowed |
| Active Directory | Required only for AD commands |

---

## Installation

```bash
git clone https://github.com/drohling/wsl-manager
cd wsl-manager
chmod +x wsl-manager.sh

# Optional: create an alias
echo "alias wm='bash ~/wsl-manager/wsl-manager.sh'" >> ~/.bashrc
source ~/.bashrc
```

Edit the paths at the top of `wsl-manager.sh` to match your environment:

```bash
POWERSHELL='/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'
PSEXEC='/mnt/c/Windows/System32/PsExec64.exe'
NAS='\\fileserver\Install'
```

---

## Usage

```bash
wm <option> <hostname> [args]
```

---

## Command Reference

### Host Control

```bash
wm -ping  <host>        # Check connectivity with colored output
wm -off   <host>        # Shutdown remote host (with confirmation)
wm -rb    <host>        # Restart remote host (with confirmation)
wm -cmd   <host>        # Open remote CMD via PsExec
```

### Information

```bash
wm -info  <host>        # OS name, architecture, build version
wm -who   <host>        # Currently logged-on user
wm -procs <host>        # List running processes
wm -progs <host>        # List installed programs (x64 + x86 registry)
wm -disks <host>        # Disk usage (used / free / total in GB)
```

### Services

```bash
wm -svc-start <host> <service>    # Start a Windows service
wm -svc-stop  <host> <service>    # Stop a Windows service (with confirmation)
wm -svc-list  <host>              # List all running services
wm -winrm     <host>              # Start WinRM (prerequisite for Invoke-Command)
```

### Maintenance

```bash
wm -gpupdate    <host>    # Force Group Policy update
wm -dns-reg     <host>    # Register DNS + apply GPUpdate
wm -sfc         <host>    # Run sfc /scannow remotely
wm -clean-spool <host>    # Clear and restart print spooler
```

### Remote Install

```bash
wm -install <host> <app>

# Available apps:
#   chrome | firefox | pdf24 | libreoffice | anydesk
```

Example:
```bash
wm -install WORKSTATION-04 chrome
```

The install process follows this pattern for every application:

```
1. Bash:        check_host → connectivity check
2. PowerShell:  Copy-Item  → copy installer from NAS to \\host\c$
3. PsExec:      msiexec /qn → silent install on remote host
4. PowerShell:  Remove-Item → cleanup installer from remote C:
5. Bash:        msg green  → confirm success
```

### Active Directory

```bash
wm -find-pc   <name>     # Search for a computer in AD (wildcard)
wm -find-user <name>     # Search for a user in AD (wildcard)
wm -os-count             # Count machines by OS version in the domain
```

### Messaging & Printers

```bash
wm -msg          <host> "Your message"    # Send message to user's screen
wm -printers     <host>                   # List installed printers
wm -del-printers <host>                   # Remove all physical printers
```

---

## Key Implementation Details

### Escaping strategy

The fundamental challenge when calling PowerShell from Bash is managing two different quoting and escaping systems simultaneously.

**Rule: use single quotes for PowerShell syntax, let Bash expand your variables.**

```bash
# Bash expands $2 (hostname) before PowerShell sees the string.
# Single quotes protect the UNC path backslashes from Bash interpretation.
"$POWERSHELL" Copy-Item \
    -Path "$NAS\Browsers\Chrome\chrome.msi" \
    -Destination '\\'$2'\c$\chrome.msi'

# Single-quoted -ScriptBlock: Bash does not touch the PowerShell code inside.
# The variable $2 is expanded by Bash before the string is passed.
"$POWERSHELL" Invoke-Command -ComputerName "$2" \
    '-ScriptBlock { Get-CimInstance Win32_OperatingSystem }'
```

**Passing PowerShell pipe operators through Bash:**

```bash
# The pipe character must be single-quoted so Bash doesn't intercept it.
"$POWERSHELL" Get-ADUser -Filter '*' '|' Select-Object Name, SamAccountName
```

### Connectivity-first pattern

Every operation that touches a remote host starts with a connectivity check. This prevents hanging calls and gives clear feedback:

```bash
check_host "$2"           # sets $status = "online" | "offline"
if [ "$status" = "online" ]; then
    # ... do the work
else
    offline_err "$2"      # prints colored error and returns
fi
```

### WinRM dependency

`Invoke-Command` requires WinRM running on the target. The pattern used here is to silently start it via PsExec before any session-based command, without requiring it to be pre-configured permanently:

```bash
"$PSEXEC" '\\'$2 net start winrm >/dev/null 2>/dev/null
"$POWERSHELL" Invoke-Command -ComputerName "$2" '-ScriptBlock { ... }'
```

### Extending with external scripts

The architecture naturally supports delegation to external scripts — both Bash and PowerShell — keeping the main file clean:

```bash
# Delegate to a Bash helper
/path/to/helper.sh "$2" "$3"

# Delegate to a PowerShell script, passing the hostname as argument
"$POWERSHELL" -ExecutionPolicy Unrestricted \
    -File '/path/to/script.ps1' "$2"
```

---

## Extending: adding a new install target

Adding a new application to `-install` takes about 8 lines:

```bash
myapp)
    msg yellow "[!] Installing MyApp on $2..."
    "$POWERSHELL" Copy-Item \
        -Path "$NAS\MyApp\myapp_installer.msi" \
        -Destination '\\'$2'\c$\myapp.msi' >/dev/null 2>/dev/null
    "$PSEXEC" '\\'$2 \
        'c:\Windows\System32\msiexec.exe /i c:\myapp.msi /qn' >/dev/null 2>/dev/null
    "$POWERSHELL" Remove-Item -Path '\\'$2'\c$\myapp.msi' -Force >/dev/null 2>/dev/null
    msg green "[✓] MyApp installed on $2."
    ;;
```

---

## Project Structure

```
wsl-manager/
├── wsl-manager.sh       # Main script
└── README.md
```

This demo is intentionally self-contained in a single file. Production deployments can split install routines, helper functions, and PowerShell scripts into subdirectories.

---

## Legal Notice

This tool is intended for use by authorized IT professionals administering machines they have explicit permission to manage. Always ensure your use complies with your organization's IT policies and applicable data protection laws.

---

## Author

**Dionisio Rohling** — Computer Engineer
Franca, SP — Brazil

> *"Bash is simple and powerful. PowerShell knows Windows. Together, they know everything."*

---

## License

MIT — free to use, adapt, and distribute.
