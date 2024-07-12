# @summary
#   This class manages the installation of the OneAgent on the host
#
class dynatraceoneagent::install {
  $created_dir              = $dynatraceoneagent::created_dir
  $download_dir             = $dynatraceoneagent::download_dir
  $filename                 = $dynatraceoneagent::filename
  $download_path            = $dynatraceoneagent::download_path
  $provider                 = $dynatraceoneagent::provider
  $oneagent_params_hash     = $dynatraceoneagent::oneagent_params_hash
  $reboot_system            = $dynatraceoneagent::reboot_system
  $service_name             = $dynatraceoneagent::service_name
  $package_state            = $dynatraceoneagent::package_state
  $oneagent_puppet_conf_dir = $dynatraceoneagent::oneagent_puppet_conf_dir

  if ($facts['kernel'] == 'Linux' or $facts['os']['family']  == 'AIX') {
    exec { 'install_oneagent':
      command   => $dynatraceoneagent::command,
      cwd       => $download_dir,
      timeout   => 6000,
      creates   => $created_dir,
      provider  => $provider,
      logoutput => on_failure,
    }
  }

  if ($facts['os']['family'] == 'Windows') {
    package { $service_name:
      ensure          => $package_state,
      provider        => $provider,
      source          => $download_path,
      install_options => [$oneagent_params_hash, '--quiet'],
    }
  }

  if ($reboot_system) and ($facts['os']['family'] == 'Windows') {
    reboot { 'after':
      subscribe => Package[$service_name],
    }
  } elsif ($facts['kernel'] == 'Linux' or $facts['os']['family']  == 'AIX') and ($reboot_system) {
    reboot { 'after':
      subscribe => Exec['install_oneagent'],
    }
  }
}
