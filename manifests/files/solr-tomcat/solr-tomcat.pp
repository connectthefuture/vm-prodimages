class solr-tomcat {
  package {'tomcat6':
    ensure => latest,
    require => Class['apt'];
  
  'tomcat6-admin':
    ensure => latest,
    require => Class['apt'];

  'tomcat6-examples':
    ensure => latest,
    require => Class['apt'];

  'openjdk-7-jdk':
    ensure => latest,
    require => Class['apt'],;
  }

  file { 'tomcat6-default-start':
    path => "/etc/default/tomcat6",
    source => "${inc_file_path}/solr-tomcat/tomcat6",
    #before => Service['tomcat6'],
    ensure => directory,
    notify => Service["tomcat6"],
    require => Package['tomcat6'],
    owner => "root",
    group => "root";
  
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
    require => Package['tomcat6'],
    owner => "tomcat6",
    group => "tomcat6";

  'solr_solrconfig_conf':
    path => "/opt/solr/example/solr/collection1/conf/solrconfig.xml",
    source => "${inc_file_path}/solr-tomcat/solrconfig.xml",
    require => [Exec['chown-solr-dirs'],
                Package['tomcat6']],
    ensure => directory,
    notify => Service['tomcat6'],
    owner => "tomcat6",
    group => "tomcat6";

  'solr_schema_conf':
    path => "/opt/solr/example/solr/collection1/conf/schema.xml",
    source => "${inc_file_path}/solr-tomcat/schema.xml",
    require => [Exec['chown-solr-dirs'],
                Package['tomcat6']],
    ensure => directory,
    notify => Service['tomcat6'],
    owner => "tomcat6",
    group => "tomcat6";

  'solr_dbdataconfig_conf':
    path => "/opt/solr/example/solr/collection1/conf/db-data-config.xml",
    source => "${inc_file_path}/solr-tomcat/db-data-config.xml",
    require => [Exec['chown-solr-dirs'],
                Package['tomcat6']],
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
    require => File['/opt/solr'],
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
    require => [File['/opt/solr'],
                Exec['download-solr']],
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    user => "root",
    cwd => "/opt/solr",
    command => "tar xvzf /opt/solr/solr.tgz -C /opt/solr/ && ;";
  
  'copy-solr-files-tomcat6':
    require => Exec['unpack-solr'],
    before => Service['tomcat6'],
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    user => "root",
    cwd => "/opt/solr",
    command => "sudo cp -rf /opt/solr/solr-4.6.0/* /opt/solr;";

  'create-new-solr-core':
    require => Exec['copy-solr-files-tomcat6'],
    before => Service['tomcat6'],
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    user => "root",
    cwd => "/opt/solr",
    command => "sudo cp -rf /opt/solr/example/solr/collection1 /opt/solr/example/solr/www_django";
  
  'chown-solr-dirs':
    user => "root",
    require => [Exec['copy-solr-files-tomcat6'], 
                File['add-core-solrxml']],
    before => Service['tomcat6'],
    path => "/usr/bin:/usr/sbin:/bin:/usr/local/bin",
    cwd => "/opt/solr",
    command => "sudo chown -R tomcat6:tomcat6 /opt/solr/";
  }

  service { 'tomcat6':
    ensure => running,
    enable => true,
    require => Package['tomcat6'],
    #subscribe => Exec["copy-solr-files-tomcat6"],
  }
}