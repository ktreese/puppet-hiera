# == Class hiera::eyaml_gpg
#
# This calss install and configures hiera-eyaml-gpg
#
class hiera::eyaml_gpg (
  $provider         = $hiera::params::provider,
  $owner            = $hiera::owner,
  $group            = $hiera::group,
  $confdir          = $hiera::confdir,
  $cmdpath          = $hiera::cmdpath,
  $eyaml_gpg_keygen = $hiera::eyaml_gpg_keygen,
) inherits hiera::params {

  require hiera::eyaml

  package { 'ruby_gpg':
    ensure   => installed,
    provider => $provider,
    before   => Package['hiera-eyaml-gpg'],
  }

  package { 'hiera-eyaml-gpg':
    ensure   => installed,
    provider => $provider,
  }

  file { "${confdir}/keys/gpg":
    ensure => directory,
    owner  => $owner,
    group  => $group,
    mode   => '0700'
  }

  # Currently only works for RedHat based machines, until gnupg packages in params is updated
  if $eyaml_gpg_keygen and $::osfamily == 'RedHat' {

    package { 'rng-tools':
      ensure => 'present',
    }

    file_line { 'rngd-sysconfig':
      path  => '/etc/sysconfig/rngd',
      line  => 'EXTRAOPTIONS="-r /dev/urandom -o /dev/random -t 5"',
      match => '^EXTRAOPTIONS=""',
    }

    service { 'rngd':
      ensure  => 'running',
      enable  => true,
      require => [ Package['rng-tools'], File_line['rngd-sysconfig'] ],
    }

    file { "${confdir}/keys/gpg/gpg_answers":
      ensure  => present,
      owner   => $owner,
      group   => $group,
      mode    => '0700',
      content => template('hiera/gpg_answers.erb'),
      before  => Exec['gpg_genkeys'],
    }

    package { $hiera::params::gnupg_package:
      ensure => installed,
    }

    exec { 'gpg_genkeys':
      user    => $owner,
      cwd     => $confdir,
      path    => $cmdpath,
      command => "gpg --batch --homedir ${confdir}/keys/gpg --gen-key ${confdir}/keys/gpg/gpg_answers",
      creates => "${confdir}/keys/gpg/pubring.gpg",
      require => [ Package[$hiera::params::gnupg_package], Service['rngd'], ],
    }

    $gpg_files = [ "${confdir}/keys/gpg/pubring.gpg", "${confdir}/keys/gpg/pubring.gpg~", "${confdir}/keys/gpg/random_seed", "${confdir}/keys/gpg/secring.gpg", "${confdir}/keys/gpg/trustdb.gpg" ]

    file { $gpg_files:
      ensure  => file,
      mode    => '0600',
      owner   => $owner,
      group   => $group,
      require => Exec['gpg_genkeys'],
    }

  }

}
