# name: discourse-geo-blocking
# version: 1.0.1
# authors: Communiteq
# about: Block access to Discourse based on geographic region or ASN network number
# url: https://www.github.com/communiteq/discourse-geo-blocking

enabled_site_setting :geo_blocking_enabled

load File.expand_path('lib/geo_blocking/lookup.rb', __dir__)

after_initialize do
  ::ActionController::Base.prepend_view_path File.expand_path('../app/views', __FILE__)

  ApplicationController.class_eval do
    alias_method :_old_rescue_discourse_actions, :rescue_discourse_actions

    DiscourseEvent.on(:site_setting_changed) do |name|
      if [:geo_blocking_asn_blocklist, :geo_blocking_country_region_blocklist].include? name
        SiteSetting.geo_blocking_cache_version  = SiteSetting.geo_blocking_cache_version + 1
      end
    end

    def rescue_discourse_actions(type, status_code, opts = nil)
      if SiteSetting.geo_blocking_enabled
        @hide_content = (status_code == 451)
      end
      _old_rescue_discourse_actions(type, status_code, opts)
    end
  end

  User.register_custom_field_type("last_ip_address", :string)

  module ::DiscourseForceModeration
    def post_needs_approval?(manager)
      superResult = super
      return superResult if ((!(SiteSetting.geo_blocking_enabled)) || (superResult != :skip))

      reason = ::GeoBlocking::Lookup.is_moderated?(manager.user.custom_fields["last_ip_address"])
      return unless reason

      :skip
    end
  end

  NewPostManager.singleton_class.prepend ::DiscourseForceModeration

  add_model_callback(:application_controller, :before_action) do
    return unless SiteSetting.geo_blocking_enabled
    return if request.fullpath.start_with?("/admin/", "/message-bus/", "/theme-javascripts/", "/stylesheets/", "/letter_avatar_proxy/", "/svg-sprite/", "/extra-locales/")

    ip = request.env["HTTP_X_REAL_IP"] || request.env["REMOTE_ADDR"]

    user = current_user
    user.custom_fields["last_ip_address"] = ip
    user.save_custom_fields(true)

    reason = ::GeoBlocking::Lookup.is_blocked?(ip)
    return unless reason

    if SiteSetting.geo_blocking_detailed_reason
      rescue_discourse_actions(:unavailable, 451, {custom_message: "geo_blocking.error_451_detailed",  custom_message_params: { reason: reason }})
    else
      rescue_discourse_actions(:unavailable, 451, {custom_message: "geo_blocking.error_451" })
    end
  end
end
