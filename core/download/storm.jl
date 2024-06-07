using HTTP
using JSON3

NOAA_STORMEVENTS_HTPP = "https://www.ncei.noaa.gov/pub/data/swdi/stormevents/csvfiles/";

# fname = HTTP.request("GET", NOAA_STORMEVENTS_HTPP)
# body = String(fname.body)

# x = findfirst(body, "<a href=")

# print(x)

# function get_file_names(url)

# end

# function download_event_details_year(year)
#     version = "v1.0"
#     fname = NOAA_STORMEVENTS_HTPP * "StormEvents_details-ftp_v1.0_d$(year)_

# end