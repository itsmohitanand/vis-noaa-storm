using CSV
using DataFrames
using GLMakie
using Shapefile
using Rasters
using Dates
using Observables
using StatsBase
using LinearAlgebra
using ColorSchemes


palette = ColorSchemes.tol_light

storm_data = CSV.File("data/processed_details_2010_2024.gzip") |> DataFrame

data = Shapefile.Table("data/cb_2018_us_state_20m/cb_2018_us_state_20m.shp")

remove_state = ["Alaska", "Hawaii", "Puerto Rico", "District of Columbia"]
state_name = [n for n in data.NAME if !(n in remove_state)]

# ----------------------- Define Axis, Menu and Slider ----------------------- #
f = Figure(resolution=(1400, 1800))
menu = Menu(f[1, 13:16], options=state_name, default="California")

rticks = [0:30:359;] * 2 * pi / 360
ax_map = Axis(f[1:9, 1:12], title="Damaging over storms between 2010-2024 N=$(size(storm_data)[1])", xgridvisible = false, ygridvisible = false)
ax_state = Axis(f[10:13, 1:6], xgridvisible = false, ygridvisible = false)
ax_occurrence = PolarAxis(f[10:13, 7:12],
    thetaticks=(rticks, ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]),
    rticks=([10, 20], ["10%", "20%"])
)
ax_damage_crop = Axis(f[14:16, 1:6], xgridvisible = false, ygridvisible = false, ylabel = "Million Dollars", xlabel = "Year")
ax_damage_property = Axis(f[14:16, 7:12], xgridvisible = false, ygridvisible = false, ylabel = "Million Dollars", xlabel = "Year")

year_slider = IntervalSlider(f[3, 13:16], range=[2010:2024;], startvalues=(2010, 2024))
crop_dmg_slider = IntervalSlider(f[5, 13:16], range=[0, 1000, 10000, 50000, 100000, 1000000, 1000000000], startvalues=(0, 1000000000))
property_dmg_slider = IntervalSlider(f[7, 13:16], range=[0, 1000, 10000, 50000, 100000, 1000000, 1000000000], startvalues=(0, 1000000000))


label_year = lift(year_slider.interval) do sl_interval
    
    start_year = sl_interval[1]
    end_year = sl_interval[2]
    
    return "Period: $(start_year) to $(end_year)"
end

label_crop_dmg = lift(crop_dmg_slider.interval) do sl_interval
    start_dmg = sl_interval[1]/1e6
    end_dmg = sl_interval[2]/1e6
    return "Crop Damage: $(start_dmg) M to $(end_dmg) M"
end

label_prop_dmg = lift(property_dmg_slider.interval) do sl_interval
    start_dmg = sl_interval[1]/1e6
    end_dmg = sl_interval[2]/1e6
    return "Property Damage: $(start_dmg) M to $(end_dmg) M"
end


Label(f[2, 13:16], label_year)
Label(f[4, 13:16], label_crop_dmg)
Label(f[6, 13:16], label_prop_dmg)

ax_obj = []
# ------------------------------------ END ----------------------------------- #

# ------------------------- Create static storm plots ------------------------ #
all_point_list = []
for row in eachrow(storm_data)
    push!(all_point_list, Point2f(row.lon_center, row.lat_center))
end

scatter!(ax_map, storm_data.lon_center, storm_data.lat_center, markersize=2, color=(palette[2], 0.25))

for i = 1:size(data.geometry)[1]

    geom = data.geometry[i]

    if !(data.NAME[i] in remove_state)
        lon, lat = [], []
        map(geom.points) do p
            push!(lon, p.x)
            push!(lat, p.y)
        end

        for j = 1:size(geom.parts)[1]-1

            start_ind = geom.parts[j] + 1
            end_ind = geom.parts[j+1]
            lines!(ax_map, lon[start_ind:end_ind], lat[start_ind:end_ind], color=:grey60)
        end
        lines!(ax_map, lon[geom.parts[end]+1:end], lat[geom.parts[end]+1:end], color=:grey60)
        xlims!(ax_map, -125, -65)
        ylims!(ax_map, 24, 50)

    end
end

ax_map.xgridvisible = false
ax_map.ygridvisible = false


# ------------------------------------ END ----------------------------------- #

state = Observable{String}("California")

# ------------------------------ Plot state map ------------------------------ #

geom_state = @lift data.geometry[data.NAME.==$state][1]

function plot_state!(ax, geometry)

    ax_new = lift(geometry) do geom
        ax = empty!(ax)
        lon, lat = [], []
        map(geom.points) do p
            push!(lon, p.x)
            push!(lat, p.y)
        end

        for j = 1:size(geom.parts)[1]-1

            start_ind = geom.parts[j] + 1
            end_ind = geom.parts[j+1]
            lines!(ax, lon[start_ind:end_ind], lat[start_ind:end_ind], color=:grey20)
        end
        lines!(ax, lon[geom.parts[end]+1:end], lat[geom.parts[end]+1:end], color=:grey20)
        pad = 1
        xlims!(ax, geom.MBR.left - pad, geom.MBR.right + pad)
        ylims!(ax, geom.MBR.bottom - pad, geom.MBR.top + pad)

        return ax
    end
    return ax_new
end

ax_state = plot_state!(ax_state, geom_state)

@lift $ax_state.title = $state

ax_obj = []

lift(geom_state) do geom
    lon, lat = [], []
    map(geom.points) do p
        push!(lon, p.x)
        push!(lat, p.y)
    end

    for j = 1:size(geom.parts)[1]-1

        start_ind = geom.parts[j] + 1
        end_ind = geom.parts[j+1]
        m1 = lines!(ax_map, lon[start_ind:end_ind], lat[start_ind:end_ind], color=:grey20)
        push!(ax_obj, m1)
    end
    m2 = lines!(ax_map, lon[geom.parts[end]+1:end], lat[geom.parts[end]+1:end], color=:grey20)
    push!(ax_obj, m2)
    return ax_obj
end

storm_points = map(storm_data.lon_center, storm_data.lat_center) do x, y
    return Point2f(x, y)
end

state_storm_data = @lift storm_data[inpolygon(storm_points, $geom_state), :]

state_storm_data_mini = lift(crop_dmg_slider.interval, state_storm_data) do sl_interval, ssd
    ssd_new = ssd[sl_interval[1].<=ssd.damage_crops, :]
    ssd_new = ssd_new[ssd_new.damage_crops.<=sl_interval[2], :]
    return ssd_new
end

state_storm_data_mini = lift(property_dmg_slider.interval, state_storm_data_mini) do sl_interval, ssd
    ssd_new = ssd[sl_interval[1].<=ssd.damage_property, :]
    ssd_new = ssd_new[ssd_new.damage_property.<=sl_interval[2], :]
    return ssd_new
end


state_storm_data_mini = lift(year_slider.interval, state_storm_data_mini) do sl_interval, ssd
    ind = sl_interval[1] .<= Dates.value.(Dates.Year.(ssd.begin_time))
    ssd_new = ssd[ind, :]
    ind = sl_interval[2] .>= Dates.value.(Dates.Year.(ssd_new.begin_time))
    ssd_new = ssd_new[ind, :]
    return ssd_new
end


state_storm_data_mini[].damage_property
state_storm_data_mini[].damage_crops


state_points = lift(state_storm_data_mini) do ssd
    x = Float32.(ssd.lon_center)
    y = Float32.(ssd.lat_center)

    return Point2f.(x, y)
end

palette
@lift scatter!($ax_state, state_points, markersize=log.($state_storm_data_mini.damage_property + $state_storm_data_mini.damage_crops), color=(palette[2], 0.5))


# ------------------------------------ END ----------------------------------- #

# ---------------------------- Plot occurrence map --------------------------- #
time = @lift $state_storm_data_mini.begin_time

function plot_occurrence!(ax, time)

    ax_new = lift(time) do dt
        empty!(ax)
        h = fit(Histogram, Dates.month.(dt), [1:13;])
        tot_events = sum(h.weights)
        h = normalize(h)
        w = h.weights * 100

        w = push!(w, w[1])
        theta = [0:30:360;] * 2 * pi / 360
        scatterlines!(ax, theta, w, color=(palette[2]))
        ax.title = "Total Number of Events: $(tot_events)"
        return
    end

    return ax_new

end

plot_occurrence!(ax_occurrence, time)


hidespines!(ax_occurrence)


# ------------------------------------ End ----------------------------------- #


# ------------------------ Plot damage over the years ------------------------ #

struct DAMAGE
    crop
    property
end

function get_damage(noaa_storm_details, sl_interval)
    dmg_property = []
    dmg_crop = []
    for i = sl_interval[1]:sl_interval[2]
        ind = Dates.value.(Dates.Year.(noaa_storm_details.begin_time)) .== i
        push!(dmg_property, sum(noaa_storm_details[ind, :].damage_property))
        push!(dmg_crop, sum(noaa_storm_details[ind, :].damage_crops))
    end
    return DAMAGE(dmg_crop, dmg_property)
end


damage = lift(year_slider.interval, state_storm_data_mini,) do sl_interval, s
    return get_damage(s, sl_interval)
end

year_slider.interval[]
lift(year_slider.interval, damage) do sl_interval, d
    empty!(ax_damage_crop)
    empty!(ax_damage_property)
    barplot!(ax_damage_crop, [sl_interval[1]:sl_interval[2];], d.crop/1e6, color=palette[6])
    barplot!(ax_damage_property, [sl_interval[1]:sl_interval[2];], d.property/1e6, color=palette[3])

end


string_crop_damage = lift(damage) do d 
    tot_damage = sum(d.crop)
    if tot_damage>1e6
        return "$(round(tot_damage/1e6, digits=2)) M"
    elseif tot_damage > 1e3
        return "$(round(tot_damage/1e3, digits=2)) K"
    end
end

string_property_damage = lift(damage) do d 
    tot_damage = sum(d.property)
    if tot_damage>1e9
        return "$(round(tot_damage/1e9, digits=2)) B"
    elseif tot_damage>1e6
        return "$(round(tot_damage/1e6, digits=2)) M"
    elseif tot_damage > 1e3
        return "$(round(tot_damage/1e3, digits=2)) K"
    end
end


@lift $ax_damage_crop.title = "Total Crop Damage: $($string_crop_damage)"
@lift $ax_damage_property.title = "Total Property Damage: $($string_property_damage)"

on(menu.selection) do s
    state[] = s
    delete!(ax_map, ax_obj[end-1])
end
