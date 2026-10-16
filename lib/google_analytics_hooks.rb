# This class hooks into Redmine's View Listeners in order to
# add content to the page
class GoogleAnalyticsHooks < Redmine::Hook::ViewListener

  # Settings from HTML forms use strings; older installations use booleans.
  def self.tracking_enabled?(value)
    ActiveModel::Type::Boolean.new.cast(value) == true
  end

  # Adds the Google Analytics code to the layout if the current user meets
  # the conditions setup by the System Administrator
  def view_layouts_base_html_head(context = { })
    settings = Setting.plugin_google_analytics_plugin
    user = User.current
    audience = if user.anonymous?
                 'anonymous'
               elsif user.admin?
                 'administrator'
               else
                 'authenticated'
               end

    return '' unless self.class.tracking_enabled?(settings["google_analytics_log_#{audience}"])

    settings['google_analytics_code'].to_s
  end
end
