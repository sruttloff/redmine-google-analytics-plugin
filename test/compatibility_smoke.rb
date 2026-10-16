# Run with: bundle exec rails runner plugins/google_analytics_plugin/test/compatibility_smoke.rb
# Uses real requests against the development/test database; all writes roll back.
require 'securerandom'
require 'nokogiri'

raise 'Use development or test' unless Rails.env.development? || Rails.env.test?
STDOUT.sync = true
checks = 0
check = lambda do |condition, description|
  raise "FAIL: #{description}" unless condition
  checks += 1
  puts "PASS: #{description}"
end
original_user = User.current
original_deliveries = ActionMailer::Base.perform_deliveries
ActionMailer::Base.perform_deliveries = false

begin
  ActiveRecord::Base.transaction do
    suffix = SecureRandom.hex(6)
    password = SecureRandom.base64(24)
    users = [false, true].map do |admin|
      user = User.new(login: "analytics-smoke-#{admin}-#{suffix}", firstname: 'Analytics', lastname: 'Smoke',
                      mail: "#{admin}-#{suffix}@example.invalid", admin: admin, language: 'en',
                      status: User::STATUS_ACTIVE)
      user.password = user.password_confirmation = password
      user.save!
      user
    end
    sessions = users.map do |user|
      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.host! 'localhost'
      session.get '/login'
      token = Nokogiri::HTML(session.response.body).at_css('input[name="authenticity_token"]')['value']
      session.post '/login', params: {username: user.login, password: password, authenticity_token: token}
      check.call(session.response.redirect?, "login #{user.admin? ? 'admin' : 'member'}")
      session
    end
    member, admin = sessions
    anonymous = ActionDispatch::Integration::Session.new(Rails.application)
    anonymous.host! 'localhost'
    path = '/settings/plugin/google_analytics_plugin'
    code = '<script id="analytics-smoke">document.documentElement.dataset.analyticsSmoke = "executed";</script>'
    audiences = %w[anonymous authenticated administrator]

    [true, '1', 1, 'true'].each { |value| check.call(GoogleAnalyticsHooks.tracking_enabled?(value), "enabled #{value.inspect}") }
    [false, '0', 0, 'false', 'off', '', nil].each { |value| check.call(!GoogleAnalyticsHooks.tracking_enabled?(value), "disabled #{value.inspect}") }

    8.times do |mask|
      flags = audiences.each_with_index.to_h { |audience, i| ["google_analytics_log_#{audience}", mask[i].to_s] }
      admin.get path
      check.call(admin.response.status == 200, "settings GET mask #{mask}")
      token = Nokogiri::HTML(admin.response.body).at_css('input[name="authenticity_token"]')['value']
      admin.post path, params: {settings: flags.merge('google_analytics_code' => code), authenticity_token: token}
      check.call(admin.response.redirect?, "settings POST mask #{mask}")
      check.call(Setting.plugin_google_analytics_plugin == flags.merge('google_analytics_code' => code), "settings persist mask #{mask}")
      admin.get path
      document = Nokogiri::HTML(admin.response.body)
      # HTML4 parsing retains the initial newline that browsers strip in a textarea.
      check.call(document.at_css('textarea[name="settings[google_analytics_code]"]').text.delete_prefix("\n") == code, "snippet stays literal in editor mask #{mask}")
      audiences.each_with_index do |audience, i|
        checkbox = document.at_css("input[type=checkbox][name='settings[google_analytics_log_#{audience}]']")
        check.call(checkbox.key?('checked') == (mask[i] == 1), "checkbox #{audience} mask #{mask}")
        check.call(document.css("input[type=hidden][name='settings[google_analytics_log_#{audience}]'][value='0']").size == 1,
                   "explicit unchecked value #{audience}")
      end
      [anonymous, member, admin].each_with_index do |session, i|
        ['/', '/projects', '/issues'].each do |page|
          session.get page
          check.call(session.response.status == 200, "#{audiences[i]} #{page} renders mask #{mask}")
          document = Nokogiri::HTML(session.response.body)
          check.call(document.css('head script#analytics-smoke').size == mask[i], "#{audiences[i]} #{page} head insertion mask #{mask}")
          check.call(document.css('body script#analytics-smoke').empty?, "no body insertion #{audiences[i]} #{page} mask #{mask}")
        end
      end
    end

    [nil, ''].each do |empty|
      Setting.plugin_google_analytics_plugin = audiences.to_h { |audience| ["google_analytics_log_#{audience}", true] }.merge('google_analytics_code' => empty)
      [anonymous, member, admin].each do |session|
        session.get '/'
        check.call(session.response.status == 200 && !session.response.body.include?('id="analytics-smoke"'), "empty code #{empty.inspect}")
      end
    end
    # Old saves omit unchecked flags and store actual booleans for defaults.
    Setting.plugin_google_analytics_plugin = {'google_analytics_code' => code, 'google_analytics_log_anonymous' => true}
    [anonymous, member, admin].each_with_index do |session, i|
      session.get '/'
      check.call(Nokogiri::HTML(session.response.body).css('head script#analytics-smoke').size == (i.zero? ? 1 : 0), "legacy settings #{audiences[i]}")
    end
    member.get path
    check.call(member.response.status == 403, 'non-admin cannot read settings')
    member.get '/'
    token = Nokogiri::HTML(member.response.body).at_css('meta[name="csrf-token"]')['content']
    member.post path, params: {settings: {'google_analytics_code' => 'unauthorized'}, authenticity_token: token}
    check.call(member.response.status == 403 && Setting.plugin_google_analytics_plugin['google_analytics_code'] == code,
               'non-admin cannot change settings')
    anonymous.get path
    check.call(anonymous.response.redirect? && anonymous.response.location.include?('/login'), 'anonymous settings request requires login')

    %w[en de].each do |language|
      # Fetch a fresh record without the password setter retained by account setup.
      User.find(users.last.id).update!(language: language)
      admin.get path
      form = Nokogiri::HTML(admin.response.body).at_css('#settings')
      label = language == 'de' ? 'Tracking-Code (inklusive Script-Tags)' : 'Tracking code (including script tags)'
      check.call(admin.response.status == 200 && form && form.text.include?(label) && !form.to_html.include?('translation missing'), "#{language} settings render")
    end
    raise ActiveRecord::Rollback
  end
ensure
  Setting.clear_cache
  User.current = original_user
  ActionMailer::Base.perform_deliveries = original_deliveries
end
puts "PASS: #{checks} checks; database changes rolled back"
