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

    def self.lookup_block?(ip)
      ipinfo = DiscourseIpInfo.get(ip)
      return false unless ipinfo && ipinfo[:asn]

      if SiteSetting.geo_blocking_asn_blocklist.split("|").include?("AS#{ipinfo[:asn]}")
        Rails.logger.warn "Geo-blocking IP #{ip} because it is in network AS#{ipinfo[:asn]}" if SiteSetting.geo_blocking_log_blocked
        return "network AS-#{ipinfo[:asn]}"
      end

      crlist = SiteSetting.geo_blocking_country_region_blocklist.split("|")
      if crlist.include?(ipinfo[:country]) || crlist.include?(ipinfo[:country_code])
        Rails.logger.warn "Geo-blocking IP #{ip} because it is in country #{ipinfo[:country]}" if SiteSetting.geo_blocking_log_blocked
        return "#{ipinfo[:country]}"
      end

      if crlist.include?("#{ipinfo[:country]}.#{ipinfo[:region]}")
        Rails.logger.warn "Geo-blocking IP #{ip} because it is in region #{ipinfo[:country]}.#{ipinfo[:region]}" if SiteSetting.geo_blocking_log_blocked
        return "#{ipinfo[:region]}, #{ipinfo[:country]}"
      end

      Rails.logger.warn "Not geo-blocking IP #{ip} - network: AS#{ipinfo[:asn]}, country: #{ipinfo[:country]} (#{ipinfo[:country_code]}), region: #{ipinfo[:region]}" if SiteSetting.geo_blocking_log_allowed
      return false
    end

  end
end