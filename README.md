# MANAGE+ 

> **Shell + PowerShell hybrid system for remote Windows administration via WSL**  
> by [Dionisio Rohling](https://github.com/drohling) — Computer Engineer

---

## What is MANAGE+?

MANAGE+ is a command-line tool for IT administrators that uses **Bash as an orchestrator** to remotely manage Windows machines through PowerShell, PsExec, and WinRM — all from inside WSL (Windows Subsystem for Linux).

It was designed for real-world corporate environments where a technician needs to perform dozens of different operations on remote Windows hosts — from software installation to user profile removal — without leaving the terminal.

---

## The Paradigm

Most tools that combine Bash and PowerShell run Linux commands *from inside PowerShell*. MANAGE+ does the opposite:

```
┌─────────────────────────────────────────────────────────────┐
│                         WSL (Debian)                        │
│                                                             │
│   manage_plus.sh  ──────►  powershell.exe  ──────►  Host   │
│        │                        │                   │       │
│     Bash logic             PS commands          Windows     │
│     Ping checks            PsExec calls         WinRM       │
│     Color output           AD queries           Registry    │
│     CSV parsing            File copy            Services    │
└─────────────────────────────────────────────────────────────┘
```

**Bash handles:** control flow, connectivity checks, user interaction, logging, color output, CSV lookups, argument parsing.

**PowerShell handles:** anything that requires a Windows context — AD, GPO, WinRM, remote sessions, file operations on UNC paths, and process execution via PsExec.

This combination gives you the simplicity and power of shell scripting with full access to the Windows ecosystem — without writing a single line of C#, without an RMM agent, and without a GUI.

---

## Requirements

| Requirement | Notes |
|---|---|
| WSL (Windows Subsystem for Linux) | Tested on Debian |
| Windows PowerShell 5.1 | At `/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe` |
| PowerShell 7+ (optional) | For extended commands |
| PsExec64.exe | From Sysinternals, placed at `C:\Windows\System32\` |
| WinRM enabled on remote hosts | Required for `Invoke-Command` operations |
| Network access to target hosts | ICMP ping must be allowed |
| Active Directory environment | Required for AD-specific commands |

---

## Installation

```bash
# Clone the repository
git clone https://github.com/drohling/manage-plus
cd manage-plus

# Make executable
chmod +x manage_plus.sh

# Optional: create an alias
echo "alias mp='bash ~/manage-plus/manage_plus.sh'" >> ~/.bashrc
source ~/.bashrc
```

> The `.pmm/` directory must be present alongside the script, containing helper scripts, PowerShell files, and data files. See [Directory Structure](#directory-structure).

---

## Usage

```bash
mp <option> <hostname> [extra args]
```

If called without arguments, MANAGE+ displays the help file located at `.pmm/ajuda_manage+`.

---

## Command Reference

### Host Management

| Command | Description |
|---|---|
| `mp -d <host>` | Shut down a remote host |
| `mp -r <host>` | Restart a remote host |
| `mp -t <host>` | Open a remote CMD terminal via PsExec |
| `mp -gp <host>` | Force `Invoke-GPUpdate` on remote host |
| `mp -ps <host>` | Start WinRM service on remote host |
| `mp -dns <host>` | Register DNS and run GPUpdate remotely |
| `mp -sfc <host>` | Run `sfc /scannow` remotely |
| `mp -time <host>` | Sync time on remote host |

### Verification & Info

| Command | Description |
|---|---|
| `mp -vc <host>` | Full computer check (patrimony + connectivity + logged user) |
| `mp -vi <host>` | Printer device check |
| `mp -p <host>` | Patrimony lookup from local CSV |
| `mp -inf <host>` | OS information, .NET version, logged user |
| `mp -vd <host>` | Disk usage on remote host |
| `mp -vdr <host>` | Driver verification |
| `mp -usb <host>` | USB device listing |
| `mp -ts <host>` | List running tasks |
| `mp -us <host>` | List user profiles folder |
| `mp -lp <host>` | List installed programs (x64 + x86) |
| `mp -hp <host>` | List installed printers |
| `mp -vs <host>` | View DNS cache / visited sites |
| `mp -vhi <host> <user>` | Chrome browsing history via SQLite |
| `mp -vu <host>` | List installed Windows updates |
| `mp -vmc <host>` | Printer MAC addresses via SNMP |
| `mp -tp <host>` | Show active user session |

### User & Profile Operations

| Command | Description |
|---|---|
| `mp -rp <host> <user>` | Remove user profile |
| `mp -cpw <user> <host> <pass>` | Change user password |
| `mp -ua [filter]` | List recently added AD users |
| `mp -ul [filter]` | List users in domain |
| `mp -gu <name>` | Find user in Active Directory |
| `mp -el <opt> <host>` | Send LAPS password |

### Printer Operations

| Command | Description |
|---|---|
| `mp -ri <host>` | Remove all printers from host |
| `mp -lsp <host>` | Clear print spooler |
| `mp -pp <host> ...` | Add printer port |

### Remote Software Installation

| Command | Description | Source |
|---|---|---|
| `mp -ofi <host>` | Microsoft Office 365 | NAS share |
| `mp -gci <host>` | Google Chrome | NAS share |
| `mp -gdi <host>` | Google Drive | NAS share |
| `mp -gei <host>` | Google Earth Pro | NAS share |
| `mp -adi <host>` | AnyDesk | Local |
| `mp -pdf <host>` | PDF24 | NAS share |
| `mp -ism <host>` | PDFSam 5.2.6 | NAS share |
| `mp -qgi <host>` | QGIS 3.28 | NAS share |
| `mp -sci <host>` | HP Universal Scanner | NAS share |
| `mp -jvi <host>` | Java (latest) | NAS share |
| `mp -jvl <host>` | Java v8u441 (legacy) | NAS share |
| `mp -ori <host>` | Oracle Instant Client + Elotech shortcut | NAS share |
| `mp -pbi <host>` | Power BI Desktop | NAS share |
| `mp -spi <host>` | Assinador SERPRO | NAS share |
| `mp -ffi <host>` | Mozilla Firefox | NAS share |
| `mp -its <host>` | TS Sisreg | NAS share |
| `mp -ifi <host>` | Irfan View | NAS share |
| `mp -loi <host>` | LogMeIn Client | NAS share |
| `mp -mci <host>` | Warsal bank module (GBPCef) | Local |
| `mp -aut <opt> <host>` | Autodesk | — |
| `mp -ipa <host>` | Interactive install via user session (PsExec -i) | — |
| `mp -isen <host>` | Senior ERP installer via user session | — |
| `mp -ipg <host> ...` | Generic program installer | — |

### Senior ERP Operations

| Command | Description |
|---|---|
| `mp -ups <host>` | Update Senior folder from NAS |
| `mp -rse <host>` | Remove Senior folder and shortcuts |
| `mp -smi <host>` | Replace midas.dll (Elotech fix) |
| `mp -se <host> ...` | Send Elotech configuration |

### UltraVNC Operations

| Command | Description |
|---|---|
| `mp -uvnc <host>` | Interactive UVNC install/uninstall menu |
| `mp -ivn <host>` | Install UVNC (normal) |
| `mp -ivs <host>` | Install UVNC (silent) |
| `mp -ivss <host>` | Install UVNC (alternative silent) |
| `mp -svn <host>` | Start UVNC service |
| `mp -rvl <host>` | Stop UVNC service and remove logs |
| `mp -dvn <host>` | Uninstall UVNC completely |

### Network & AD

| Command | Description |
|---|---|
| `mp -ip <host> ...` | iPerf2 connection test |
| `mp -id <ip>` | Check if IP is reserved in DNS |
| `mp -vm <host>` | Check MAC address |
| `mp -wf <host> ...` | View WiFi networks |
| `mp -l <host>` | Locate computer in AD |
| `mp -rc <host>` | Remove computer from AD |
| `mp -ic [filter]` | List inactive computers |
| `mp -qm` | Count machines by OS in domain |
| `mp -md` | List disabled AD objects |

### Misc

| Command | Description |
|---|---|
| `mp -msg <host>` | Send message to user |
| `mp -msp <host>` | Send pre-defined message |
| `mp -nv <host>` | View network shares |
| `mp -sh <host> ...` | Send shortcut via share |
| `mp -eas <host> ...` | Send shortcuts via PS script |
| `mp -gd <host>` | Remote device manager |
| `mp -os <num> <arg>` | Query service order (OS) |
| `mp -lo <host>` | Send LogMeIn remote support link |
| `mp -pk <host> <process>` | Kill remote process |

---

## How Remote Installation Works

Every remote installation follows the same pattern:

```bash
# 1. Check host connectivity
verifica_conexao $HOST

# 2. Copy installer from NAS to remote C:
$powershell Copy-Item -Path '\\nas\Install\...' -Destination '\\HOST\c$\installer.msi'

# 3. Notify the user
$powershell msg /server:$HOST '*' "Installation in progress..."

# 4. Execute silently via PsExec
$powershell psexec '\\HOST' 'msiexec.exe /i c:\installer.msi /qn'

# 5. Cleanup via PS1 script
$powershell -executionpolicy unrestricted -file '...\cleanup.ps1' $HOST

# 6. Confirm
echo "[OK] Installation complete."
```

The PowerShell calls are escaped so the Bash variables (`$HOST`) are expanded by the shell *before* being passed to `powershell.exe`, while PowerShell-internal variables and strings (like `'\\HOST\c$'`) are preserved with single quotes.

---

## Key Design Decisions

### Why Bash as the controller?

- Native string manipulation (`sed`, `awk`, `grep`) for parsing CSV patrimony data
- Simple and readable control flow (`case`, `select`, `if`)
- Color terminal output with ANSI escape codes
- Quick connectivity checks with `ping`
- Easy to extend with small helper scripts in `.pmm/`

### Why not pure PowerShell?

PowerShell handles Windows objects extremely well but is verbose for flow control, interaction, and text processing. Bash keeps the orchestration layer clean and readable.

### Escaping strategy

When PowerShell needs to receive a path with backslashes:

```bash
# Single quotes preserve backslashes for PowerShell
$powershell psexec '\\'$HOST 'net start spooler'

# Double-escaped for UNC paths passed through psexec
$psexec '\\'$HOST reg query "HKLM\SOFTWARE\..."
```

When Bash variables must expand inside PowerShell arguments:

```bash
# Bash expands $HOST before PowerShell sees the string
$powershell Copy-Item -Path '\\nas\file.exe' -Destination '\\'$HOST'\c$\file.exe'
```

---

## Directory Structure

```
manage-plus/
├── manage_plus.sh          # Main script
├── README.md
└── .pmm/                   # Support directory
    ├── ajuda_manage+        # Help text file
    ├── user_ativo.sh        # Active user detection
    ├── files/
    │   ├── data/
    │   │   └── patrimonios.csv      # Asset inventory CSV
    │   ├── PShell/                  # PowerShell scripts
    │   └── python_scripts/          # Python helpers
    ├── shell_scripts/               # PS1 cleanup/install helpers
    │   ├── antivirus.ps1
    │   ├── anydesk.ps1
    │   ├── googledrive.ps1
    │   ├── office365.ps1
    │   └── ...
    └── sql/                         # SQLite temp files
```

---

## Built-in Functions

```bash
verifica_conexao <host>    # Sets $act = "online" | "offline"
test_ping <host>           # Ping with colored output
mensagem_colorida <cor> <msg>  # Prints colored message
usuario_ativo <host>       # Returns currently logged user
log_event <message>        # Appends timestamped entry to manageplus.log
perguntarUsuario           # Interactive y/n prompt for UI installs
```

---

## Logging

Events are written to `manageplus.log` in the working directory:

```
2025-01-15 14:32:01 - Installation started on HOST01
```

---

## Supported Environments

| Component | Version |
|---|---|
| WSL Distribution | Debian GNU/Linux |
| Windows Target | Windows 10 / Windows 11 / Windows Server 2016+ |
| PowerShell | 5.1 (primary), 7.x (optional) |
| PsExec | 64-bit (PsExec64.exe) |
| Python | 3.x (for auxiliary scripts) |

---

## Author

**Dionisio Rohling** — Computer Engineer  
Designed and built for real-world IT administration in an Active Directory corporate environment.

> *"Shell scripting is simple and powerful. PowerShell knows Windows. Together, they know everything."*

---

## License

MIT License — feel free to adapt for your own environment.
