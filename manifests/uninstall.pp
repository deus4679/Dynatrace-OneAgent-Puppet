class dynatraceoneagent::uninstall {
  $provider                            = $dynatraceoneagent::provider
  $install_dir                         = $dynatraceoneagent::install_dir
  $created_dir                         = $dynatraceoneagent::created_dir

  if ($facts['kernel'] == 'Linux' or $facts['os']['family'] == 'AIX') {
    exec { 'uninstall_oneagent':
      command   => "${install_dir}/agent/uninstall.sh",
      onlyif    => "test -f '${created_dir}'",
      timeout   => 6000,
      provider  => $provider,
      logoutput => on_failure,
    }
  } elsif $facts['os']['family'] == 'Windows' {
    $uninstall_command = @(EOT)
      $app = Get-WmiObject win32_product -filter "Name like 'Dynatrace OneAgent'"
      msiexec /x $app.IdentifyingNumber /quiet /l*vx uninstall.log
      | EOT

    exec { 'uninstall_oneagent':
      command   => $uninstall_command,
      onlyif    => "Test-Path -Path '${created_dir}' -PathType Leaf",
      timeout   => 6000,
      provider  => powershell,
      logoutput => on_failure,
    }
  }
}
