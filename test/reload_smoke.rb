# Run with: bundle exec rails runner plugins/google_analytics_plugin/test/reload_smoke.rb
# Isolate this plugin so unrelated plugins' reload behavior does not affect the check.
raise 'Use development or test' unless Rails.env.development? || Rails.env.test?
STDOUT.sync = true
Redmine::PluginLoader.singleton_class.prepend(Module.new do
  def directories
    super.select { |directory| File.basename(directory.to_s) == 'google_analytics_plugin' }
  end
end)

3.times do |iteration|
  Rails.application.reloader.reload!
  listeners = Redmine::Hook.listeners.select { |listener| listener.class.name == 'GoogleAnalyticsHooks' }
  raise "Expected one listener, got #{listeners.size}" unless listeners.size == 1
  raise 'Stale listener class' unless listeners.first.is_a?(GoogleAnalyticsHooks)
  raise 'Hook unavailable' unless Redmine::Hook.hook_listeners(:view_layouts_base_html_head).include?(listeners.first)
  raise 'Boolean conversion unavailable' unless GoogleAnalyticsHooks.tracking_enabled?('1') && !GoogleAnalyticsHooks.tracking_enabled?('0')
  puts "PASS: reload #{iteration + 1}: exactly one current hook listener and working settings conversion"
end
