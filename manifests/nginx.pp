class s_udraw::nginx($server_name = undef) {
  class {'nginx':
    manage_repo    => true,
    package_source => 'nginx-mainline'
  }

  file {['/var/www', '/var/www/udrawstatic']:
    ensure => directory,
  }

  class { 'letsencrypt':
    install_method => 'vcs',
    config         => {
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
  nginx::resource::vhost{"non_https_${server_name}":
    server_name         => [$server_name],
    www_root            => '/var/www/udrawstatic',
    notify              => Service['nginx'],
    # Send all http requets to the https listener
    # an exception must be made for Certbot/letsencrypt which needs to access
    # the /.welll-known path for doing host validation.
    location_cfg_append => {
      'rewrite' => '^ https://$server_name$request_uri? permanent',
    }
  }

  # Create a path exception for the (non ssl) server to allow letsencrypt
  # rather than sending it a 301 to https://
  nginx::resource::location{'allow_letsencrypt_wellknown_path':
    vhost    => "non_https_${server_name}",
    location => '/.well-known',
    www_root => '/var/www/udrawstatic'
  }

  nginx::resource::vhost{"https_${server_name}":
    server_name => [$server_name],
    www_root    => '/opt/udraw/current/public/',
    add_header  => {
      'Strict-Transport-Security' => '"max-age=31536000; includeSubDomains" always',
    },
    http2       => 'on',
    ssl         => true,
    ssl_port    => 443,
    listen_port => 443,
    ssl_cert    => "/etc/letsencrypt/live/${server_name}/fullchain.pem",
    ssl_key     => "/etc/letsencrypt/live/${server_name}/privkey.pem",
    require     => Letsencrypt::Certonly[$server_name],
  }

  nginx::resource::location { "${name}_canvasapi":
    ensure   => present,
    ssl_only => true,
    vhost    => "https_${server_name}",
    location => '/canvases/',
    proxy    => 'http://canvasapi',
  }

  nginx::resource::location { "${name}_socketio":
    ensure              => present,
    ssl_only            => true,
    vhost               => "https_${server_name}",
    location            => '/socket.io/',
    proxy               => 'http://socketio',
    location_cfg_append => {
      proxy_http_version => '1.1',
    },
    raw_append          => [
      'proxy_set_header Upgrade $http_upgrade;',
      'proxy_set_header Connection "upgrade";'
    ]
  }
}