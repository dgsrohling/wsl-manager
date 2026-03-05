# wsl-manager

> **Remote Windows administration using Bash as the orchestrator and PowerShell as the execution engine — all from WSL.**
> by [Dionisio Rohling](https://github.com/drohling) — Computer Engineer

---

## Table of Contents

1. [The Problem with Traditional IT Administration](#the-problem-with-traditional-it-administration)
2. [Why Automation Matters](#why-automation-matters)
3. [The Case for Bash + PowerShell](#the-case-for-bash--powershell)
4. [The Paradigm](#the-paradigm)
5. [Why Not Just PowerShell?](#why-not-just-powershell)
6. [Why Not an RMM Tool?](#why-not-an-rmm-tool)
7. [Requirements](#requirements)
8. [Installation](#installation)
9. [Usage & Command Reference](#usage--command-reference)
10. [Key Implementation Details](#key-implementation-details)
11. [Extending the Tool](#extending-the-tool)
12. [Legal Notice](#legal-notice)

---

## The Problem with Traditional IT Administration

In any organization managing more than a handful of Windows machines, a technician's daily routine quickly becomes dominated by repetitive, manual tasks:

- Connecting to a remote host via RDP just to check who is logged on
- Opening the Windows GUI to verify disk space across twenty machines
- Manually copying an installer to a workstation, running it, then cleaning up
- Switching between tabs, tools, and consoles to accomplish a single workflow
- Doing the same thing on ten different machines because there is no way to script it from a central point

Each of these tasks is individually simple. Collectively, they consume enormous amounts of time and introduce human error. A technician clicking through GUIs is a technician not solving the problems that actually require human judgment.

The traditional answer has been GUI-based RMM (Remote Monitoring and Management) platforms, Active Directory Group Policy, or expensive enterprise tools. These are powerful — but they carry significant overhead: licensing costs, agent deployment, steep learning curves, and a layer of abstraction that often gets in the way when you need to do something specific and fast.

There is a simpler path.

---

## Why Automation Matters

Automation in IT administration is not just about saving time, though it does that dramatically. It is about three deeper principles:

### 1. Consistency

A human running a manual process will do it slightly differently each time. A script runs identically every time. When you roll out an application to fifty workstations, every machine gets the same flags, the same configuration, and the same cleanup — without exception.

### 2. Auditability

A script can log every action it takes — which host, which operation, at what time, with what result. Manual operations leave no trace. When something goes wrong a week later, a log tells you exactly what happened. A memory does not.

### 3. Scalability

A manual task that takes three minutes per machine takes five hours across one hundred machines. A scripted task that takes three minutes to write runs across one hundred machines in minutes. The investment in automation pays compound returns: every machine you add to your environment costs progressively less technician time.

This is why automation is not a luxury in modern IT — it is the foundation of a maintainable infrastructure.

---

## The Case for Bash + PowerShell

Windows and Linux have historically been administered in completely separate worlds. Windows administrators work in PowerShell or CMD. Linux administrators work in Bash. Tooling, knowledge, and workflows rarely crossed the boundary.

The **Windows Subsystem for Linux (WSL)** changed this. WSL runs a full Linux environment directly on Windows, with native interoperability between the two systems — including the ability to call Windows binaries directly from Bash.

This creates an unusual opportunity: you can use the best tool from each ecosystem for the job it does best, within a single script, running from a single terminal.

Most documentation about WSL interoperability focuses on calling Linux tools *from PowerShell* — importing `grep`, `awk`, or `sed` as wrappers. This project takes the **opposite approach**: Bash is the master, PowerShell is the specialist called when Windows-specific capability is needed.

This distinction matters. Here is why:

| Capability | Best tool | Why |
|---|---|---|
| Connectivity check | `ping` (Bash) | One-liner, universal, no dependencies |
| Argument parsing and flow control | Bash `case` | Terse, readable, battle-tested |
| User interaction (`select`, `read`) | Bash | Native, no boilerplate |
| Colored terminal output | ANSI + Bash | Zero dependencies |
| Text parsing and transformation | `sed`, `awk`, `grep` (Bash) | Unmatched for line-oriented data |
| Timestamped logging | `date` + Bash | Trivial to implement |
| Remote Windows session (WinRM) | PowerShell `Invoke-Command` | Native Windows remoting |
| Copy files to UNC paths (`\\host\c$`) | PowerShell `Copy-Item` | Handles Windows auth natively |
| Remote process execution | PsExec (via PowerShell) | Industry-standard remote exec |
| Active Directory queries | PowerShell `Get-ADUser`, etc. | Native AD integration |
| Windows service management | `net start/stop` via PsExec | Direct and reliable |
| Group Policy | PowerShell `Invoke-GPUpdate` | Only available in PS |

Neither shell excels at everything. Used together through WSL, they complement each other perfectly.

The result is a tool built from primitives that every sysadmin already knows — no frameworks, no agents, no licenses, no vendor lock-in. Just Bash logic driving PowerShell execution.

---

## The Paradigm

```
┌──────────────────────────────────────────────────────────────────┐
│                          WSL (Linux)                             │
│                                                                  │
│   wsl-manager.sh  ─────────►  powershell.exe  ────────►  Host   │
│          │                          │                    │       │
│    Bash orchestrates           PS executes           Windows     │
│    ─────────────────           ───────────           ───────     │
│    Connectivity check          WinRM sessions        Services    │
│    Argument parsing            Invoke-Command        Registry    │
│    Flow control                UNC file copy         AD objects  │
│    User interaction            PsExec calls          Processes   │
│    Logging & output            GPUpdate / DNS        Printers    │
│    Text processing             AD queries            Installers  │
└──────────────────────────────────────────────────────────────────┘
```

The script never talks directly to the remote machine. Bash decides *what* to do and *when* to do it. PowerShell and PsExec handle the actual Windows-level execution. This separation of concerns keeps each layer focused and easy to maintain.

---

## Why Not Just PowerShell?

PowerShell is an exceptional tool for Windows administration. It has rich object pipelines, deep AD integration, and native access to the .NET framework. For scripting Windows-specific tasks, it has no peer.

But pure PowerShell has friction for the orchestration layer:

- Verbose syntax for control flow and user interaction
- No `ping` one-liner; network checks require several lines
- ANSI color output requires extra work
- String manipulation is less intuitive than `sed`/`awk`
- Development iteration is slower for quick operational scripts

A PowerShell script that wraps all of this becomes long and hard to scan quickly. Bash keeps the top-level logic compact and readable — you can look at a `case` block and immediately understand every operation the tool supports.

---

## Why Not an RMM Tool?

Commercial RMM platforms (ConnectWise, NinjaRMM, Datto, etc.) are excellent for large, managed environments. They provide dashboards, alerting, patch management, and reporting at scale.

But they come with trade-offs:

- **Cost:** Per-endpoint licensing that grows with the environment
- **Agent dependency:** Every managed machine needs a running agent — another surface to maintain, update, and troubleshoot
- **Rigidity:** Built-in workflows cover common cases; anything custom requires their scripting environment or API
- **Latency:** GUI-based workflows are inherently slower than a CLI for one-off operations
- **Overkill:** For environments where you need targeted, fast, custom operations, a full RMM is often more overhead than it is worth

wsl-manager requires nothing on the target machines beyond what Windows already provides (WinRM, SMB, PsExec run once per session). The entire tool is a single shell script that a new technician can read and understand in twenty minutes.

---

## Requirements

| Component | Notes |
|---|---|
| WSL | Any Linux distro. Tested on Debian. |
| Windows PowerShell 5.1 | At `/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe` |
| PsExec64.exe | [Sysinternals](https://learn.microsoft.com/en-us/sysinternals/downloads/psexec) — place at `C:\Windows\System32\` |
| WinRM on targets | Enable with: `winrm quickconfig` on the target, or start it on-demand via PsExec (see below) |
| Network access | ICMP (ping) and SMB (port 445) must be reachable |
| Active Directory | Required only for `-find-pc`, `-find-user`, `-os-count` |

---

## Installation

```bash
git clone https://github.com/drohling/wsl-manager
cd wsl-manager
chmod +x wsl-manager.sh

# Optional: create an alias for convenience
echo "alias wm='bash ~/wsl-manager/wsl-manager.sh'" >> ~/.bashrc
source ~/.bashrc
```

Edit the paths at the top of `wsl-manager.sh` to match your environment:

```bash
POWERSHELL='/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'
PSEXEC='/mnt/c/Windows/System32/PsExec64.exe'
NAS='\\fileserver\Install'   # Your file server share for installers
```

---

## Usage & Command Reference

```bash
wm <option> <hostname> [args]
```

### Host Control

```bash
wm -ping  <host>        # Connectivity check with colored output
wm -off   <host>        # Shutdown remote host (prompts confirmation)
wm -rb    <host>        # Restart remote host (prompts confirmation)
wm -cmd   <host>        # Open interactive CMD on remote host via PsExec
```

### Information

```bash
wm -info  <host>        # OS name, architecture, build version
wm -who   <host>        # Currently logged-on user
wm -procs <host>        # Running processes
wm -progs <host>        # Installed programs (x64 + x86 registry)
wm -disks <host>        # Disk usage: used / free / total in GB
```

### Services

```bash
wm -svc-start <host> <service>    # Start a Windows service remotely
wm -svc-stop  <host> <service>    # Stop a Windows service (prompts confirmation)
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
```

Available applications:

| App | Package type | Silent flag |
|---|---|---|
| `chrome` | MSI | `/qn` |
| `firefox` | MSI | `/qn` |
| `pdf24` | MSI | `/qn` |
| `libreoffice` | MSI | `RebootYesNo=No /qn` |
| `anydesk` | EXE | `--silent` |

Example:
```bash
wm -install WORKSTATION-04 chrome
```

Every install follows this exact pattern:

```
1. check_host        → Bash pings the target before anything else
2. Copy-Item         → PowerShell copies the installer from NAS to \\host\c$
3. PsExec msiexec    → Silent remote install with no user interaction
4. Remove-Item       → PowerShell removes the installer from remote C:
5. msg green         → Bash confirms success in the terminal
```

### Active Directory

```bash
wm -find-pc   <name>    # Wildcard search for a computer in AD
wm -find-user <name>    # Wildcard search for a user in AD
wm -os-count            # Count all machines in domain grouped by OS version
```

### Messaging & Printers

```bash
wm -msg          <host> "Text"    # Send a pop-up message to the user's screen
wm -printers     <host>           # List installed printers
wm -del-printers <host>           # Remove all physical printers (keeps PDF/virtual)
```

---

## Key Implementation Details

### The escaping strategy

The central technical challenge of this paradigm is managing two quoting systems simultaneously. Bash has its own rules. PowerShell has its own rules. When Bash builds a string to pass to `powershell.exe`, both sets of rules apply at once.

The strategy is straightforward:

> **Use single quotes for PowerShell syntax. Let Bash expand your variables outside of them.**

```bash
# Bash expands $2 (the hostname) before PowerShell receives the string.
# Single quotes protect the UNC backslashes from Bash interpretation.
"$POWERSHELL" Copy-Item \
    -Path "$NAS\Browsers\Chrome\chrome.msi" \
    -Destination '\\'$2'\c$\chrome.msi'
```

Breaking down what Bash actually produces before PowerShell sees it:
```
Copy-Item -Path \\fileserver\Install\Browsers\Chrome\chrome.msi -Destination \\HOSTNAME\c$\chrome.msi
```

For PowerShell script blocks, single quotes prevent Bash from interpreting any PowerShell-specific syntax:

```bash
# Bash does not touch anything inside the single-quoted ScriptBlock.
# $2 is expanded by Bash before the whole string is passed to powershell.exe.
"$POWERSHELL" Invoke-Command -ComputerName "$2" \
    '-ScriptBlock { Get-CimInstance Win32_OperatingSystem | Select-Object Caption, OSArchitecture }'
```

For pipe operators, they must be single-quoted so Bash does not intercept them:

```bash
# Without the quotes, Bash would pipe powershell's stdout to Select-Object — which doesn't exist in Bash.
"$POWERSHELL" Get-ADUser -Filter '*' '|' Select-Object Name, SamAccountName
```

### Connectivity-first pattern

Every operation that touches a remote host begins with a connectivity check. This prevents hanging calls and gives immediate, clear feedback:

```bash
check_host "$2"               # sets $status = "online" | "offline"
if [ "$status" = "online" ]; then
    # perform the operation
else
    offline_err "$2"          # prints colored error, stops execution
fi
```

### On-demand WinRM

`Invoke-Command` requires WinRM to be running on the target. Rather than requiring it to be permanently enabled, the pattern used here starts it silently via PsExec immediately before each session call:

```bash
"$PSEXEC" '\\'$2 net start winrm >/dev/null 2>/dev/null
"$POWERSHELL" Invoke-Command -ComputerName "$2" '-ScriptBlock { ... }'
```

This works even on machines where WinRM is not configured to start automatically, which covers most standard workstation deployments.

### Delegating to external scripts

For complex operations that would make the main file unwieldy, the architecture naturally supports delegation — to both Bash helpers and PowerShell scripts:

```bash
# Delegate to a Bash helper script
/path/to/helper.sh "$2" "$3"

# Delegate to a PowerShell script, passing hostname as argument
"$POWERSHELL" -ExecutionPolicy Unrestricted -File '/path/to/script.ps1' "$2"
```

This keeps the main file as a clean command router, with complex logic living in focused, testable separate files.

---

## Extending the Tool

### Adding a new install target

Adding a new application to `-install` follows the same eight-line pattern every time:

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

### Adding a new command

Adding a new top-level command is a `case` entry:

```bash
-my-command)
    check_host "$2"
    if [ "$status" = "online" ]; then
        # your PowerShell or PsExec call here
        log "my-command executed on $2"
    else
        offline_err "$2"
    fi
    ;;
```

---

## Project Structure

```
wsl-manager/
├── wsl-manager.sh       # Main script — self-contained demo
└── README.md
```

This demo is intentionally a single file. A production deployment can grow into subdirectories for helper scripts, PS1 files, and data — without changing the paradigm.

---

## Legal Notice

This tool is intended for use by authorized IT professionals administering systems they have explicit permission to manage. Some operations — such as listing logged-on users, querying browsing history, or interacting with user sessions — involve personal data as defined by data protection regulations (including GDPR/LGPD). Ensure your use is covered by your organization's IT policy and applicable law before deployment.

---

## Author

**Dionisio Rohling** — Computer Engineer
Franca, SP — Brazil

> *"Bash is simple and powerful. PowerShell knows Windows. Together, they know everything."*

---

## License

MIT — free to use, adapt, and distribute.
