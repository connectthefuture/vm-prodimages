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
    command => "wget http://download.redis.io/redis-stable.tar.gz && tar -xvzf redis-stable.tar.gz && cd redis-stable && make;",
    cwd => "/root",
    user => "root",
    before => Package['install-redis'],
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

##redis closing brace
}

class tomcat7-solr {
    package { 'tomcat7':
    ensure => latest,
    require => Class['apt'],;
  
  'tomcat7-admin':
    ensure => latest,
    require => Class['apt'],;

  'tomcat7-examples':
    ensure => latest,
    require => Class['apt'],;

  'openjdk-7-jdk':
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
                Exec['chown-solr-dirs'],
                Exec['unpack-solr']],
    ensure => directory,
    notify => Service['tomcat7'],
    owner => "tomcat7",
    group => "tomcat7";

  'solr_schema_conf':
    path => "/user/share/solr/example/solr/collection1/conf/schema.xml",
    source => "${inc_file_path}/solr-tomcat/schema.xml",
    require => [Package['tomcat7'],
                Exec['chown-solr-dirs'],
                Exec['unpack-solr']],
    ensure => directory,
    notify => Service['tomcat7'],
    owner => "tomcat7",
    group => "tomcat7";

  'solr_dbdataconfig_conf':
    path => "/user/share/solr/example/solr/collection1/conf/db-data-config.xml",
    source => "${inc_file_path}/solr-tomcat/db-data-config.xml",
    require => [Package['tomcat7'],
                Exec['chown-solr-dirs'],
                Exec['unpack-solr']],
    ensure => directory,
    notify => Service['tomcat7'],
    owner => "tomcat7",
    group => "tomcat7";

  'tomcat_users_conf':
    path => "/etc/tomcat7/tomcat-users.xml",
    source => "${inc_file_path}/solr-tomcat/_etc_tomcat7_tomcat-users.xml",
    require => [Exec['chown-solr-dirs'],
                Package['tomcat7']],
    ensure => directory,
    notify => Service['tomcat7'],
    owner => "root",
    group => "tomcat7";
  }
  

  file { 'log4jprops':
    path => "/usr/share/tomcat7/lib/log4j.properties",
    source => "${inc_file_path}/solr-tomcat/_usr_share_tomcat7_lib_log4j.properties",
    require => [Exec['chown-tomcat7-usr-share-tomcatlib'],
                Package['tomcat7']],
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

  file {'mysql-connector-solr-jar': 
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
    require => Exec['create-new-solr-core'],
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