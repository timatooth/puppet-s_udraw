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

  nginx::resource::upstream { 'canvasapi':
    members => [
      'localhost:3000',
    ],
  }
  nginx::resource::upstream { 'socketio':
    members => [
      'localhost:3001',
    ],
  }

  #non https version for (we need this for verifying the ACME challenge from letsencrypt)
  nginx::resource::vhost{"non_https_$server_name":
    server_name         => [$server_name],
    www_root            => '/var/www/udrawstatic',
    location_cfg_append => { 'rewrite' => '^ https://$server_name$request_uri? permanent' }
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

  nginx::resource::location { "${name}_root":
    ensure          => present,
    ssl             => true,
    ssl_only        => true,
    vhost           => "https_$server_name",
    location        => '/',
    location_alias  => '/opt/capistrano/udraw/current/public/',
  }

  nginx::resource::location { "${name}_canvasapi":
    ensure          => present,
    ssl             => true,
    ssl_only        => true,
    vhost           => "https_$server_name",
    location        => '/canvases/',
    proxy           => 'canvasapi',
  }

  nginx::resource::location { "${name}_socketio":
    ensure          => present,
    ssl             => true,
    ssl_only        => true,
    vhost           => "https_$server_name",
    location        => '/socket.io/',
    proxy           => 'socketio',
    location_cfg_append => {
      proxy_set_header   => 'Upgrade $http_upgrade',
      proxy_set_header   => 'Connection "upgrade"',
      proxy_set_header   => 'X-Forwarded-For $proxy_add_x_forwarded_for',
      proxy_set_header   => 'Host $host',
      proxy_http_version => '1.1',
    }
  }

  include ::s_udraw::app
}
