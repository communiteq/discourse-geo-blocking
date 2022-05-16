# discourse-geo-blocking

Geo blocking plugin for Discourse forum software.

This can be used to completely block access for certain countries or networks, for for example fraud prevention or to comply with sanctions.

## Installation

[Like usual.](https://meta.discourse.org/t/install-plugins-in-discourse/19157)

## Usage

* Go to Admin -> Settings -> Plugins
* Enable the plugin
* Add all networks you want to block to `geo_blocking_asn_blocklist`. Prefix the numbers with AS, so for example `AS12345`.
* Add all countries and regions you want to block to `geo_blocking_country_region_blocklist`. The following formats are accepted:
  * Full country name (for example: `Belgium`)
  * Country ISO code (for example: `JP` for Japan)
  * Full country name followed by a dot and then the region name (for example: `Switzerland.Jura`).

* If you enable `geo blocking detailed reason` then the error message will contain the country/region or network that caused the user to be blocked.
* To test the plugin you can check `geo blocking log blocked` and/or `geo blocking log allowed` and inspect the `/logs` on your forum.

For a full list of supported countries and regions, see [list_of_countries_and_regions.txt](https://github.com/communiteq/discourse-geo-blocking/blob/master/list_of_countries_and_regions.txt).

## Attention and Caveats

If anonymous visitors are being blocked, they could still get a cached version of the home page for around one minute.

The error page does not contain "Popular" and "Recent" topics because that would leak content to a blocked user.

## License

GPL v2