class s_udraw::app {

  class { 'nodejs':
    repo_url_suffix => '6.x',
  }

  package {'redis-server':
    ensure => present,
  }

  package {'supervisor':
    ensure => present,
  }

  include ::datadog_agent::integrations::redis
  include ::datadog_agent::integrations::supervisor
}
