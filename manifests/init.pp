class s_udraw {

  class{'nginx':
    manage_repo => true,
    package_source => 'nginx-mainline'
  }

  file {'/var/www':
    ensure => directory,
  } ->
  file {'/var/www/udrawstatic':
    ensure => directory,
  } ->
  file {'/var/www/udrawstatic/index.html':
    ensure  => file,
    content => template('s_udraw/index.html.erb')
  }

  nginx::resource::vhost{'capi.udraw.me':
    www_root => '/var/www/udrawstatic',
  }
}
