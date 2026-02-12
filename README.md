# Dynatrace OneAgent – Puppet Module

## Table of Contents

1. #overview  
2. #behavior--policy  
3. #setup  
   - #what-the-dynatrace-oneagent-affects  
   - #setup-requirements  
   - #beginning-with-dynatrace-oneagent-installation  
4. #usage  
   - #most-basic-oneagent-installation-using-a-saas-tenant  
   - #oneagent-installation-using-a-managed-tenant-with-a-specific-version  
   - #advanced-configuration  
   - #set-or-update-oneagent-configuration-and-host-metadata  
   - #update-oneagent-communication  
5. #how-it-works-under-the-hood  
6. #limitations  
7. #development--testing  
8. #references  
9. #migration-note

---

## Overview

This module downloads, installs, and minimally configures **Dynatrace OneAgent** on **Linux**, **Windows**, and **AIX**, and ensures the OneAgent service is running. It exposes parameters for install‑time options and select post‑install host settings via `oneagentctl`.

> **Design goal:** safe defaults and least surprise. The module avoids destructive actions and will not “unset” values when parameters are removed from Puppet.

---

## Behavior & Policy

**Source of truth rules:**

- **If you define a parameter in Puppet** → the module **sets it (one‑time)** by writing a small tracking file and notifying a corresponding `oneagentctl` exec. After convergence, the module does **not** continually force the value; UI changes are tolerated unless you update the param again in Puppet.
- **If you do not define a parameter in Puppet** → the module **leaves it unmanaged forever**; the **Dynatrace UI/tenant defaults** own it.

**Parameters covered by this policy:**

- `monitoring_mode` (`infra-only` | `fullstack` | `discovery`)
- `network_zone`
- `host_group`, `host_tags`, `host_metadata`, `hostname`
- `log_monitoring`, `log_access`
- `oneagent_communication_hash`

**Important safety change:**  
When a parameter is removed from Puppet, the module **no longer runs any “unset/clear” commands**. It simply removes its own tracking file and **does not** modify the agent.

---

## Setup

### What the Dynatrace OneAgent affects

- Installs the **Dynatrace OneAgent** package with the selected parameters and manages a small set of module tracking files under the OneAgent config path.
- Ensures the OneAgent **service** is enabled and running.
- **Note:** For **deep application instrumentation**, processes running **before** the initial install may need to be restarted (or you can schedule a reboot).

### Setup requirements

This module requires:

- [puppet/archive](https://forge.puppet.com/puppet/archive) – used to download the installer  
- [puppetlabs/reboot](https://forge.puppet.com/modules/puppetlabs/reboot) – optional; only required if you choose to reboot after install  
- (Windows uninstall workflows may use [puppetlabs/powershell](https://forge.puppet.com/modules/puppetlabs/powershell))

Install from Forge:

```bash
puppet module install deus-dynatraceoneagent
```

You must provide at least:

- **Tenant URL**  
  - SaaS: `https://{your-environment-id}.live.dynatrace.com`  
  - Managed: `https://{your-domain}/e/{your-environment-id}`
- **PaaS token** for downloading the OneAgent installer

For OS/platform specifics and available flags, refer to Dynatrace documentation (Deployment API, Supported OS, and `oneagentctl`). See **References**.

### Beginning with Dynatrace OneAgent (Installation)

Declare the class with mandatory options:

```puppet
class { 'dynatraceoneagent':
  tenant_url => 'https://{your-environment-id}.live.dynatrace.com',
  paas_token => '{your-paas-token}',
}
```

**On a fresh host, the module:**

1. **Downloads** the OneAgent installer (OS‑specific).  
2. **Installs** OneAgent with minimal defaults (always includes `--set-app-log-content-access=true`).  
3. **Applies** any explicitly defined post‑install settings (e.g., `monitoring_mode`, `network_zone`) **once** via `oneagentctl`.  
4. Ensures the OneAgent **service** is running.

**On subsequent runs:**

- The installer is **skipped** (idempotent guard).  
- Execs are **`refreshonly`**; they only run when you change a Puppet parameter (or the module’s tracking file changes).  
- Removing a parameter from Puppet leaves the value **as‑is** on the agent (unmanaged).

---

## Usage

### Most basic OneAgent installation using a SaaS tenant

```puppet
class { 'dynatraceoneagent':
  tenant_url => 'https://{env-id}.live.dynatrace.com',
  paas_token => '{your-paas-token}',
}
```

- **Monitoring mode:** Unmanaged unless you set `monitoring_mode`. The installer inherits the **tenant default** mode (commonly *Full‑Stack* unless admins change it in the Dynatrace UI).  
- **Network zone:** Unmanaged unless you set `network_zone`.

### OneAgent installation using a Managed tenant with a specific version

The `version` must follow the Dynatrace format (e.g., `1.181.63.20191105-161318`).

```puppet
class { 'dynatraceoneagent':
  tenant_url => 'https://{your-domain}/e/{env-id}',
  paas_token => '{your-paas-token}',
  version    => '1.181.63.20191105-161318',
}
```

#### Verify Installer Signature (Linux/AIX Only)

```puppet
class { 'dynatraceoneagent':
  tenant_url       => 'https://{env-id}.live.dynatrace.com',
  paas_token       => '{your-paas-token}',
  verify_signature => true,
}
```

### Advanced configuration

Download to a custom directory, pass additional OneAgent **install‑time** parameters, and request a reboot after install:

```puppet
class { 'dynatraceoneagent':
  tenant_url           => 'https://{env-id}.live.dynatrace.com',
  paas_token           => '{your-paas-token}',
  version              => '1.181.63.20191105-161318',
  download_dir         => '/var', # or 'C:\\Download Dir' on Windows
  reboot_system        => true,
  oneagent_params_hash => {
    '--set-app-log-content-access' => 'true',
    # Only include this if you explicitly want to override tenant default at *install time*:
    '--set-monitoring-mode'        => 'fullstack', # or 'infra-only' | 'discovery'
    # Windows example of MSI public property:
    # 'INSTALL_PATH'               => 'C:\\Dynatrace\\oneagent',
  },
}
```

> **Tip:** If you **don’t** pass `--set-monitoring-mode` at install, the **tenant default** applies. For post‑install enforcement, set `monitoring_mode` (below).

### Set or update OneAgent configuration and host metadata

These are **set once** when present. If later removed from Puppet, the module **does not** unset them.

```puppet
class { 'dynatraceoneagent':
  tenant_url      => 'https://{env-id}.live.dynatrace.com',
  paas_token      => '{your-paas-token}',

  monitoring_mode => 'infra-only',     # 'infra-only' | 'fullstack' | 'discovery' (unmanaged if omitted)
  network_zone    => 'sydneynp',       # unmanaged if omitted

  host_group      => 'LINUX_PROD',     # unmanaged if omitted
  host_tags       => ['Environment=Prod', 'Role=DB', 'App=Billing'],
  host_metadata   => ['Owner=ops@example.com', 'CostCentre=42'],
  hostname        => 'db01.prod.local',

  log_monitoring  => true,
  log_access      => false,
}
```

**Operational nuance:** With default wiring (`refreshonly`), UI changes are **not** automatically reverted unless you change the Puppet parameter again (or the tracking file changes). This prevents CM from “fighting” observability admins.

### Update OneAgent communication

Change OneAgent communication during or after installation:

```puppet
class { 'dynatraceoneagent':
  tenant_url                  => 'https://{env-id}.live.dynatrace.com',
  paas_token                  => '{your-paas-token}',
  oneagent_communication_hash => {
    '--set-server'       => 'https://activegate.example.com:443/communication',
    '--set-tenant'       => 'abc123456',
    '--set-tenant-token' => 'abcdef0123456789',
    '--set-proxy'        => 'http://proxy.example.com:9480',
  },
}
```

> Prefer install‑time parameters for settings that can be configured at install; reserve `oneagentctl` for post‑install changes where appropriate.

---

## How it works (under the hood)

- **Download:** Uses `puppet/archive` to fetch the OS‑specific installer into `download_dir`.  
- **Install (Linux/AIX):** Builds the shell command locally (`/bin/sh <installer> <params>`) and runs it with `cwd => download_dir`. A robust guard (`test -x /opt/dynatrace/oneagent/agent/tools/oneagentctl`) ensures idempotency.  
- **Install (Windows):** Uses a `package` resource with `provider => windows`, passing installer flags via `install_options`.  
- **Post‑install settings:** For each managed setting, the module writes a small file under `.../agent/config/puppet/*.conf`. Those files **notify** corresponding `oneagentctl` execs that include `--restart-service`. Execs are `refreshonly`; they run only when their file changes.  
- **Unmanaged on absence:** If a parameter is omitted in Puppet, the module sets `ensure => absent` on its tracking file and **does not** call any unset/clear command. The agent value remains whatever the UI/tenant default dictates.

---

## Limitations

- Ensure the **PaaS token** has permission to download OneAgent from your environment.
- Some Windows installer flags must be provided as **MSI public properties**; others must use `--set-param`. Check Dynatrace’s installer reference before adding Windows‑specific options.
- If you want **continuous enforcement** for a subset of settings (always revert UI changes), add `unless` guards that query `oneagentctl --get-...` and switch those execs to `refreshonly => false`. The default behavior favors **“set once; UI can override later.”**

---

## Development & Testing

- Acceptance tests use **puppet_litmus**. See: <https://github.com/puppetlabs/puppet_litmus>  
- A helper script is included: `./scripts/run_acc_tests.sh`.

When contributing, please include:

- A short **CHANGELOG** entry (what changed and why), and  
- README updates if your change affects behavior or parameters.

---

## References

- Dynatrace OneAgent: <https://www.dynatrace.com/support/help/setup-and-configuration/dynatrace-oneagent/>  
- Deployment API: <https://www.dynatrace.com/support/help/extend-dynatrace/dynatrace-api/environment-api/deployment/>  
- OneAgent CLI (`oneagentctl`): <https://www.dynatrace.com/support/help/setup-and-configuration/dynatrace-oneagent/oneagent-configuration-via-command-line-interface>  
- Supported operating systems: <https://www.dynatrace.com/support/help/technology-support/operating-systems/>

---

## Migration Note

Older revisions could **clear** Host Group/tags/metadata/hostname when you removed those parameters from Puppet. This has been **removed**. Now, removing a parameter simply makes it **unmanaged**, and the value is left as‑is on the agent (UI/tenant defaults remain authoritative).

