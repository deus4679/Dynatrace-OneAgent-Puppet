# @summary
#   This class manages the installation of the OneAgent on the host
#
class dynatraceoneagent::install {
  $download_dir             = $dynatraceoneagent::download_dir
  $filename                 = $dynatraceoneagent::filename
  $download_path            = $dynatraceoneagent::download_path
  $provider                 = $dynatraceoneagent::provider
  $oneagent_params_hash     = $dynatraceoneagent::oneagent_params_hash
  $reboot_system            = $dynatraceoneagent::reboot_system
  $service_name             = $dynatraceoneagent::service_name
  $package_state            = $dynatraceoneagent::package_state
  #$oneagent_puppet_conf_dir = $dynatraceoneagent::oneagent_puppet_conf_dir
  #$oneagent_tools_dir       = $dynatraceoneagent::oneagent_tools_dir
  $oneagent_ctl             = $dynatraceoneagent::oneagent_ctl

  # ---------- Linux / AIX ----------
  if ($facts['kernel'] == 'Linux' or $facts['os']['family'] == 'AIX') {

    # Build args locally from the hash already available
    $oneagent_params_array = $oneagent_params_hash.map |$k,$v| { "${k}=${v}" }
    $oneagent_unix_params  = $oneagent_params_array.empty ? {
      true    => '',
      default => " ${join($oneagent_params_array, ' ')}",
    }

    # Build the full install command locally
    $install_cmd = "/bin/sh ${download_path}${oneagent_unix_params}"

    exec { 'install_oneagent':
      command   => $install_cmd,
      cwd       => $download_dir,                    # e.g. /var or /tmp; exists pre‑install
      path      => ['/bin','/usr/bin','/sbin','/usr/sbin'],
      timeout   => 6000,
      # Robust guard: only run if agent tools are not present yet
      unless    => "test -x /opt/dynatrace/oneagent/agent/tools/${oneagent_ctl}",
      provider  => $provider,                        # 'shell'
      logoutput => on_failure,
      tries     => 2,
      try_sleep => 5,
    }
  }  # <-- close Linux/AIX block BEFORE Windows

  # ---------- Windows ----------
  if ($facts['os']['family'] == 'Windows') {
    package { $service_name:
      ensure          => $package_state,
      provider        => $provider,
      source          => $download_path,
      install_options => [$oneagent_params_hash, '--quiet'],
    }
  }

  # ---------- Optional reboot handling ----------
  if $reboot_system and $facts['os']['family'] == 'Windows' {
    reboot { 'after':
      subscribe => Package[$service_name],
    }
  } elsif ($facts['kernel'] == 'Linux' or $facts['os']['family'] == 'AIX') and $reboot_system {
    reboot { 'after':
      subscribe => Exec['install_oneagent'],
    }
  }
}
