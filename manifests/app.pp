class s_udraw::app {

  class { 'nodejs':
    repo_url_suffix => '6.x',
  }

  ensure_packages(['redis-server'])

  file {'/etc/systemd/system/udraw.service':
    ensure  => file,
    mode    => '0644',
    content => template('s_udraw/udraw.service.erb'),
  }
  include ::datadog_agent::integrations::redis
}
