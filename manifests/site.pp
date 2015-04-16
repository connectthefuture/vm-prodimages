# Exec { path => "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/home/${user}/virtualenvs/${project}/bin" }

# Global variables
$inc_file_path       = '/vagrant/manifests/files' # Absolute path to the files directory (If you're using vagrant, you can leave it alone.)
$tz                  = 'America/New_York' # Timezone
$user                = 'johnb' # User to create
$password            = 'admin' # The user's password
$project             = 'djdam' # Used in nginx and uwsgi
$domain_name         = 'DJDAM' # Used in nginx, uwsgi and virtualenv directory
$db_name             = 'www_django' # Mysql database name to create
$db_user             = 'root' # Mysql username to create
$db_password         = 'mysql' # Mysql password for $db_user
$mysql_root_password = 'mysql' # Mysql admin password for root, to change from no password
$mongodb_dbname         = 'images' # Mongo database name to create
$mongodb_collectname    = 'fs.files' # Mongo collection name using fs.files if making grid.fs to create
$mongodb_mongouser      = 'mongo' # Mongo Standard user username to create
$mongodb_mongopassword  = 'mongo' # Mongo Standard password for $db_user
$mongodb_adminuser      = 'johnb' # Mongo Admin user username to create
$mongodb_adminpassword  = 'admin' # Mongo Admin password for $db_user


Exec { path => "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/home/${user}/virtualenvs/${domain_name}/bin:/home/${user}/virtualenvs/${domain_name}/src/${project}" }

import 'nodes.pp'
#include ::ntp
include timezone
include user
include apt
include apache2
#include nginx
include uwsgi
include mysql
include php
#include phpmyadmin
#include tomcat7-solr
#include solr-tomcat
#include solr-jetty
include redis
include mongodb
include python
include ruby
include puppet-initial-commands
include virtualenv
include imgdeps
include software


# Class: timezone
#
#
class timezone {
  package { "tzdata":
    ensure => latest,
    require => Class['apt'],
  }

  file { "/etc/localtime":
    require => Package["tzdata"],
    source => "file:///usr/share/zoneinfo/${tz}",
  }
}


# class { '::ntp':
#   servers => [ 'ntp1.corp.com', 'ntp2.corp.com' ],
# }

# Class: user
#
#
class user {
  exec { 'add user':
    command => "sudo useradd -m -G sudo -s /bin/bash ${user}",
    unless => "id -u ${user}",
    environment => ['JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64',
                    'JETTY_HOME=/usr/share/jetty',
                    'JETTY_BASE=/var/lib/jetty/webapps',
                    'EDITOR=/usr/bin/nano'],
  }

  exec { 'set password':
    command => "echo \"${user}:${password}\" | sudo chpasswd",
    require => Exec['add user'],
  }

  # Prepare user's project directories and srv dir for media in /var/www DjangoDirs
  file { ["/home/${user}/virtualenvs",
          "/home/${user}/virtualenvs/${domain_name}",
          "/home/${user}/virtualenvs/${domain_name}/src",
          "/home/${user}/virtualenvs/${domain_name}/src/${project}",
          "/home/${user}/virtualenvs/${domain_name}/src/${project}/var",
          "/home/${user}/virtualenvs/${domain_name}/src/${project}/var/static",
          "/home/${user}/virtualenvs/${domain_name}/src/${project}/var/run",
          "/home/${user}/virtualenvs/${domain_name}/src/${project}/templates",
          "/home/${user}/.puppet",
          "/home/${user}/.puppet/modules"]:
    ensure => directory,
    owner => "${user}",
    group => "${user}",
    require => Exec['add user'],
    before => [File['srv dir'], File['www dir']]
  }

  file { 'www dir':
    #path => "/home/${user}/Sites/${domain_name}/media",
    path => "/var/www",
    ensure => directory,
    owner => 'root',
    group => 'root',
    mode => 0775,
    require => Exec['add user'],
    before => [File['srv dir']],
  }

  file { 'srv dir':
    #path => "/home/${user}/Sites/${domain_name}/media",
    path => "/var/www/srv",
    ensure => directory,
    owner => 'www-data',
    group => 'www-data',
    mode => 0775,
    require => Exec['add user'],
  }
}


class apt {
  exec { 'apt-get update':
    timeout => 0
  }

  package { 'python-software-properties':
    ensure => latest,
    require => Exec['apt-get update'],
  }

  exec { 'add-apt-repository ppa:nginx/stable':
    require => Package['python-software-properties'],
    before => Exec['last ppa'],
  }

  exec { 'last ppa':
    command => 'add-apt-repository ppa:git-core/ppa',
    require => Package['python-software-properties'],
  }

  exec { 'apt-get update again':
    command => 'apt-get update',
    timeout => 0,
    require => Exec['last ppa'],
  }
}


class nginx {
  package { 'nginx':
    ensure => latest,
    require => [Class['apt'], Class['apache2']],
  }

  service { 'nginx':
    ensure => running,
    enable => true,
    require => Package['nginx'],
  }

  file { '/etc/nginx/sites-enabled/default':
    ensure => absent,
    require => Package['nginx'],
  }

  file { 'sites-available config':
    path => "/etc/nginx/sites-available/${domain_name}",
    source => "${inc_file_path}/nginx/nginx.conf",
    ensure => file,
    #content => template("${inc_file_path}/nginx/nginx.conf.erb"),
    require => Package['nginx'],
  }

  file { "/etc/nginx/sites-enabled/${domain_name}":
    ensure => link,
    target => "/etc/nginx/sites-available/${domain_name}",
    require => File['sites-available config'],
    notify => Service['nginx'],
  }
}


class apache2 {
  package { 'apache2':
    ensure => latest,
    require => Class['apt'],
  }

  package { 'libapache2-mod-wsgi':
    ensure => latest,
    require => Class['apt'],
  }

  package { 'libapache2-mod-rpaf':
    ensure => latest,
    require => Class['apt'],
  }

  service { "apache2":
    ensure => running,
    enable => true,
    hasrestart => true,
    subscribe => [
                File['ports_conf'],
                File['httpd_conf'],
                ],
    require => [
                Package["apache2"],
                Package["libapache2-mod-wsgi"],
                Package["libapache2-mod-rpaf"]
               ],
  }

  file { 'ports_conf':
    path => "/etc/apache2/ports.conf",
    source => "${inc_file_path}/apache2/ports.conf",
    require => Package["apache2"],
    ensure => file,
    notify => Service["apache2"],
    owner => "root",
    group => "root",
  }

  file { 'httpd_conf':
    path => "/etc/apache2/httpd.conf",
    source => "${inc_file_path}/apache2/httpd.conf",
    require => Package["apache2"],
    ensure => file,
    notify => Service["apache2"],
    owner => "root",
    group => "root",
  }

}


class uwsgi {
  $sock_dir = '/tmp/uwsgi' # Without a trailing slash
  $uwsgi_user = 'www-data'
  $uwsgi_group = 'www-data'

  package { 'uwsgi':
    ensure => latest,
    provider => pip,
    require => Class['python'],
  }

  service { 'uwsgi':
    ensure => running,
    enable => true,
    require => File['apps-enabled config'],
  }

  # Prepare directories
  file { ['/var/log/uwsgi', '/etc/uwsgi', '/etc/uwsgi/apps-available', '/etc/uwsgi/apps-enabled']:
    ensure => directory,
    require => Package['uwsgi'],
    before => File['apps-available config'],
  }

  # Prepare a directory for sock file
  file { [$sock_dir]:
    ensure => directory,
    owner => "${uwsgi_user}",
    require => Package['uwsgi'],
  }

  # Upstart file
  file { '/etc/init/uwsgi.conf':
    ensure => file,
    source => "${inc_file_path}/uwsgi/uwsgi.conf",
    require => Package['uwsgi'],
  }

  # django uwsgi ini file
  file { 'apps-available config':
    path => "/etc/uwsgi/apps-available/${project}.ini",
    ensure => file,
    content => template("${inc_file_path}/uwsgi/uwsgi.ini.erb")
  }

  file { 'apps-enabled config':
    path => "/etc/uwsgi/apps-enabled/${project}.ini",
    ensure => link,
    target => "/etc/uwsgi/apps-available/${project}.ini",
    require => File['apps-available config'],
  }
}


class mysql {
  $create_user_cmd = "CREATE USER '${db_user}'@localhost IDENTIFIED BY '${db_password}';"
  $create_db_cmd = "CREATE DATABASE ${db_name} CHARACTER SET utf8;"
  $grant_db_cmd = "GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_user}'@localhost;"

  package { 'mysql-server':
    ensure => latest,
    require => Class['apt'],
  }

  package { 'mysql-client':
    ensure => latest,
    require => Class['apt'],
  }

  package { 'libmysqlclient-dev':
    ensure => latest,
    require => Class['apt'],
  }

  file { "my.cnf":
    path => "/etc/mysql/my.cnf",
    #source => "puppet:///modules/mysql/my.cnf",
    source => "${inc_file_path}/mysql/my.cnf",
    require => Package["mysql-server"],
    notify => Service["mysql"],
  }

  service { 'mysql':
    ensure => running,
    enable => true,
    require => Package['mysql-server'],
    subscribe => [Package["mysql-server"]], #, File["my.cnf"]],
  }

  # Set up the root user and passwd
  exec { 'set-mysql-root-password':
    unless => "mysqladmin -uroot -p${mysql_root_password} status",
    path => ["/bin", "/usr/bin"],
    command => "mysqladmin -uroot -p password ${mysql_root_password}",
    #before => Exec['grant-user-db'],
    require => Package["mysql-server"],
  }

  exec { 'create-user':
    unless => "mysqlshow -u${db_user} -p${db_password} ${db_name}",
    command => "mysql -uroot -p${mysql_root_password}  -e \"${create_user_cmd}\"",
    before => Exec['create-user-db'],
    require => Service['mysql'],
               #Exec['set-mysql-root-password']]
  }

  exec { 'create-user-db':
    #unless => "mysqlshow -u${db_user} -p${db_password} ${db_name}",
    command => "mysql -uroot -p${mysql_root_password} -e \"${create_db_cmd}\"",
    before => Exec['grant-user-db'],
    require => [Service['mysql'], Exec['set-mysql-root-password']],
  }

  exec { 'grant-user-db':
    command => "mysql -uroot -p${mysql_root_password} -e \"${grant_db_cmd}\"",
    before => Exec['import-mysql-database'],
    require => [Service['mysql'], Exec['set-mysql-root-password']],
  }

  exec { 'import-mysql-database':
    path  => '/usr/bin:/usr/sbin',
    command => "mysql -u${db_user} -p${db_password} -D ${db_name} < ${inc_file_path}/mysql/${db_name}.sql",
    require => [Service['mysql'], Exec['set-mysql-root-password']],
  }
}


class python {
  package { 'curl':
    ensure => latest,
    require => Class['apt'],
  }

  package { 'python':
    ensure => latest,
    require => Class['apt'],
  }

  package { 'python-dev':
    ensure => latest,
    require => Class['apt'],
  }

  package { 'ipython':
    ensure => latest,
    require => Class['apt'],
  }

  package { 'pkg-config':
    ensure => latest,
    require => Class['apt'],
  }

  package { 'python-mysqldb':
    ensure => latest,
    require => Class['apt'],
  }

  ## New command jan20
  package { 'python-setuptools':
    ensure => latest,
    require => Class['apt'],
  }

  # package { 'python-mysql.connector':
  #   ensure => latest,
  #   require => Class['apt'],
  # }

  exec { 'install-distribute':
    command => 'curl http://python-distribute.org/distribute_setup.py | python',
    require => Package['python-dev', 'curl', 'python-setuptools']
  }

  exec { 'install-pip':
    command => 'easy_install pip',
    require => Exec['install-distribute'],
  }
}


class phpmyadmin {
  package { 'phpmyadmin':
    ensure => latest,
    require => Class['php', 'mysql', 'apache2'],
  }

  file { '/etc/phpmyadmin/apache.conf':
    path => "/etc/phpmyadmin/apache.conf",
    source => "${inc_file_path}/phpmyadmin/apache.conf",
    require => Class['php', 'mysql', 'apache2'],
    mode => 0775,
    owner => "root",
    #notify => Service["mysql"],
  }

  file { 'link-to-apache':
    target => '/etc/apache2/conf.d/phpadmin.conf',
    ensure => link,
    owner => "root",
    group => "www-data",
    path => "/etc/phpmyadmin/paache.conf",
    require => File['/etc/phpmyadmin/apache.conf'],
  }

  file { '/etc/phpmyadmin/config-db.php':
    path => "/etc/phpmyadmin/config-db.php",
    source => "${inc_file_path}/phpmyadmin/config-db.php",
    require => [
        Package['phpmyadmin'],
        Class['php', 'mysql', 'apache2'],
        ],
  }

  file { '/etc/phpmyadmin/config.inc.php':
    path => "/etc/phpmyadmin/config.inc.php",
    source => "${inc_file_path}/phpmyadmin/config.inc.php",
    require => Class['php', 'mysql', 'apache2'],
    #notify => Service['mysql', 'apache2'],
  }
  # # Remove config if it does not include auto-login options
  # exec { 'remove-non-autologin-config':
  #   command => 'sudo rm /etc/phpmyadmin/config.inc.php',
  #   unless => 'grep "Enable auto-login" /etc/phpmyadmin/config.inc.php',
  #   path => ['/bin/', '/usr/bin/'],
  #   #notify => Exec['download-autologin-config'],
  # }
}


class php {
  package { ['php5', 'php5-dev', 'php-pear', 'libapache2-mod-php5', 'php-mdb2-driver-mysql', 'php5-mysql']:# , 'php5-xdebug', 'php5-xcache', 'php5-curl', 'php-xml-rpc2', 'php-xml-htmlsax3', 'php-xml-serializer', 'php-xml-parser', 'php-mail-mimedecode']:
    ensure => latest,
    require => Class['apt'],
  }

  # exec { "UsergroupChange":
  #   command => "sed -i 's/User apache/User vagrant/ ; s/Group apache/Group vagrant/' /etc/httpd/conf/httpd.conf",
  #   onlyif  => "grep -c 'User apache' /etc/httpd/conf/httpd.conf",
  #   require => Class["apache2"],
  #   notify  => Service['apache2'],
  # }

  file { "/var/lib/php/session":
    owner  => "root",
    group  => "vagrant",
    mode   => 0770,
    require => Package['php5'],
  }

  file { "/etc/php5/apache2/php.ini":
    path => '/etc/php5/apache2/php.ini',
    #ensure => "present",
    source => "${inc_file_path}/php5/php.ini",
    owner => "root",
    group => "root",
    mode => 644,
    require => [
                Class["apache2"],
                Package["php5"],
                ],
  }

  file { "/var/www/index.php":
      #notify => Service["apache2"],
      #ensure => "present",
      source => "${inc_file_path}/php5/index.php",
      path => "/var/www/index.php",
      owner => "root",
      group => "root",
      mode => 644,
      require => [
                  Class["apache2"],
                  Package["php5"],
                  ],
  }
}


class virtualenv {
  package { 'virtualenv':
    ensure => latest,
    provider => pip,
    require => Class['python', 'user'],
  }

  exec { 'create-virtualenv':
    command => "virtualenv ${domain_name}",
    cwd => "/home/${user}/virtualenvs",
    user => "${user}",
    #unless => 'test -d /home/${user}/virtualenvs/${domain_name}',
    require => Package['virtualenv'],
    before => File['requirements.txt'],
  }

  file { 'media dir':
    #path => "/home/${user}/Sites/${domain_name}/media",
    path => "/var/www/srv/media",
    ensure => directory,
    owner => 'www-data',
    group => 'www-data',
    mode => 0775,
  }

  file { "/home/${user}/virtualenvs/${domain_name}/src/${project}/var/media":
    target => "/var/www/srv/media",
    ensure => link,
    owner => "${user}",
    group => "www-data",
    path => "/home/${user}/virtualenvs/${domain_name}/src/${project}/var/media",
    require => [Exec['create-virtualenv'], File['media dir']]
  }

  file { 'requirements.txt':
    ensure => file,
    path => "/home/${user}/virtualenvs/${domain_name}/src/requirements.txt",
    owner => "${user}",
    group => "${user}",
    mode => 0644,
    source => "${inc_file_path}/virtualenv/requirements.txt",
    require => Exec['create-virtualenv'],
  }
}


class imgdeps {
  exec { 'exiftool-full':
    command => 'wget -O Image-ExifTool-9.47.tar.gz http://www.sno.phy.queensu.ca/~phil/exiftool/Image-ExifTool-9.47.tar.gz && gzip -dc Image-ExifTool-9.47.tar.gz | tar -xf - && cd Image-ExifTool-9.47/ && perl Makefile.PL && make test && sudo make install',
    cwd => '/root',
    user => 'root',
    require => Package['libjpeg-dev'],
  }

  package { ['python-imaging', 'libjpeg-dev', 'libpng-dev', 'libtiff-dev', 'liblcms1-dev', 'libsvga1-dev', 'librsvg2-dev', 'libfreetype6-dev', 'libexif-dev', 'libglib2.0-dev', 'libexiv2-dev']:
    ensure => latest,
    require => Class['apt'],
    before => Exec['pil-png', 'pil-jpg', 'pil-freetype'],
  }

  package { 'dcraw':
    ensure => latest,
    require => Class['apt'],
  }

  package { 'ufraw':
    ensure => latest,
    require => Class['apt'],
  }

  package { 'imagemagick':
    ensure => latest,
    require => [Class['apt'], Package['dcraw', 'ufraw', 'libjpeg-dev']],
  }

  exec { 'pil-png':
    command => 'sudo ln -s /usr/lib/`uname -i`-linux-gnu/libz.so /usr/lib/',
    unless => 'test -L /usr/lib/libz.so'
  }

  exec { 'pil-jpg':
    command => 'sudo ln -s /usr/lib/`uname -i`-linux-gnu/libjpeg.so /usr/lib/',
    unless => 'test -L /usr/lib/libjpeg.so'
  }

  exec { 'pil-freetype':
    command => 'sudo ln -s /usr/lib/`uname -i`-linux-gnu/libfreetype.so /usr/lib/',
    unless => 'test -L /usr/lib/libfreetype.so'
  }

  package { 'exiv2':
    ensure => latest,
    require => Class['apt'],
  }

  exec { 'install-gexiv2':
    command => 'wget -O gexiv2.tar.xz http://ftp.gnome.org/pub/gnome/sources/gexiv2/0.7/gexiv2-0.7.0.tar.xz && tar -xvf gexiv2.tar.xz && cd gexiv2-0.7.0 && ./configure && make && make install',
    require => Package['libexiv2-dev', 'libglib2.0-dev'],
    cwd => '/root',
    user => 'root',
  }
}

#class mongodb {

#  package { 'mongodb':
#    ensure => latest,
#    require => Class['apt'],
#  }
#}

#class mongodb(
#  $replSet = "",
#  $respawn = "",
#  $ulimit_nofile = "1024",
#  $repository = "deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen",
#  $package = "mongodb-10gen"
#  ) {

class mongodb{

  exec { 'add-mongo-user':
    command => "sudo useradd -r -U ${mongodb_mongouser}",
    #unless => "id -u ${user}",
    user => "root",
    environment => ['MONGOHOME=/data/db',
                    'MONGOBASE=/usr/bin'];
  }

  file { 'data-mkdir':
    #path => "/home/${user}/Sites/${domain_name}/media",
    path => "/data",
    ensure => directory,
    owner => "${mongodb_mongouser}",
    group => "${mongodb_mongouser}",
    mode => 0755,
    require => Exec['add-mongo-user'],
    before => File['data-db-mkdir'],
  }

  file { 'data-db-mkdir':
    #path => "/home/${user}/Sites/${domain_name}/media",
    path => "/data/db",
    ensure => directory,
    owner => "${mongodb_mongouser}",
    group => "${mongodb_mongouser}",
    mode => 0755,
    require => Exec['add-mongo-user'],
  }

  exec { "10gen-apt-key":
    path => "/bin:/usr/bin",
    command => "apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10",
    unless => "apt-key list | grep 10gen",
  }

  exec { "10gen-apt-repo":
    path => "/bin:/usr/bin",
    command => "echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' >> /etc/apt/sources.list",
    unless => "cat /etc/apt/sources.list | grep 10gen",
    require => Exec["10gen-apt-key"],
  }

  exec { "10gen-apt-update":
    path => "/bin:/usr/bin",
    command => "apt-get update",
    unless => "ls /usr/bin | grep mongo",
    require => Exec["10gen-apt-repo"],
  }

  package { "mongodb-10gen":
    ensure => installed,
    require => Exec["10gen-apt-update"],
  }

  service { "mongodb":
    enable => true,
    ensure => running,
    require => Package["mongodb-10gen"],
  }

  ## Init mongo conf
  file { '/etc/init/mongodb.conf':
    path => "/etc/init/mongodb.conf",
    source => "${inc_file_path}/mongodb/init/init_mongodb.conf",
    mode => 0644,
    owner => "root",
    notify => Service["mongodb"],
    require => Package["mongodb-10gen"],
  }

  ## Primary mongo conf
  file { '/etc/mongodb.conf':
    path => "/etc/mongodb.conf",
    source => "${inc_file_path}/mongodb/mongodb.conf",
    #    content => template("mongodb/mongodb.conf.erb"),
    mode => 0644,
    owner => "root",
    notify => Service["mongodb"],
    require => [
            Package["mongodb-10gen"],
            File['/etc/init/mongodb.conf'],
            ],
  }
}


class nodejs {
  exec { 'add-nodejs-user':
    command => "sudo useradd -r -U nodejs",
    #unless => "id -u ${user}",
    user => "root",
    environment => ['NODEBASE=/home/${user}/virtualenvs/nodejs',
                    'NODEROOT=/usr/bin'];
  }
  package { 'nodejs':
    ensure => latest,
    require => Class['apt'],
  }
}

class puppet-initial-commands {
  package { 'wget':
    ensure => latest,
    require => Class['apt'],
  }

  package { 'puppet':
    ensure => latest,
    require => Class['apt'],
  }

  package { "puppet-dashboard":
    ensure => latest,
    require => [Class['apt'], Package['puppet']],
    #path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    #command => "sudo apt-get install puppet-dashboard",
    #refreshonly => true,
  }

  exec { "update-puppet-ppa":
    require => Package['wget'],
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    command => "wget https://apt.puppetlabs.com/puppetlabs-release-precise.deb;\
            sudo dpkg -i puppetlabs-release-precise.deb;\
            sudo apt-get update;",
    before => Package['puppet-dashboard'],
    #refreshonly => true,
  }

  exec {"puppet-modules-ex42":
    require => Package['git'],
    command => "git clone --recursive https://github.com/example42/puppet-modules-nextgen.git /etc/puppet/modules",
  }
}


class solr-jetty {
  package { 'jetty':
    ensure => latest,
    require => Class['apt'],
  }

  package { 'openjdk-7-jdk':
    ensure => latest,
    require => Class['apt'],
  }

  file { '/usr/share/solr':
    ensure => directory,
    path => '/usr/share/solr',
    owner => "root",
    group => "root",
    mode => 0755,
  }

  exec { 'download-solr':
    require => File['/usr/share/solr'],
    before => Exec['unpack-solr'],
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    user => "root",
    cwd => "/usr/share/solr",
    environment => ['JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64',
                    'JETTY_HOME=/usr/share/jetty',
                    'JETTY_BASE=/var/lib/jetty/webapps',
                    'EDITOR=/usr/bin/nano'],
    command => "wget -x --directory-prefix=/usr/share/solr -O solr.tgz http://mirror.symnds.com/software/Apache/lucene/solr/4.6.0/solr-4.6.0.tgz;",
  }

  exec { 'unpack-solr':
    require => [File['/usr/share/solr'],
                Exec['download-solr']],
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    user => "root",
    cwd => "/usr/share/solr",
    command => "tar -xvzf /usr/share/solr/solr.tgz -C /usr/share/solr/;",
  }

  exec { 'copy-solr-files-jetty':
    require => Exec['unpack-solr'],
    before => File['jetty-default-start'],
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    user => "root",
    cwd => "/usr/share/solr",
    command => "sudo cp -R /usr/share/solr/solr-4.6.0/example/lib/ /usr/share/solr/lib && sudo cp -R /usr/share/solr/solr-4.6.0/example/example-DIH/ /usr/share/solr/solr/example-DIH && sudo cp -R /usr/share/solr/solr-4.6.0/example/resources/ /usr/share/solr/resources && sudo cp -R /usr/share/solr/solr-4.6.0/example/start.jar /usr/share/solr/start.jar && sudo cp /usr/share/solr/solr-4.6.0/example/etc/*.xml /etc/jetty & sudo cp -R /usr/share/solr/solr-4.6.0/example/solr/collection1/ /usr/share/solr/solr && sudo mkdir -p /var/lib/jetty/lib && sudo chown -R solr:solr /var/lib/jetty && sudo chmod -R ug+rw /var/lib/jetty && sudo mkdir /usr/share/solr/solr/data && sudo mkdir /usr/share/solr/work && sudo cp /usr/share/solr/solr-4.6.0/example/webapps/*.war /var/lib/jetty/webapps && sudo cp -R /usr/share/solr/solr-4.6.0/dist/ /usr/share/solr/solr/dist && sudo cp -R /usr/share/solr/solr-4.6.0/contrib/ /usr/share/solr/solr/contrib && sudo cp -R /usr/share/solr/solr-4.6.0/example/contexts/solr-jetty-context.xml /var/lib/jetty/webapps/solr.xml && sudo cp -R /usr/share/solr/solr-4.6.0/example/lib/* /var/lib/jetty/lib;",
  }

  exec {
  'add-solr-user':
    command => "sudo useradd -r -U solr",
    #unless => "id -u ${user}",
    user => "root",
    environment => ['JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64',
                    'JETTY_HOME=/usr/share/jetty',
                    'JETTY_BASE=/var/lib/jetty/webapps',
                    'EDITOR=/usr/bin/nano'];

  'set-solr-password':
    command => "echo solr:solr | sudo chpasswd",
    require => Exec['add-solr-user'],
    user => "root",
    before => Exec['chown-solr-dirs'],;
  }

  exec {'chown-solr-dirs':
    command => "sudo chown -R solr:solr /usr/share/solr && sudo mkdir -p /var/log/solr && sudo chown -R solr:solr /var/log/solr && sudo chmod -R ug+rw /var/log/solr && sudo chmod -R ug+rw /usr/share/solr/solr/data && sudo chmod -R ug+rw /usr/share/solr/work;",
    user => "root",
    require => Exec['copy-solr-files-jetty'],
    before => Service['jetty'],
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    cwd => "/usr/share",
  }

  file {
  'jetty-default-start':
    path => "/etc/default/jetty",
    source => "${inc_file_path}/solr-jetty/jetty",
    before => Service['jetty'],
    ensure => file,
    notify => Service["jetty"],
    owner => "root",
    group => "root";

  'solr_solrconfig_conf':
    path => "/usr/share/solr/solr/conf/solrconfig.xml",
    source => "${inc_file_path}/solr-jetty/solrconfig.xml",
    require => Exec['chown-solr-dirs'],
    ensure => file,
    notify => Service['jetty'],
    owner => "solr",
    group => "solr";

  'solr_schema_conf':
    path => "/usr/share/solr/solr/conf/schema.xml",
    source => "${inc_file_path}/solr-jetty/schema.xml",
    require => Exec['chown-solr-dirs'],
    ensure => file,
    notify => Service['jetty'],
    owner => "solr",
    group => "solr";

  'solr_dbdataconfig_conf':
    path => "/usr/share/solr/solr/conf/db-data-config.xml",
    source => "${inc_file_path}/solr-jetty/db-data-config.xml",
    require => Exec['chown-solr-dirs'],
    ensure => file,
    notify => Service['jetty'],
    owner => "solr",
    group => "solr";

   'solr_core_properties':
    path => "/usr/share/solr/solr/conf/core.properties",
    source => "${inc_file_path}/solr-jetty/core.properties",
    require => Exec['chown-solr-dirs'],
    ensure => file,
    notify => Service['jetty'],
    owner => "solr",
    group => "solr";

  'jetty_classpath_startconfig':
    path => "/etc/jetty/start.config",
    source => "${inc_file_path}/solr-jetty/etc-jetty-start.config",
    require => Exec['chown-solr-dirs'],
    ensure => file,
    notify => Service['jetty'],
    owner => "solr",
    group => "solr";
  }

  service { 'jetty':
    ensure => running,
    enable => true,
    require => Package['jetty'],
    subscribe => [Exec["copy-solr-files-jetty"],
                  File["jetty-default-start"],
                  File['solr_solrconfig_conf'],
                  File['jetty_classpath_startconfig']],
  }
}


class solr-tomcat {
  package { [ 'tomcat6', 'tomcat6-admin', 'tomcat6-examples',  'openjdk-7-jdk' ] :
    ensure => latest,
    require => Class['apt'],;
  }

  file { 'make-opt-solr':
    ensure => directory,
    require => Package['tomcat6'],
    path => '/opt/solr',
    owner => "root",
    group => "tomcat6",
    mode  => 0775;

    ## next tells tomcat where to find solr home
  'tomcat6-catalina-localhost-solrxml':
    path => "/etc/tomcat6/Catalina/localhost/solr.xml",
    source => "${inc_file_path}/solr-tomcat/_etc_tomcat6_Catalina_localhost_solr.xml",
    #before => Service['tomcat6'],
    ensure => directory,
    notify => Service["tomcat6"],
    require => Package['tomcat6'],
    owner => "root",
    group => "root";

  ## next tells solr about added core
  'add-core-solrxml':
    path => "/opt/solr/example/solr/solr.xml",
    source => "${inc_file_path}/solr-tomcat/_opt_solr_example_solr_solr.xml",
    #before => Service['tomcat6'],
    ensure => directory,
    notify => Service["tomcat6"],
    require => [Package['tomcat6'],
                          Exec['unpack-solr']],
    owner => "tomcat6",
    group => "tomcat6";

  'solr_solrconfig_conf':
    path => "/opt/solr/example/solr/collection1/conf/solrconfig.xml",
    source => "${inc_file_path}/solr-tomcat/solrconfig.xml",
    require => [Package['tomcat6'],
                Exec['chown-solr-dirs'],
                Exec['unpack-solr']],
    ensure => directory,
    notify => Service['tomcat6'],
    owner => "tomcat6",
    group => "tomcat6";

  'solr_schema_conf':
    path => "/opt/solr/example/solr/collection1/conf/schema.xml",
    source => "${inc_file_path}/solr-tomcat/schema.xml",
    require => [Package['tomcat6'],
                Exec['chown-solr-dirs'],
                Exec['unpack-solr']],
    ensure => directory,
    notify => Service['tomcat6'],
    owner => "tomcat6",
    group => "tomcat6";

  'solr_dbdataconfig_conf':
    path => "/opt/solr/example/solr/collection1/conf/db-data-config.xml",
    source => "${inc_file_path}/solr-tomcat/db-data-config.xml",
    require => [Package['tomcat6'],
                Exec['chown-solr-dirs'],
                Exec['unpack-solr']],
    ensure => directory,
    notify => Service['tomcat6'],
    owner => "tomcat6",
    group => "tomcat6";

  'tomcat_users_conf':
    path => "/etc/tomcat6/tomcat-users.xml",
    source => "${inc_file_path}/solr-tomcat/_etc_tomcat6_tomcat-users.xml",
    require => [Exec['chown-solr-dirs'],
                Package['tomcat6']],
    ensure => directory,
    notify => Service['tomcat6'],
    owner => "root",
    group => "root";
  }

  exec { 'add-solr-user':
    command => "sudo useradd -r -U solr",
    #unless => "id -u ${user}",
    user => "root",
    environment => ['JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64',
                    'CATALINA_HOME=/usr/share/tomcat6',
                    'CATALINA_BASE=/var/lib/tomcat6/webapps',
                    'EDITOR=/usr/bin/nano'],;

  'set-solr-password':
    command => "echo solr:solr | sudo chpasswd",
    require => Exec['add-solr-user'],
    user => "root",
    before => Exec['chown-solr-dirs'],;

  'download-solr':
    require => File['make-opt-solr'],
    before => Exec['unpack-solr'],
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    user => "root",
    cwd => "/opt/solr",
    environment => ['JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64',
                    'CATALINA_HOME=/usr/share/tomcat6',
                    'CATALINA_BASE=/var/lib/tomcat6/webapps',
                    'EDITOR=/usr/bin/nano'],
    command => "wget -x --directory-prefix=/opt/solr -O solr.tgz http://mirror.symnds.com/software/Apache/lucene/solr/4.6.0/solr-4.6.0.tgz;";

  'unpack-solr':
    require => [File['make-opt-solr'],
                Exec['download-solr']],
    before =>   Exec['chown-solr-dirs'],
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    user => "root",
    cwd => "/opt/solr",
    command => "tar -xvzf /opt/solr/solr.tgz -C /opt/solr/;";

  'copy-solr-files-solrhome':
    require => Exec['unpack-solr'],
    before => Service['tomcat6'],
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    user => "root",
    cwd => "/opt/solr",
    command => "sudo cp -rf /opt/solr/solr-4.6.0/* /opt/solr;";

  'create-new-solr-core':
    require => Exec['copy-solr-files-solrhome'],
    before => Service['tomcat6'],
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    user => "root",
    cwd => "/opt/solr",
    command => "sudo cp -rf /opt/solr/example/solr/collection1 /opt/solr/example/solr/www_django";

  'chown-solr-dirs':
    user => "root",
    require => [Exec['copy-solr-files-solrhome'],
                File['add-core-solrxml']],
    before => Service['tomcat6'],
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    cwd => "/opt/solr",
    command => "sudo chown -R tomcat6:tomcat6 /opt/solr/";
  }

  exec { 'copy-solr-tomcatlib':
    command => "sudo cp -r /opt/solr/example/lib/ext/* /usr/share/tomcat6/lib",
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    user => "root",
    cwd => "/opt/solr",
    require => Exec['chown-solr-dirs'],;
    #refreshonly => true,

  'chown-tomcat6-usr-share-tomcatlib':
    command => "sudo chown -R tomcat6:tomcat6 /usr/share/tomcat6/lib",
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    user => "root",
    cwd => "/usr/share/tomcat6/lib",
    require => Exec['copy-solr-tomcatlib'],;
  }

  exec { 'collect-jars-to-catalina-home-shared':
    command => "sudo mkdir -p /usr/share/tomcat6/shared/classes && sudo chown -R tomcat6:tomcat6 /usr/share/tomcat6/shared",
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    user => "tomcat6",
    cwd => "/usr/share/tomcat6",
    before => Service['tomcat6'],
    require => Exec['chown-tomcat6-usr-share-tomcatlib'],
  }

  file { 'log4jprops':
    path => "/usr/share/tomcat6/lib/log4j.properties",
    source => "${inc_file_path}/solr-tomcat/_usr_share_tomcat6_lib_log4j.properties",
    require => [Exec['chown-tomcat6-usr-share-tomcatlib'],
                Package['tomcat6']],
    ensure => file,
    notify => Service['tomcat6'],
    owner => "tomcat6",
    group => "tomcat6",
  }

  file { 'mkdir-solr-lib':
    path => "/opt/solr/example/solr/lib",
    ensure => directory,
    require => Exec['create-new-solr-core'],
    owner => "tomcat6",
    group => "tomcat6",
    mode => 0755;
  }

  file { 'mysql-connector-solr-jar':
    path => "/opt/solr/example/solr/lib/mysql-connector-java-5.1.26-bin.jar",
    source => "${inc_file_path}/solr-tomcat/mysql-connector-java-5.1.26-bin.jar",
    ensure => file,
    require => File['mkdir-solr-lib'],
  }


  file { 'make-data-dirs-in-collection1-core':
    path => "/opt/solr/example/solr/collection1/data",
    ensure => directory,
    require => Exec['create-new-solr-core'],
    owner => "tomcat6",
    group => "tomcat6",
    mode => 0755;

  'make-data-dirs-in-www_django-core':
    path => "/opt/solr/example/solr/www_django/data",
    ensure => directory,
    require => Exec['create-new-solr-core'],
    owner => "tomcat6",
    group => "tomcat6",
    mode => 0755;

  'make-data-dirs-in-solrhome':
    path => "/opt/solr/example/solr/data",
    ensure => directory,
    require => Exec['create-new-solr-core'],
    owner => "tomcat6",
    group => "tomcat6",
    mode => 0755;

  }

  service { 'tomcat6':
    ensure => running,
    enable => true,
    require => Package['tomcat6'],
    subscribe => [File['log4jprops'],
                 Exec['create-new-solr-core'],
                 File['tomcat_users_conf']],;
  }
}

  # class solr-tomcat {
  #   package {'solr-tomcat':
  #     ensure => latest,
  #     require => Class['apt'],
  #   }

  #   package { 'openjdk-7-jdk':
  #     ensure => latest,
  #     require => Class['apt'],
  #   }

  #   service { 'tomcat6':
  #     ensure => running,
  #     enable => true,
  #     require => Package['solr-tomcat'],
  #     #subscribe => Exec["copy-solr-files-jetty"],
  #   }


class redis {
  package { 'tcl8.5':
    ensure => latest,
    require => Class['apt'],
  }

  file { "/etc/redis":
    ensure => directory,
    owner => "root",
    path => "/etc/redis",
    group => "root",
    #before => [File['srv dir'], File['www dir']],
    require => Package['tcl8.5']
  }

  exec { "source-make-redis":
    require => Package['wget'],
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    command => "wget http://download.redis.io/redis-stable.tar.gz && tar -xvzf redis-stable.tar.gz && cd redis-stable && make && make install;",
    cwd => "/root",
    user => "root",
    before => Exec['install-redis'],
    #refreshonly => true,
  }

  exec { "install-redis":
    require => Exec["source-make-redis"],
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    command => "sudo cp src/redis-server /usr/local/bin && sudo cp src/redis-cli /usr/local/bin && sudo cp redis.conf /etc/redis/redis.conf;",
    cwd => "/root/redis-stable",
    user => "root",
    #before => Package['install-redis'],
    #refreshonly => true,
  }

  file { "/etc/init/redis-server":
    path => "/etc/init/redis-server.conf",
    source => "${inc_file_path}/redis/_etc_init_redis-server.conf",
    ensure => file,
    require => Exec['install-redis'],
  }

  exec { "start-redis":
    require => File["/etc/init/redis-server"],
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    command => "sudo start redis-server",
    #cwd => "/root/redis-stable",
    user => "root",
  }
  ##redis closing brace
}


class tomcat7-solr {
  package { [ 'tomcat7', 'tomcat7-admin', 'tomcat7-examples',  'openjdk-7-jdk' ] :
    ensure => latest,
    require => Class['apt'],;
  }

  file {
  'make-user-share-solr':
    ensure => directory,
    require => Package['tomcat7'],
    path => '/usr/share/solr',
    owner => "root",
    group => "tomcat7",
    mode  => 0775,
  }

  exec {
  'download-solr':
    #require => File['make-user-share-solr'],
    before => Exec['unpack-solr'],
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    user => "root",
    cwd => "/user/share/solr",
    environment => ['JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64',
                              'CATALINA_HOME=/usr/share/tomcat7',
                              'CATALINA_BASE=/var/lib/tomcat7/webapps',
                              'EDITOR=/usr/bin/nano'],
    command => "wget -x --directory-prefix=/user/share/solr -O solr.tgz http://mirror.symnds.com/software/Apache/lucene/solr/4.6.0/solr-4.6.0.tgz;";

  'unpack-solr':
    #require => [File['make-user-share-solr'],
    require =>    Exec['download-solr'],
    #before =>   Exec['chown-solr-dirs'],
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    user => "root",
    cwd => "/user/share/solr",
    command => "tar -xvzf /user/share/solr/solr.tgz -C /user/share/solr/;";

  'copy-solr-files-solrhome':
    require => Exec['unpack-solr'],
    before => Service['tomcat7'],
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    user => "root",
    cwd => "/user/share/solr",
    command => "sudo cp -rf /user/share/solr/solr-4.6.0/* /user/share/solr;";
  }

  file {
   ## next tells tomcat where to find solr home
  'tomcat7-catalina-localhost-solrxml':
    path => "/etc/tomcat7/Catalina/localhost/solr.xml",
    source => "${inc_file_path}/solr-tomcat/_etc_tomcat7_Catalina_localhost_solr.xml",
    #before => Service['tomcat7'],
    ensure => directory,
    notify => Service["tomcat7"],
    require => Package['tomcat7'],
    owner => "root",
    group => "root";

  ## next tells solr about added core
  'add-core-solrxml':
    path => "/user/share/solr/example/solr/solr.xml",
    source => "${inc_file_path}/solr-tomcat/_user/share_solr_example_solr_solr.xml",
    #before => Service['tomcat7'],
    ensure => directory,
    notify => Service["tomcat7"],
    require => [Package['tomcat7'],
                          Exec['unpack-solr']],
    owner => "tomcat7",
    group => "tomcat7";

  'solr_solrconfig_conf':
    path => "/user/share/solr/example/solr/collection1/conf/solrconfig.xml",
    source => "${inc_file_path}/solr-tomcat/solrconfig.xml",
    require => [Package['tomcat7'],
                #Exec['chown-solr-dirs'],
                Exec['unpack-solr']],
    ensure => directory,
    notify => Service['tomcat7'],
    owner => "tomcat7",
    group => "tomcat7";

  'solr_schema_conf':
    path => "/user/share/solr/example/solr/collection1/conf/schema.xml",
    source => "${inc_file_path}/solr-tomcat/schema.xml",
    require => [Package['tomcat7'],
                #Exec['chown-solr-dirs'],
                Exec['unpack-solr']],
    ensure => directory,
    notify => Service['tomcat7'],
    owner => "tomcat7",
    group => "tomcat7";

  'solr_dbdataconfig_conf':
    path => "/user/share/solr/example/solr/collection1/conf/db-data-config.xml",
    source => "${inc_file_path}/solr-tomcat/db-data-config.xml",
    require => [Package['tomcat7'],
                #Exec['chown-solr-dirs'],
                Exec['unpack-solr']],
    ensure => directory,
    notify => Service['tomcat7'],
    owner => "tomcat7",
    group => "tomcat7";

  'tomcat_users_conf':
    path => "/etc/tomcat7/tomcat-users.xml",
    source => "${inc_file_path}/solr-tomcat/_etc_tomcat7_tomcat-users.xml",
    require => #[Exec['chown-solr-dirs'],
                       Package['tomcat7'],
    ensure => directory,
    notify => Service['tomcat7'],
    owner => "root",
    group => "tomcat7";
  }

  file { 'log4jprops':
    path => "/usr/share/tomcat7/lib/log4j.properties",
    source => "${inc_file_path}/solr-tomcat/_usr_share_tomcat7_lib_log4j.properties",
    #require => [Exec['chown-tomcat7-usr-share-tomcatlib'],
    #            Package['tomcat7']],
    ensure => file,
    notify => Service['tomcat7'],
    owner => "tomcat7",
    group => "tomcat7",
  }

  file { 'mkdir-solr-lib':
    path => "/usr/share/solr/example/solr/lib",
    ensure => directory,
    #require => Exec['create-new-solr-core'],
    owner => "tomcat7",
    group => "tomcat7",
    mode => 0755;
  }

  file { 'mysql-connector-solr-jar':
    path => "/usr/share/solr/example/solr/lib/mysql-connector-java-5.1.26-bin.jar",
    source => "${inc_file_path}/solr-tomcat/mysql-connector-java-5.1.26-bin.jar",
    ensure => file,
    require => File['mkdir-solr-lib'],
  }

  file { 'make-data-dirs-in-collection1-core':
    path => "/usr/share/solr/example/solr/collection1/data",
    ensure => directory,
    #require => Exec['create-new-solr-core'],
    owner => "tomcat7",
    group => "tomcat7",
    mode => 0755;

  # 'make-data-dirs-in-www_django-core':
  #   path => "/usr/share/solr/example/solr/www_django/data",
  #   ensure => directory,
  #   require => Exec['create-new-solr-core'],
  #   owner => "tomcat7",
  #   group => "tomcat7",
  #   mode => 0755;

  'make-data-dirs-in-solrhome':
    path => "/usr/share/solr/example/solr/data",
    ensure => directory,
    #require => Exec['create-new-solr-core'],
    #recursive => true,
    owner => "tomcat7",
    group => "tomcat7",
    mode => 0755;

  }

  service { 'tomcat7':
    ensure => running,
    enable => true,
    require => Package['tomcat7'],
    subscribe => [File['log4jprops'],
                          File['tomcat_users_conf']],;
  }
}


class ruby {
  package { [ 'ruby', 'ruby-dev', 'libapache2-mod-ruby', 'rdoc', 'rake', 'ri', 'irb', 'libopenssl-ruby', 'libreadline-ruby', 'libmysql-ruby']:
    ensure => latest,
    require => Class['apt'],
  }
#  exec { 'install-gems':
#    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
#    user => "root",
#    command => "(
#      URL='http://production.cf.rubygems.org/rubygems/rubygems-1.3.7.tgz'
#      PACKAGE=$(echo $URL | sed \"s/\.[^\.]*$//; s/^.*\///\")
#      cd $(mktemp -d /tmp/install_rubygems.XXXXXXXXXX) && \
#      wget -c -t10 -T20 -q $URL && \
#      tar xfz $PACKAGE.tgz && \
#      cd $PACKAGE && \
#      sudo ruby setup.rb)",
#  }
}

class software {
  package { 'git':
    ensure => latest,
    require => Class['apt'],
  }

  package { 'build-essential':
    ensure => latest,
    require => Class['apt'],
  }

  package { 'nmap':
    ensure => latest,
    require => Class['apt'],
  }

}
