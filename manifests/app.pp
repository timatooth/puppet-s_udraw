class s_udraw::app {

  class { 'nodejs':
    repo_url_suffix => '6.x',
  }

  ensure_packages(['redis-server', 'supervisor'])

  service {'supervisor':
    enable  => true,
    ensure  => running,
    require => Package['supervisor'],
  }

  file {'/etc/supervisor/supervisord.conf':
    ensure  => file,
    content => template('s_udraw/supervisord.conf.erb'),
    notify  => Service['supervisor']
  }

  include ::datadog_agent::integrations::redis

  class { ::datadog_agent::integrations::supervisord:
    instances => [{servername => $::hostname, socket => 'unix:///var/run//supervisor.sock'}],
  }
}
