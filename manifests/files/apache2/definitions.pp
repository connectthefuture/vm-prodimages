define apache2::site($production_domain,
    $staging_domain,
    $owner="www-data",
    $group="www-data") 
{
$sites_available_path = "/etc/apache2/sites-available/${djangoapp::full_project_name}.conf" 
$sites_enabled_path = "/etc/apache2/sites-enabled/${djangoapp::full_project_name}.conf"

file {$sites_available_path:
  content => template("apache2/project.conf.erb"),
  require => Package["apache2"],
  notify  => Service["apache2"],
  owner   => "root",
  group   => "root" 
  }

file {$sites_enabled_path:
  ensure  => link,
  target  => $sites_available_path,
  require => Package["apache2"],
  notify  => Service["apache2"],
  owner   => "root",
  group   => "root" 
  }
}

define apache2::mod_wsgi::setup(
    $venv_path,
    $server_type,
    $python_dir_name,
    $deployment_current_path,
    $deployment_etc_path,
    $owner="www-data",
    $group="www-data") 
{

$project_wsgi_path = $name

file {$project_wsgi_path:
  content => template("apache2/mod_wsgi/project.wsgi.erb"),
  require => [
              File[$deployment_etc_path],
              Package["apache2"],
              Package["libapache2-mod-wsgi"],
              ],
  notify  => Service["apache2"],
  owner   => $owner,
  group   => $group,
  mode    => 444
  }
}

