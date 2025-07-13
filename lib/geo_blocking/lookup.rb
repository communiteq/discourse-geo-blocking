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
      @reason =
        Rails
          .cache
          .fetch("geoblocking-moderate/#{version}/#{ip}", expires_in: 24.hours) do
            lookup_moderate?(ip)
          end

      @reason
    end

    def self.lookup(ip, configuration)
      ipinfo = DiscourseIpInfo.get(ip)
      return false unless ipinfo && ipinfo[:asn]

      if configuration == 'block'
        asn_blocklist = SiteSetting.get_blocking_asn_blocklist
        log_blocked = SiteSetting.get_blocking_log_blocked
        country_region_blocklist = SiteSetting.geo_blocking_country_region_blocklist
        action = 'blocking'
        log_allowed = SiteSetting.geo_blocking_log_allowed
      elsif configuration == 'moderate'
        asn_blocklist = SiteSetting.get_moderating_asn_blocklist
        log_blocked = SiteSetting.get_moderating_log_blocked
        country_region_blocklist = SiteSetting.geo_moderating_country_region_blocklist
        action = 'moderating'
        log_allowed = SiteSetting.geo_moderating_log_allowed
      else
        return false
      end

      if asn_blocklist.split("|").include?("AS#{ipinfo[:asn]}")
        if log_blocked
          Rails.logger.warn "Geo-#{action} IP #{ip} because it is in network AS#{ipinfo[:asn]}"
        end
        return "network AS-#{ipinfo[:asn]}"
      end

      crlist = country_region_blocklist.split("|")
      if crlist.include?(ipinfo[:country]) || crlist.include?(ipinfo[:country_code])
        if log_blocked
          Rails.logger.warn "Geo-#{action} IP #{ip} because it is in country #{ipinfo[:country]}"
        end
        return "#{ipinfo[:country]}"
      end

      if crlist.include?("#{ipinfo[:country]}.#{ipinfo[:region]}")
        if log_blocked
          Rails.logger.warn "Geo-#{action} IP #{ip} because it is in region #{ipinfo[:country]}.#{ipinfo[:region]}"
        end
        return "#{ipinfo[:region]}, #{ipinfo[:country]}"
      end

      if log_allowed
        Rails.logger.warn "Not geo-#{action} IP #{ip} - network: AS#{ipinfo[:asn]}, country: #{ipinfo[:country]} (#{ipinfo[:country_code]}), region: #{ipinfo[:region]}"
      end
      return false
    end

    def self.lookup_moderate?(ip)
      lookup(ip, 'moderate')
    end

    def self.lookup_block?(ip)
      lookup(ip, 'block')
    end
  end
end
