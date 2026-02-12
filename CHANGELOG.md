# Changelog

All notable changes to this project will be documented in this file.
## Release 1.12.0

### Features

- **Safe “unmanaged on absence” policy**
  - Removing parameters from Puppet **no longer clears Dynatrace values** for Host Group, tags, metadata, hostname, network zone, or monitoring mode.
  - When a parameter is omitted, the module only removes its *tracking file* and leaves the agent setting as‑is (Dynatrace UI/tenant defaults remain the source of truth).  

- **Explicit, opt‑in monitoring mode**
  - `monitoring_mode` now defaults to `undef`. If you **set** it (`infra-only` | `fullstack` | `discovery`), the module **sets it once** post‑install; if you **omit** it, the installer inherits the **tenant default** mode and Puppet stays hands‑off thereafter.

- **Documentation refresh**
  - Rewrote README with clear policy (“define → set once; omit → unmanaged”), quick start, advanced usage, and operational notes.

### Changes

- **Fresh-install refactor**
  - Build the installer command **locally in `install.pp`** and run with `cwd => download_dir` and a robust guard:
    ```puppet
    unless => "test -x /opt/dynatrace/oneagent/agent/tools/oneagentctl"
    ```
    This ensures the installer executes only when OneAgent is truly absent and resolves prior evaluation issues when referencing variables across classes.

- **Removed destructive execs**
  - Deleted all `unset_*` exec resources and their `notify` links. The module no longer issues `oneagentctl` “clear” calls when parameters are absent.

- **Parameter typing & scope clean-up**
  - `monitoring_mode` → `Optional[Enum['infra-only','fullstack','discovery']]`.
  - `host_tags` / `host_metadata` → `Array[String]` (defaults `[]`).
  - `oneagent_communication_hash` → `Hash[String, String]` (default `{}`).
  - Defined `$oneagent_tools_dir` in `init.pp` class body for clean cross‑class use.

### Bugfixes

- **Install-time “Could not evaluate” on fresh nodes**
  - Resolved by avoiding undefined cross-class locals (`$dynatraceoneagent::command`) and constructing the command inside `install.pp`.
  - Ensured `path => ['/bin','/usr/bin','/sbin','/usr/sbin']` so `/bin/sh` is always found.

### Upgrade Notes

- **Behavioral change (safer defaults):** If your workflow relied on Puppet **clearing** Host Group/tags/metadata/hostname/network zone when you removed parameters, you must now clear them **explicitly** via Dynatrace UI or by adding your own opt‑in purge switches.
- **Monitoring mode:** Leaving `monitoring_mode` unset means Puppet will not enforce it; Dynatrace admins can change it in the UI and it will stick. Set it in PE only when you want Puppet to set it (one-time).
- **No continuous enforcement by default:** Post‑install execs are `refreshonly`. If you want Puppet to **continuously** re-enforce certain values, add `unless` guards that read from `oneagentctl --get-*` and set `refreshonly => false` for those specific execs.

## Release 1.11.0

### Features

- None added in this release.

### Bugfixes

- ### Fix repeated OneAgent reinstall due to deprecated `agent.state` guard

  - The module previously relied on the presence of the file `${install_dir}/agent/agent.state` as the `creates` attribute of the `Exec['install_oneagent']` resource.
  - Recent Dynatrace OneAgent versions and console‑pushed auto‑updates no longer create or preserve this file, causing Puppet to believe the agent was not installed and re-run the installer on every agent converge.
  - This resulted in repeated `(corrective)` executions of the install script and unnecessary restarts of the OneAgent service.

  **Key Change:**
  - The idempotency guard for `Exec['install_oneagent']` has been updated to use a presence check on the OneAgent control binary:
    ```
    unless => "${oneagent_tools_dir}/${oneagent_ctl} --version >/dev/null 2>&1"
    ```
  - This ensures the installer only runs when the OneAgent binary is missing or non-functional, preventing reinstall loops after auto-updates.

  **Result:**
  - The installer now behaves correctly and idempotently across all supported versions.
  - OneAgent service restarts no longer occur on every Puppet run.

- ### Prevent compile error and remove stale `created_dir` references in `download.pp`

  - Removed the unused `$created_dir` variable from `dynatraceoneagent::download`.
  - Removed `creates => $created_dir` from the `archive { $filename: ... }` resource (not required for idempotency when `ensure => present` and `extract => false` are used).
  - Fixed an interpolation bug in the cleanup `exec` (`rm ${$download_path} ...` → `rm ${download_path} ...`), which could previously fail to parse.

  **Result:**
  - The catalog no longer errors with `Unknown variable: 'dynatraceoneagent::created_dir'`.
  - Download logic remains idempotent and stable without relying on the deprecated `agent.state` marker.

- ### Align `uninstall.pp` guard with stable OneAgent presence

  - Replaced the `onlyif` test that referenced the deprecated `${install_dir}/agent/agent.state` with a presence check on `oneagentctl` under `${install_dir}/agent/tools/`.
  - This mirrors the install guard approach and ensures uninstall only runs when OneAgent is actually present.

  **Result:**
  - Uninstall behavior is now consistent across versions and no longer depends on internal state files that may not exist after auto-updates.

### Known Issues

- None reported

## Release 1.10.0

## Features

 - Replaced deprecated infra_only parameter with new monitoring_mode enum (infra-only, fullstack, discovery) to support enhanced agent installation modes.
 - Updated default behavior to monitoring_mode = 'fullstack' to maintain compatibility with previous releases.
 - Configuration logic now uses monitoring_mode to manage agent mode settings and associated config files.

## Bugfixes

 - ### Updating `init.pp` for Dynamic Monitoring Mode Support

 - We refactored the Puppet module's `init.pp` to improve how the `monitoring_mode` parameter is handled for Dynatrace OneAgent installations. 
 - Previously, the install parameters hash (`oneagent_params_hash  - `) was generated in `params.pp` using a static value, which prevented external overrides (such as from the PE console or Hiera).

 - **Key changes:**
 - The `monitoring_mode` parameter is now settable from the PE console, Hiera, or directly in the class declaration.
 - Construction of `oneagent_params_hash` was moved into the `init.pp` class body. This ensures the hash uses the effective value of `monitoring_mode` passed into the class, rather than always defaulting to the value in `params.pp`.
 - This refactor allows dynamic selection of agent monitoring mode (e.g., `infra-only`, `fullstack`, or `discovery`) at deployment time, making the module more flexible and robust for various environments
 - **Result:**  
 - The module now correctly applies the desired monitoring mode based on the value provided at classification, not just the default. 
 - This pattern is recommended for all parameters that may be externally overridden.

## Known Issues

 - None reported

## Release 1.9.0

### Features

 - Provide option to disable puppet from managing the OneAgent service using the `manage_service` parameter
 - Dynatrace root cert file is now directly passed with module instead of requiring archive for download

### Bugfixes

TBD

### Known Issues

TBD

## Release 1.9.0

### Features

 - Provide option to disable puppet from managing the OneAgent service using the `manage_service` parameter
 - Dynatrace root cert file is now directly passed with module instead of requiring archive for download

### Bugfixes

TBD

### Known Issues

TBD

## Release 1.8.0

### Features

 - Simplified conditions by setting conditions on class containment on init.pp
 - Move uninstall tasks to new `dynatraceoneagent::uninstall` class.

### Bugfixes

 - Dynatrace OneAgent Windows uninstalls now executed via PowerShell

### Known Issues

TBD

## Release 1.7.0

### Features

 - Add download_options parameter on Archive resource in case custom flags are needed for curl/wget/s3 when downloading the OneAgent installer

### Bugfixes

 - Added `--restart-service` parameter to `oneagentctl --set-network-zone` command

### Known Issues

TBD

## Release 1.6.0

### Features

 - Use shell (`/bin/sh`) to run OneAgent install script on Linux and AIX systems
 - Remove resource `file{ $download_path:}` as it is not needed anymore with the addition of shell to the install OneAgent command

### Bugfixes

 - Fixed if statements with missing or with wrong conditions that checked for the AIX/Linux Operating System from the host facts.

### Known Issues

TBD

## Release 1.5.0

### Features

 - Add oneagentctl support
 - Add option to verify OneAgent Linux/AIX installer file signature
 - OneAgent service state can now be set using the `service_state` parameter
 - OneAgent package state can now be set using the `package_state` parameter
 - Use `reboot` module for both linux and windows reboots
 - Convert `host_metadata` string parameter to array
 - Convert `host_tags` string parameter to array
 - Following best practice, OneAgent metadata including host tags, host metadata and hostname is now set via `oneagentclt` instead of configuration files.
 - Add `download` class to separately handle OneAgent binary download
 - Add windows fact `dynatrace_oneagent_appdata`
 - Add windows fact `dynatrace_oneagent_programfiles`
- Add acceptance tests using the Litmus test framework

### Bugfixes

 - Remove `ensure => present` from `file{ $download_path:}` resource to ensure no file is present if OneAgent installer download fails.
 - data/common.yaml file now has valid yaml

### Known Issues

TBD

## Release 1.4.0

### Features

TBD

### Bugfixes

- Make proxy_server param optional

### Known Issues

TBD

## Release 1.3.0

### Features

TBD

### Bugfixes

- Add proxy_server var to init.pp

### Known Issues

TBD

## Release 1.2.0

### Features

- Add proxy server resource for archive module

### Bugfixes

TBD

### Known Issues

TBD

## Release 1.1.0

### Features

TBD

### Bugfixes

- Fix config directory dependency issue by installing OneAgent package in install.pp

### Known Issues

TBD

## Release 1.0.0

### Features

- Ability to set string values to the hostcustomproperties.conf and hostautotag.conf of the OneAgent config to add tags and metadata to a host entity.
- Ability to override the automatically detected hostname by setting the values of the hostname.conf file and restarting the Dynatrace OneAgent service.

### Bugfixes

- Remove debug message for whenever reboot parameter was set to false

### Known Issues

TBD

## Release 0.5.0

### Features

- Ability to download specific version
- Module will automatically detect OS and download required installer
- Module will automatically detect OS and will run the installer package required
- Add AIX support
- Add support for OneAgent Install Params
- Implement Archive module for OneAgent installer downloads
- Reboot functionality included
- Module built and validated with PDK

### Bugfixes

- Fix OneAgent download issue
- Fix module directory issue

### Known Issues

TBD
