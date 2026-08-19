# JumpServer Interim Bastion Deployment

A scripted deployment of **JumpServer Community Edition** on a Debian container host.

> **Important:** This repository is intended to accelerate a controlled interim deployment.

## Why JumpServer?

The immediate requirement is to provide a controlled administrative access point supporting:

- SSH access to Linux and network infrastructure
- RDP access to Windows systems
- Browser-based access to privileged sessions
- Windows RemoteApp / application publishing
- Centralised authentication
- MFA
- Privileged credential isolation
- Session recording and audit
- Role-based access control

JumpServer is a useful stepping stone because its operating model is much closer to a PAM/bastion platform than a traditional standalone jump host.

It allows engineers to connect **through the bastion** instead of receiving direct network access and privileged credentials to managed systems.

The intended long-term destination remains **WALLIX Bastion**.

---

## High-Level Architecture

```text
                    Administrative Users
                            |
                     HTTPS / SSH access
                            |
                 +-----------------------+
                 |   JumpServer Bastion  |
                 |    Debian / Docker    |
                 +-----------------------+
                     |       |       |
                     |       |       |
                    SSH     RDP   RemoteApp
                     |       |       |
              +------+-------+-------+------+
              |      Managed Networks      |
              | Linux / Windows / Devices  |
              +-----------------------------+
```

For application publishing, a separate Windows Server application publisher is normally required:

```text
User Browser
     |
     v
+------------+
| JumpServer |
+------------+
     |
     | Managed RemoteApp session
     v
+-------------------------+
| Windows App Publisher   |
| Windows Server + RDS    |
| Legacy Java / Thick App |
+-------------------------+
     |
     v
Target Management Interface
```

The bastion should be treated as a **security boundary**, not simply another management VM.

---

## Repository Contents

Typical repository layout:

```text
.
├── README.md
└── deploy_jumpserver.sh
```

`deploy_jumpserver.sh` performs the initial Debian/container bootstrap and launches the official JumpServer installer.

---

## Supported Deployment Model

This script is designed for a **small interim deployment** using:

- Debian 11 or Debian 12
- x86-64 / amd64 server
- Docker Engine
- Docker Compose plugin
- JumpServer Community Edition
- Single-node deployment

For a new build, allocate at least:

| Resource | Minimum |
|---|---:|
| CPU | 4 vCPU |
| RAM | 8 GB |
| Architecture | 64-bit |
| Storage | 50 GB+ recommended |
| Network | Static IP recommended |

More storage should be allocated where session recordings will be retained locally.

---

## Before You Deploy

The server should ideally be a **clean, dedicated VM**.

Do not deploy JumpServer on:

- a general-purpose administration server;
- an application server;
- an Internet-facing server with unrelated services;
- a domain controller;
- a server hosting production workloads.

Recommended preparation:

1. Assign a static management IP.
2. Patch Debian fully.
3. Configure DNS and NTP.
4. Configure host and network firewalls.
5. Decide how administrators will reach the bastion.
6. Decide where audit/session logs will be retained.
7. Prepare a TLS certificate.
8. Identify the subnets and systems JumpServer is permitted to manage.

---

## Network Security Model

A secure interim deployment should follow this principle:

> **Administrators reach managed systems through JumpServer. Managed systems should not normally be directly reachable from administrator workstations.**

### Example Flow

```text
Admin Workstation
      |
      | HTTPS 443
      v
JumpServer
      |
      +---- TCP 22 ----> Linux / Network Devices
      |
      +---- TCP 3389 --> Windows Systems
      |
      +---- Required management protocols --> Application Publisher
```

Where possible, target-side firewall policy should explicitly restrict administration protocols to the JumpServer source address or bastion subnet.

Example:

```text
ALLOW  JumpServer_Subnet -> Linux_Admin_Subnet    TCP/22
ALLOW  JumpServer_Subnet -> Windows_Admin_Subnet  TCP/3389
DENY   User_Subnets       -> Linux_Admin_Subnet    TCP/22
DENY   User_Subnets       -> Windows_Admin_Subnet  TCP/3389
```

Use the actual firewall rules appropriate to your environment.

---

## Installation

### 1. Clone the Repository

```bash
git clone <YOUR-REPOSITORY-URL>
cd <YOUR-REPOSITORY>
```

### 2. Review the Script

Never execute infrastructure bootstrap scripts without first reviewing them.

```bash
less deploy_jumpserver.sh
```

The script:

1. Checks for root privileges.
2. Installs Debian dependencies.
3. Configures the official Docker APT repository.
4. Installs Docker Engine and the Docker Compose plugin.
5. Enables Docker.
6. Downloads the official JumpServer `quick_start.sh`.
7. Executes the JumpServer installer.

### 3. Make It Executable

```bash
chmod +x deploy_jumpserver.sh
```

### 4. Run It

```bash
sudo ./deploy_jumpserver.sh
```

The JumpServer installer may prompt for installation/configuration information depending on the current JumpServer release.

---

## First Login

After the containers have started, browse to:

```text
http://<JUMPSERVER-IP>/
```

The upstream JumpServer quick-start currently documents the initial credentials as:

```text
Username: admin
Password: ChangeMe
```

**Change the initial administrator password immediately.**

Do not expose the system beyond a controlled management network while the default credentials remain active.

---

## Mandatory Post-Installation Hardening

The installation completing successfully does **not** mean the bastion is ready for operational use.

Complete the following before onboarding administrators or production assets.

### 1. Change the Default Administrator Password

Do this immediately.

Use a long, unique password stored in an approved password manager.

---

### 2. Enable MFA

Require MFA for privileged users.

For an interim Community deployment, built-in MFA such as TOTP can be used.

Do not allow the bastion to become a single-password route into privileged infrastructure.

---

### 3. Deploy HTTPS

Do not operate the production portal over clear-text HTTP.

Install a trusted TLS certificate and force HTTPS.

JumpServer's `jmsctl` tooling includes SSL configuration support.

---

### 4. Restrict Network Exposure

Do **not** expose the JumpServer administrative portal directly to the public Internet unless this has been explicitly designed, hardened and approved.

Preferred interim pattern:

```text
Corporate / Engineering Device
          |
          v
 VPN / Controlled Access Network
          |
          v
      JumpServer
```

Restrict inbound access using firewall policy.

---

### 5. Restrict Target Systems

Configure managed assets so privileged administration protocols are accepted from the bastion rather than broadly from user networks.

This is one of the most important controls in the design.

Without this restriction, engineers may be able to bypass the bastion entirely.

---

### 6. Avoid Shared JumpServer Accounts

Every administrator should have an individually attributable account.

Avoid:

```text
admin-team
engineer
support
shared-admin
```

Prefer named identities mapped to centrally managed users where practical.

---

### 7. Configure LDAP / Active Directory

For a corporate deployment, integrate with the existing directory rather than maintaining a large standalone identity store.

Use secure LDAP/TLS where available.

Keep at least one tested local break-glass administrator account for directory outages.

---

### 8. Protect Managed Credentials

Where JumpServer manages target credentials:

- do not reveal passwords unnecessarily to engineers;
- restrict access to credential administration;
- rotate privileged credentials;
- avoid reusing the same privileged password across assets;
- document emergency retrieval procedures.

---

### 9. Enable Session Recording and Audit

Session recording is one of the principal reasons for deploying a PAM-style gateway.

Confirm that:

- SSH command activity is auditable;
- graphical sessions are recorded as required;
- login activity is logged;
- administrative changes are logged;
- retention meets organisational requirements.

---

### 10. Export Logs

Where possible, forward security and audit events to the organisation's central logging/SIEM platform.

Do not rely solely on logs stored inside the bastion VM.

The minimum useful event set normally includes:

- successful logins;
- failed logins;
- MFA events;
- account changes;
- asset changes;
- permission changes;
- privileged session start/stop;
- administrative changes.

---

### 11. Back Up the Platform

At minimum, protect:

- JumpServer configuration;
- database;
- encryption/secrets material;
- session recordings where required;
- TLS certificates;
- integration configuration.

JumpServer's management tooling provides database backup and restore functions, but those backups must still be copied to protected storage.

---

### 12. Patch Regularly

The fact that this is an interim platform makes patching **more**, not less, important.

Regularly patch:

- Debian;
- Docker;
- JumpServer;
- Windows RemoteApp publisher;
- browsers/clients;
- any legacy tools being published.

---

## JumpServer Management

The official installer provides `jmsctl.sh`.

The installer directory is normally located under `/opt`, with the exact path depending on the installed JumpServer version.

Locate it with:

```bash
find /opt -maxdepth 2 -name jmsctl.sh -type f
```

Change to the installer directory before running management commands.

### Status

```bash
./jmsctl.sh status
```

### Start

```bash
./jmsctl.sh start
```

### Stop

```bash
./jmsctl.sh stop
```

### Restart

```bash
./jmsctl.sh restart
```

### Logs

```bash
./jmsctl.sh tail
```

Or for a specific service:

```bash
./jmsctl.sh tail <service>
```

### Database Backup

```bash
./jmsctl.sh backup_db
```

### Help

```bash
./jmsctl.sh --help
```

---

## Application Publishing / Legacy Java Interfaces

One of the reasons JumpServer was selected for the interim design is the requirement to reach **legacy Java and other thick-client management interfaces**.

The preferred model is not to install arbitrary legacy applications directly onto the JumpServer Linux host.

Instead:

```text
Browser
   |
JumpServer
   |
RemoteApp
   |
Dedicated Windows Application Publisher
   |
Legacy Application / Java Runtime
   |
Managed Device
```

This provides an isolated execution environment for:

- old Java management consoles;
- vendor engineering applications;
- legacy browser-dependent tools;
- database clients;
- infrastructure management clients;
- vendor-specific thick applications.

### Windows Application Publisher

Current JumpServer documentation specifies a Windows application-publisher model and recommends Windows Server 2019 or later capability, with at least:

- 4 CPU cores;
- 8 GB RAM;
- WinRM or OpenSSH management connectivity;
- valid Windows Remote Desktop Services licensing.

The Windows host should be treated as another privileged infrastructure component.

It should **not** become a general desktop or shared utility server.

---

## Legacy Java Security

Legacy Java applications represent a significant security risk and should be deliberately isolated.

Recommended pattern:

```text
                       Internet
                          X
                          |
                   No direct access
                          |
                +--------------------+
                | Application Host   |
                | Legacy Java only   |
                +--------------------+
                     |          |
                  HTTPS       Mgmt Protocol
                     |          |
                     v          v
               Approved     Managed
               Vendor UI     Device
```

Recommended controls:

- dedicated VM;
- no email client;
- no general web browsing;
- no office suite;
- block Internet egress unless explicitly required;
- permit only required destination hosts and ports;
- use the minimum Java version compatible with the target application;
- remove unused Java/browser plugins;
- snapshot or back up before application changes;
- rebuild rather than allowing uncontrolled software accumulation.

This makes the application publisher closer to a **controlled compatibility appliance** than a normal Windows desktop.

---

## Example Security Zones

For an OT/CNI-style environment, a suitable model may be:

```text
Enterprise / Engineering Network
               |
        Controlled Firewall
               |
        Bastion / Access Zone
         +-------------+
         | JumpServer  |
         +-------------+
               |
          OT Firewall
               |
      Management / IDMZ Zone
               |
       Managed OT Systems
```

For stronger segmentation, place the bastion on a dedicated firewall interface / security zone rather than co-locating it with production management servers.

Access policy should be explicit in both directions.

---

## Recommended Initial Access Policy

For a quick deployment, start conservatively.

### Administrators

Allow only:

- authorised engineering/admin groups;
- individually assigned accounts;
- MFA-authenticated access.

### Assets

Onboard only systems that genuinely require immediate privileged access.

Do not import entire network ranges simply because they are reachable.

### Permissions

Grant:

```text
User / Group
     +
Asset / Asset Group
     +
Permitted Account
     +
Permitted Protocol
     +
Permitted Time / Policy
```

Use least privilege.

---

## Firewall Considerations

At minimum, document:

### Inbound to JumpServer

Potentially:

```text
TCP/443   HTTPS portal
TCP/2222  SSH proxy / terminal access if enabled and required
```

Actual ports depend on the deployed JumpServer configuration.

Do not blindly expose every container-published port through upstream firewalls.

### Outbound from JumpServer

Only allow the protocols required to administer known assets.

Examples:

```text
TCP/22     SSH
TCP/3389   RDP
TCP/443    HTTPS management interfaces
TCP/5985   WinRM HTTP if explicitly required
TCP/5986   WinRM HTTPS preferred
TCP/636    LDAPS
UDP/123    NTP
TCP/53
UDP/53     DNS
```

Additional application-specific ports should be explicitly documented and approved.

---

## Docker Security Notes

Running JumpServer in containers does not remove the need to secure the host.

Recommended host controls:

- dedicated VM;
- minimal Debian installation;
- SSH restricted to management networks;
- SSH keys preferred for Linux host administration;
- disable unused services;
- apply security updates;
- restrict membership of the `docker` group;
- monitor Docker daemon activity;
- ensure sufficient disk capacity for images, databases and logs.

Remember that membership of the Docker group is effectively root-equivalent on a standard Docker host.

---

## Script Security Considerations

The deployment script downloads upstream installation code from GitHub and executes it.

This is convenient for rapid deployment, but production environments should ideally improve software supply-chain control.

A stronger implementation would:

1. Pin a tested JumpServer release.
2. Download the release artifact.
3. Verify its checksum/signature where provided.
4. Store the approved installer internally.
5. deploy the approved version from a controlled repository.
6. test upgrades before production rollout.

For example, rather than permanently relying on:

```bash
https://github.com/jumpserver/jumpserver/releases/latest/download/quick_start.sh
```

a controlled deployment should eventually reference an explicitly approved JumpServer release.

The use of `latest` is intentional for this **quick-start script**, but is not ideal for a repeatable production build.

---

## Recommended Script Improvements

The supplied bootstrap script is deliberately simple.

The next revision should ideally add:

- Debian version validation;
- CPU/RAM/disk pre-flight checks;
- static JumpServer version pinning;
- checksum validation;
- configurable installation directory;
- configurable ports;
- automated TLS configuration;
- host firewall configuration;
- optional corporate CA installation;
- NTP validation;
- DNS validation;
- audit/SIEM integration;
- backup configuration;
- logging of deployment actions;
- non-interactive configuration where safely supported.

For infrastructure-as-code maturity, the logical evolution is:

```text
Terraform / VM Build
        |
        v
Cloud-init / Ansible
        |
        v
Hardened Debian
        |
        v
Docker + JumpServer
        |
        v
JumpServer API Configuration
```

---

## Community Edition Considerations

JumpServer Community Edition is GPLv3 open source and supports the core bastion/PAM use case.

However, Community and Enterprise capabilities differ.

Do not assume that every feature visible in JumpServer product literature is available in the Community edition.

In particular, some advanced identity, connector, HA, multi-organisation and enterprise integration features are associated with X-Pack / Enterprise components.

For the current interim use case, validate the exact Community feature set for:

- authentication;
- SSO;
- RemoteApp;
- RDP;
- audit;
- HA;
- ticket/JIT workflows;
- external log storage;
- enterprise directory integration.

before making any of them mandatory design dependencies.

---

## Single-Node Risk

This deployment is intentionally simple.

A single JumpServer node introduces a potential availability dependency:

```text
JumpServer unavailable
        =
Privileged access path unavailable
```

That may be acceptable for a temporary deployment, but the operational team should explicitly decide what happens during failure.

Possible controls include:

- VM-level backup/restore;
- tested database backup;
- configuration backup;
- emergency break-glass procedure;
- controlled direct access available only during declared incidents.

Do not quietly leave unrestricted direct SSH/RDP access enabled "just in case", as this undermines the entire bastion model.

---

## Break-Glass Access

Document a formal emergency route.

For example:

```text
Normal:
Engineer -> JumpServer -> Asset

Emergency:
Named senior engineer
      ->
Incident approval
      ->
Restricted management workstation
      ->
Specific asset
```

Break-glass activity should be:

- exceptional;
- attributable;
- logged;
- reviewed afterwards;
- technically restricted where possible.

---

## Acceptance Checklist

Before considering the interim bastion operational:

- [ ] Debian fully patched
- [ ] Static IP configured
- [ ] DNS working
- [ ] NTP working
- [ ] Docker installed from approved repository
- [ ] JumpServer installed successfully
- [ ] Default admin password changed
- [ ] MFA enabled
- [ ] HTTPS enabled
- [ ] Firewall restrictions applied
- [ ] Administrator accounts individually assigned
- [ ] LDAP/AD configured if required
- [ ] Break-glass account configured and tested
- [ ] Target assets restrict administrative access to bastion
- [ ] SSH tested
- [ ] RDP tested
- [ ] RemoteApp tested
- [ ] Session recording verified
- [ ] Audit logs verified
- [ ] SIEM forwarding configured where required
- [ ] Backup taken
- [ ] Restore process documented
- [ ] Application publisher hardened
- [ ] Legacy Java environment isolated
- [ ] Operational owner identified
- [ ] Upgrade/patch owner identified
- [ ] WALLIX migration assumptions documented

---

## Migration to WALLIX

This environment should be designed so that migrating to WALLIX later is predominantly a **gateway replacement**, not another network redesign.

Good interim decisions therefore include:

- route privileged access through a defined bastion security zone;
- restrict target firewalls to the bastion zone;
- use named users;
- centralise identity;
- adopt MFA;
- use vaulted or brokered credentials;
- record sessions;
- define asset groups;
- formalise access policies;
- centralise audit events.

Conceptually:

```text
Today

Users
  |
JumpServer
  |
Managed Assets


Future

Users
  |
WALLIX Bastion
  |
Managed Assets
```

The security operating model should remain broadly consistent while the interim technology is replaced.

---

## Operational Principle

The objective of this project is **not simply to install a jump server**.

The objective is to establish the following privileged-access pattern as quickly as practical:

```text
IDENTIFY
   |
AUTHENTICATE + MFA
   |
AUTHORISE
   |
BROKER ACCESS
   |
HIDE / CONTROL CREDENTIAL
   |
RECORD SESSION
   |
AUDIT
```

If direct administrator-to-asset access remains the normal path, the bastion has not achieved its primary security purpose.

---

## Useful Upstream Documentation

JumpServer project:

https://github.com/jumpserver/jumpserver

JumpServer documentation:

https://docs.jumpserver.org/

JumpServer installer:

https://github.com/jumpserver/installer

Official Docker installation documentation:

https://docs.docker.com/engine/install/debian/

---

## Disclaimer

This repository provides an implementation starting point and should be adapted to the organisation's security architecture, firewall policy, identity design, logging requirements, vulnerability-management process and operational procedures.

For CNI, OT or other regulated environments, deployment should be reviewed against the organisation's applicable security requirements, including relevant NCSC CAF, NIS/NIS2-derived obligations, IEC 62443 principles and internal privileged-access standards.
