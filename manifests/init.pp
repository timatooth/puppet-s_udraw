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

  class { ::letsencrypt:
    email => 'nztims@gmail.com',
  }

  letsencrypt::certonly { 'capi.udraw.me':
    plugin        => 'webroot',
    webroot_paths => ['/var/www/udrawstatic'],
    manage_cron   => true,
    cron_success_command => '/bin/systemctl reload nginx.service',
    require       => [File['/var/www/udrawstatic']],
  }

  nginx::resource::vhost{'capi.udraw.me':
    www_root => '/var/www/udrawstatic',
    ssl      => true,
    ssl_cert => '/etc/letsencrypt/live/capi.udraw.me/fullchain.pem',
    ssl_key  => '/etc/letsencrypt/live/capi.udraw.me/privkey.pem',
    require  => [letsencrypt::certonly['capi.udraw.me']],
  }
}
