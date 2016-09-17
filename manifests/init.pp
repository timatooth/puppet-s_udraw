class s_udraw($server_name = undef) {
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
    config => {
      email => 'nztims@gmail.com',
    }
  }

  letsencrypt::certonly { $server_name:
    plugin               => 'webroot',
    webroot_paths        => ['/var/www/udrawstatic'],
    manage_cron          => true,
    cron_success_command => '/bin/systemctl reload nginx.service',
    require              => [Nginx::Resource::Vhost["non_https_${server_name}"]],
  }

  #non https version for (we need this for verifying the ACME challenge from letsencrypt)
  nginx::resource::vhost{"non_https_$server_name":
    server_name => [$server_name],
    www_root    => '/var/www/udrawstatic',
  }

  nginx::resource::vhost{"https_$server_name":
    server_name => [$server_name],
    www_root    => '/var/www/udrawstatic',
    ssl         => true,
    ssl_port    => 443,
    listen_port => 443,
    ssl_cert    => "/etc/letsencrypt/live/${server_name}/fullchain.pem",
    ssl_key     => "/etc/letsencrypt/live/${server_name}/privkey.pem",
    require     => Letsencrypt::Certonly[$server_name],
  }

  include ::s_udraw::app
}
