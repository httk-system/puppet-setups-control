$global_config = lookup("global")

if $facts["system_id"] {
  $sysid = $facts["system_id"]
} else {
  $sysid = $facts["hostname"]
}
notice("System id: $sysid")

$system_config = lookup("systems")[$sysid]

notice("Applying common : $system_config")
class { "setup::common":
  config => $system_config
}

$deps = lookup("setups").reduce([]) |$deps, $setup| {
  $setup_name=$setup.keys[0]
  $setup_config=$setup[$setup_name]
  $setup_config_config = $setup_config[config]
  $role_deps = $setup_config[roles].reduce([]) |$role_deps, $role_val| {
    $role_name = $role_val[0]
    $role_systems = $role_val[1]
    $role_sys_deps = $role_systems.reduce([]) |$role_sys_deps, $role_system| {
      $role_system_name=$role_system.keys[0]
      $role_system_config=$role_system[$role_system_name]
      if $role_system_name == $sysid {

	if $system_config =~ Hash {
	  $config1 = $system_config
	} else {
	  $config1 = {}
	}

	if $setup_config_config =~ Hash {
	  $config2 = $setup_config_config
	} else {
	  $config2 = {}
	}

	if $role_system_config =~ Hash {
	  $config3 = $role_system_config
	} else {
	  $config3 = {}
	}
        $config = $global_config + $config1 + $config2 + $config3
        notice("Applying role: $setup_name::$role_name : $config")

        #if defined( "setup::$setup_name::$role_name") {
        #  class { "setup::$setup_name::$role_name":
	#    config => $config
	#  }
        #}
        
        $new_deps = call("setup_$setup_name::$role_name", $config)
        if $new_deps {
          $role_sys_deps_new = $new_deps
        } else {
          $role_sys_deps_new = []
        }
      } else {
        $role_sys_deps_new = []
      }
      $role_sys_deps + $role_sys_deps_new
    }
    $role_deps + $role_sys_deps
  }
  $deps + $role_deps
}

$grouped_deps = $deps.reduce({}) |$grouped_deps, $dep| {
  $cls = $dep['class']
  if $cls in $grouped_deps {
    $grouped_deps_new = $grouped_deps + {$cls => $grouped_deps[$cls] + [$dep['config']]}
  } else {
    $grouped_deps_new = $grouped_deps + {$cls => [$dep['config']]}
  }
  $grouped_deps_new
}

notice("Resolving dependencies: $grouped_deps")

#lookup('classes', {merge => unique}).include
