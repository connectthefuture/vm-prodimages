
node 'precise32' {
    package { 'nginx':
        ensure => installed,
    }
    package {}
}
