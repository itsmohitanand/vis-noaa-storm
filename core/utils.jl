using Dates



function remove_missing_loc(storm_data)
    valid_ind = .!(ismissing.(storm_data.BEGIN_LAT) .& ismissing.(storm_data.END_LAT) .& ismissing.(storm_data.BEGIN_LON) .& ismissing.(storm_data.END_LON))
    return storm_data[valid_ind, :]
end

function noaa_replace_datetime(noaa_storm_details)

    @warn "Timezones not accounted here and can lead to inaccuracy"
    @warn "Adding 2000 to years manually"

    #TODO - Harmonise Time Zones
    #TODO - Automatic Years

    begin_date_time = Dates.DateTime.(noaa_storm_details.BEGIN_DATE_TIME, "d-u-Y HH:MM:SS") .+Dates.Year(2000)
    end_date_time = Dates.DateTime.(noaa_storm_details.END_DATE_TIME, "d-u-Y HH:MM:SS").+Dates.Year(2000)
    


    noaa_storm_details.begin_time = begin_date_time
    noaa_storm_details.end_time = end_date_time
    
    select!(noaa_storm_details, Not([:BEGIN_DATE_TIME, :END_DATE_TIME]))

    return noaa_storm_details
end

function damage_number(damage)
    dmg = map(damage) do x
        if ismissing(x)
            return convert(Float64, -1.0)
        elseif string(x[end]) == "K"
            return parse(Float64, x[1:end-1])*1000
        elseif string(x[end]) == "M" 
            return parse(Float64, x[1:end-1])*1000000
        elseif string(x[end]) == "B" 
            return parse(Float64, x[1:end-1])*1000000000
        elseif x == ""
            return convert(Float64, -1.0)
        else
            return parse(Float64, x)
        end
    end

    return Float64.(dmg)
end

function noaa_add_damage(noaa_storm_details)
    dmg_prop = damage_number(noaa_storm_details.DAMAGE_PROPERTY)
    noaa_storm_details.damage_property = dmg_prop

    dmg_crop = damage_number(noaa_storm_details.DAMAGE_CROPS)
    noaa_storm_details.damage_crops = dmg_crop
    
    select!(noaa_storm_details, Not([:DAMAGE_PROPERTY, :DAMAGE_CROPS]))

    index = (dmg_crop .>-1) .& (dmg_prop.>-1)
    noaa_storm_details = noaa_storm_details[index, :]
    index = (noaa_storm_details.damage_crops .>0) .|| (noaa_storm_details.damage_property.>0)

    return noaa_storm_details[index, :]
end

function noaa_add_center(noaa_storm_details)
    noaa_storm_details.lat_center = (noaa_storm_details.BEGIN_LAT .+ noaa_storm_details.END_LAT)./2
    noaa_storm_details.lon_center = (noaa_storm_details.BEGIN_LON .+ noaa_storm_details.END_LON)./2
    
    noaa_storm_details = noaa_storm_details[.!ismissing.(noaa_storm_details.lon_center), :]

    noaa_storm_details = noaa_storm_details[.!ismissing.(noaa_storm_details.lat_center), :]

    noaa_storm_details.lon_center = Float64.(noaa_storm_details.lon_center)
    noaa_storm_details.lat_center = Float64.(noaa_storm_details.lat_center)

    return noaa_storm_details
end



function remove_cols(noaa_storm_details)
    remove_col = [:STATE_FIPS, :EVENT_ID, :EPISODE_ID, :CZ_TYPE, 
                    :CZ_FIPS, :WFO, :CZ_NAME, :MAGNITUDE, :MAGNITUDE_TYPE, 
                    :CATEGORY, :TOR_F_SCALE, :TOR_LENGTH, :TOR_WIDTH, :TOR_OTHER_WFO,
                    :TOR_OTHER_CZ_STATE, :TOR_OTHER_CZ_FIPS,:BEGIN_YEARMONTH, :BEGIN_DAY, 
                    :BEGIN_TIME, :END_YEARMONTH, :END_DAY, :END_TIME, :BEGIN_LOCATION, :END_LOCATION,
                    :BEGIN_RANGE, :END_RANGE, :BEGIN_AZIMUTH, :END_AZIMUTH, :YEAR, :MONTH_NAME ,
                    :TOR_OTHER_CZ_NAME]

    return select!(noaa_storm_details, Not(remove_col))
end


function process_details(noaa_storm_details)
    noaa_storm_details = remove_cols(noaa_storm_details)
    noaa_storm_details = noaa_add_damage(noaa_storm_details)
    noaa_storm_details = noaa_add_center(noaa_storm_details)
    noaa_storm_details = noaa_replace_datetime(noaa_storm_details)
    return noaa_storm_details
end

function get_details(year::Int)
    noaa_storm_details = read_details(year)
    return process_details(noaa_storm_details)
end

function get_details(list_year::Array)
    
    init_year = get_details(list_year[1])                    

    for i=2:length(list_year)        
        year = get_details(list_year[i])
        init_year = vcat(init_year, year)
    end
    return init_year
end