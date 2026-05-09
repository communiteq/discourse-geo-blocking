# frozen_string_literal: true

module GeoBlocking
  class Lookup
    def self.is_blocked?(ip)
      version = SiteSetting.geo_blocking_cache_version
      @reason = Rails.cache.fetch("geoblocking/#{version}/#{ip}", expires_in: 24.hours) do
        lookup_block?(ip)
      end

      @reason
    end

    def self.is_moderated?(ip)
      version = SiteSetting.geo_blocking_cache_version
      @reason = Rails.cache.fetch("geoblocking-moderate/#{version}/#{ip}", expires_in: 24.hours) do
        lookup_moderate?(ip)
      end

      @reason
    end

    def self.lookup(ip, configuration)
      ipinfo = DiscourseIpInfo.get(ip)
      return false unless ipinfo && ipinfo[:asn]

      if configuration == 'block'
        asn_blocklist = SiteSetting.geo_blocking_asn_blocklist
        log_blocked = SiteSetting.geo_blocking_log_blocked
        country_region_blocklist = SiteSetting.geo_blocking_country_region_blocklist
        ip_whitelist = SiteSetting.geo_blocking_ip_whitelist
        country_region_allowlist = SiteSetting.geo_blocking_country_region_allowlist
        ip_blacklist = SiteSetting.geo_blocking_ip_blacklist
        action = 'blocking'
        log_allowed = SiteSetting.geo_blocking_log_allowed
      elsif configuration == 'moderate'
        asn_blocklist = SiteSetting.geo_moderating_asn_blocklist
        log_blocked = SiteSetting.geo_moderating_log_blocked
        country_region_blocklist = SiteSetting.geo_moderating_country_region_blocklist
        ip_whitelist = SiteSetting.geo_moderating_ip_whitelist
        ip_blacklist = SiteSetting.geo_moderating_ip_blacklist
        country_region_allowlist = SiteSetting.geo_moderating_country_region_allowlist
        action = 'moderating'
        log_allowed = SiteSetting.geo_moderating_log_allowed
      else
        return false
      end

      if asn_blocklist.split("|").include?("AS#{ipinfo[:asn]}")
        Rails.logger.warn "Geo-#{action} IP #{ip} because it is in network AS#{ipinfo[:asn]}" if log_blocked
        return "network AS-#{ipinfo[:asn]}"
      end

      if country_region_allowlist.present?
        if ip_blacklist.split("|").include?(ip)
          Rails.logger.warn "Geo-#{action} IP #{ip} because it is in IP blacklist #{ip_blacklist}" if log_blocked
          return "#{ip}"
        end

        cr_allowlist = country_region_allowlist.split("|")
        if cr_allowlist.include?(ipinfo[:country]) || cr_allowlist.include?(ipinfo[:country_code])
          return false
        end

        if cr_allowlist.include?("#{ipinfo[:country]}.#{ipinfo[:region]}")
          return false
        end

        Rails.logger.warn "Geo-#{action} IP #{ip} (#{ipinfo[:region]} / #{ipinfo[:country]} / #{ipinfo[:country_code]}) because it is not in #{country_region_allowlist}" if log_blocked
        if ipinfo[:region]
          return "#{ipinfo[:region]}, #{ipinfo[:country]}"
        end
        return "#{ipinfo[:country]}"
      end

      if ip_whitelist.split("|").include?(ip)
        return false
      end

      crlist = country_region_blocklist.split("|")
      if crlist.include?(ipinfo[:country]) || crlist.include?(ipinfo[:country_code])
        Rails.logger.warn "Geo-#{action} IP #{ip} because it is in country #{ipinfo[:country]}" if log_blocked
        return "#{ipinfo[:country]}"
      end

      if crlist.include?("#{ipinfo[:country]}.#{ipinfo[:region]}")
        Rails.logger.warn "Geo-#{action} IP #{ip} because it is in region #{ipinfo[:country]}.#{ipinfo[:region]}" if log_blocked
        return "#{ipinfo[:region]}, #{ipinfo[:country]}"
      end

      Rails.logger.warn "Not geo-#{action} IP #{ip} - network: AS#{ipinfo[:asn]}, country: #{ipinfo[:country]} (#{ipinfo[:country_code]}), region: #{ipinfo[:region]}" if log_allowed
      false
    end

    def self.lookup_moderate?(ip)
      lookup(ip, 'moderate')
    end

    def self.lookup_block?(ip)
      lookup(ip, 'block')
    end
  end
end
