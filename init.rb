require 'redmine'

# Use Zeitwerk's constant autoloading; plugin lib paths are not on $LOAD_PATH.
# Re-register the listener if Redmine's hook registry was reloaded.
hooks = GoogleAnalyticsHooks
unless Redmine::Hook.listeners.any? { |listener| listener.is_a?(hooks) }
  Redmine::Hook.add_listener(hooks)
end

Redmine::Plugin.register :google_analytics_plugin do
  name 'Google Analytics plugin'
  author 'Eric Davis, Raphael Kallensee, Tobias Fischer; SaaS-Secure.com, S. Ruttloff'
  author_url 'https://www.saas-secure.com/'
  description 'Insert Google Analytics, Matomo or other tracking snippets for anonymous users, signed-in users and administrators.'
  url 'https://github.com/sruttloff/redmine-google-analytics-plugin'
  version '1.1.0'

  requires_redmine :version_or_higher => '6.1.0'

  settings :default => {
    'google_analytics_code' => '',
    'google_analytics_log_anonymous' => true,
    'google_analytics_log_authenticated' => true,
    'google_analytics_log_administrator' => true
  }, :partial => 'google_analytics_settings'

end
