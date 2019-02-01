#!/bin/bash
###########################################################################################################
# 2019-02-01 Christian Duentgen (duentgen@gmx.de)
###########################################################################################################
# Script running the SUMO microskopic traffic generator in order to generate some GPS trace data
# If an alternative scipt sumo.bash is present in /data/config/ it will be executed instead of this 
# demo script.
###########################################################################################################

if [ -f "/data/config/sumo2.bash" ]
    then    
        echo "Using alternative sumo2.bash script in /data/config."
        source "/data/config/sumo2.bash"
        exit 0
    else    
        echo "No alternative sumo2.bash script found in /data/config. "
        echo "==> Using demo script /usr/local/share/sumo/bin/startSUMO.bash."
fi

time_script_start=$(date +%s)

# Download OSM data from geofabrik.de.
# Define some pairs (url filename) for map download:
#mapdownloadurl=('http://download.geofabrik.de/europe/germany-latest.osm.bz2' 'germany-latest')
#mapdownloadurl=('http://download.geofabrik.de/europe/germany/berlin-latest.osm.bz2' 'berlin-latest')
mapdownloadurl=('http://download.geofabrik.de/europe/germany/bremen-latest.osm.bz2' 'bremen-latest')
#mapdownloadurl=('http://download.geofabrik.de/europe/germany/hamburg-latest.osm.bz2' 'hamburg-latest')
#mapdownloadurl=('http://download.geofabrik.de/europe/germany/hessen-latest.osm.bz2' 'hessen-latest')
#mapdownloadurl=('http://download.geofabrik.de/europe/germany/nordrhein-westfalen-latest.osm.bz2' nordrhein-westfalen-latest')
#mapdownloadurl=('http://download.geofabrik.de/europe/germany/nordrhein-westfalen/arnsberg-regbez-latest.osm.bz2' 'arnsberg-regbez-latest')
#mapdownloadurl=('http://download.geofabrik.de/europe/germany/saarland-latest.osm.bz2' 'saarland-latest')

# define data folders
#vol_base="/data/SUMO-DATA" # for use on local workstation workstation
vol_base="/data" # for use in docker-compose orchestrated container

vol_config="$vol_base"/config
vol_maps="$vol_base"/maps
vol_tmp="$vol_base"/tmp
vol_results="$vol_base"/results
vol_logs="$vol_base"/logs

if [ "$SUMO_HOME" = "" ]
    then
        SUMO_HOME="/usr/local/share/sumo"
fi
sumo_home="$SUMO_HOME"
sumo_path="$sumo_home/bin"
sumo_tools_path="$sumo_home/tools"
sumo_data_path="$sumo_home/data"

echo "Set up paths:"
echo "  vol_config = $vol_config"
echo "  vol_maps = $vol_maps"
echo "  vol_results = $vol_results"
echo "  vol_logs = $vol_logs"
echo "  vol_tmp = $vol_tmp"
echo "  SUMO_HOME = $SUMO_HOME"
echo "  sumo_home = $sumo_home"
echo "  sumo_path = $sumo_path"
echo "  sumo_tools_path = $sumo_tools_path"
echo "  sumo_data_path = $sumo_data_path"

# simulation parameters
simulated_time=3600 # number of seconds to simulate
simulation_start=0  # starting time (seconds in epoche)
simulation_end=$(($simulation_start + $simulated_time))
simulation_repetition_rate=10.0 # 1/f where f is the frequency of generated vehicles per timestep. 
simulation_fringe_factor=10.0   # reaktive amount of vehicles to enter from outside the map (on border edges)
simulation_dua_iterations="--max-convergence-deviation " # use automatic stop during iterative search for Dynamic User Equilibrium 
#simulation_dua_iterations="-l 5" # use exactly N iterations for finding Dynamic User Equilibrium
simulated_num_vianodes="--intermediate=5" # use certain number of intermediate way points
#simulated_num_vianodes=""
export_basedate=$(date +%s) # time in epoche representing the start of the simulation (timestep 0)
export_samplerate="1" # share of vehicles whose tracks shall be exported [0,1]

#create folders if required
mkdir -p ${vol_config}
mkdir -p ${vol_maps}
mkdir -p ${vol_tmp}
mkdir -p ${vol_results}
mkdir -p ${vol_logs}

#variables for files related to map import
file_osmmap="$vol_maps/${mapdownloadurl[1]}.osm"
file_network="$vol_maps/${mapdownloadurl[1]}.osm.net.xml"
file_url="${mapdownloadurl[0]}"
file_osmtypefiles="$vol_config/osmNetconvert.typ.xml, $vol_config/osmNetconvertUrbanDe.typ.xml"

#download map data if required
time_osmmap_start=$(date +%s)
if [ -f "$file_osmmap".bz2 ]
    then
        echo "OSM Map data found on disk."
    else
        echo "OSM map data file "$file_osmmap".bz2 not found on disk. Starting download from ${mapdownloadurl[0]} to $vol_maps ..."
        curl -o "$file_osmmap".bz2 "$file_url"
fi

# expand the data and copy to maps-folder
if [ -f "$file_osmmap" ]
    then
        echo "Unzipped OSM map archive $file_osmmap found in $vol_maps ."
    else 
        echo "Unzipping OSM map archive to $vol_maps ..."
        bunzip2 -f "$file_osmmap".bz2
fi

# copy xml-typemap-files for OSM-import if necessary
if [ -f "$vol_config"/osmNetconvertUrbanDe.typ.xml ]
    then
        echo "Typemap definitions for OSM import found in $vol_config ."
    else
        echo "Typemap definitions for OSM imports are copied to $vol_config ..."
        cp "$sumo_data_path"/typemap/osmNetconvert.typ.xml "$vol_config"/osmNetconvert.typ.xml
        cp "$sumo_data_path"/typemap/osmNetconvertUrbanDe.typ.xml "$vol_config"/osmNetconvertUrbanDe.typ.xml
fi
time_osmmap_end=$(date +%s)
echo "Prepared OSM map data for conversion to SUMO net file in $(($time_osmmap_end - $time_osmmap_start)) seconds."

# convert mapdata to SUMO network
if [ -f "$file_network" ]
    then
        echo "SUMO net definition file $file_network found in $vol_maps ."
    else
        echo "SUMO net definition file $file_network not found. Creating it from unzipped OSM map in $vol_maps ..."
        time_netconvert_start=$(date +%s)
        # standard option settings for importing net from OSM data
        #"$sumo_path"/netconvert --type-files "$file_osmtypefiles" --osm-files "$file_osmmap" --output-file "$file_network" --geometry.remove --roundabouts.guess --ramps.guess  --junctions.join --tls.guess-signals --tls.discard-simple --tls.join --no-internal-links --keep-edges.by-vclass passenger --remove-edges.by-vclass rail_slow,rail_fast,bicycle,pedestrian --remove-edges.by-type highway.track,highway.services,highway.unsurfaced --remove-edges.isolated true --message-log "$vol_logs"/netconvert.messages.log --error-log "$vol_logs"/netconvert.messages.log

        # options set to reduce net size for large OSM imports (only "drivable" roads, largest connected component only"):
        "$sumo_path"/netconvert --type-files "$file_osmtypefiles" --osm-files "$file_osmmap" --output-file "$file_network" --geometry.remove --roundabouts.guess --ramps.guess  --junctions.join --tls.guess-signals --tls.discard-simple --tls.join --no-internal-links --keep-edges.by-vclass passenger --remove-edges.by-vclass rail,rail_electric,bicycle,pedestrian --remove-edges.by-type highway.track,highway.services,highway.unsurfaced --remove-edges.isolated true --keep-edges.components 1 --message-log "$vol_logs"/netconvert.messages.log --error-log "$vol_logs"/netconvert.messages.log
        time_netconvert_end=$(date +%s)
        echo "Converted OSM map data to SUMO net file in $(($time_netconvert_end - $time_netconvert_start)) seconds."
fi

#get timestamp as an id for the current run
run_id=$(date +%Y-%0m-%0d_%H-%M-%S)
echo "All further output files of this skript will be labeled with timestamp $run_id ."

#set up variables for data exchange and result file names
file_trips="$vol_tmp/trips_$run_id.trips"
file_routes="$vol_tmp/trips_$run_id.routes"
file_fcdtrace="$vol_tmp/trips_$run_id.fcd"
file_result="$vol_results/trips_$run_id.gps"

# create random trips (and routes using -r...) -- needed as input to sumo / sumo-gui
#echo "Create random trips definitions and route them..."
#"$sumo_tools_path"/randomTrips.py -n "$file_network" -r "$file_routes" -b "$simulation_start" -e "$simulation_end" -p "$simulation_repetition_rate" --allow-fringe --fringe-factor "$simulation_fringe_factor" "$simulated_num_vianodes" -l > "$vol_logs"/"$run_id"_randomTrips.log

# create trips only
echo "Create random trip definitions..."
time_trips_start=$(date +%s)
"$sumo_tools_path"/randomTrips.py -n "$file_network" -o "$file_trips" -b "$simulation_start" -e "$simulation_end" -p "$simulation_repetition_rate" --allow-fringe --fringe-factor "$simulation_fringe_factor" "$simulated_num_vianodes" -l > "$vol_logs"/"$run_id"_randomTrips.log
time_conversion_end=$(date +%s)
time_trips_end=$(date +%s)
echo "Random Trips generated in $(($time_trips_end - $time_trips_start)) seconds."

# example for random trip creation --- run from /data/SUMO-DATA :
#/usr/local/share/sumo/tools/randomTrips.py -n maps/etwaBochum.osm.net.xml -o tmp/trips.trips -b 0 -e 3600 -p 0.5 --allow-fringe --fringe-factor 10.0 -l > logs/randomTrips.log

# perform routing for existing trips using Dynamic User Equilibrium 
#echo "Create routes from trips using Dynamic User Equilibrium..."
#time_route_start=$(date +%s)
#"$sumo_tools_path"/assign/duaIterate.py -n "$file_network" -t "$file_trips" -o "$file_routes" "$simulation_dua_iterations" > "$vol_logs"/"$run_id"_duaIterate.log
#time_route_end=$(date +%s)
#echo "Routes for trips generated in $(($time_route_end - $time_route_start)) seconds."

# simulate from commandline using pre-routed trips and dump data in format suitable to traceExporter
#echo "Start simulation of re-routed trips..."
#time_sumo_start=$(date +%s)
#"$sumo_path"/sumo --net-file "$file_network" --route-files "$file_routes" --fcd-output "$file_fcdtrace" --print-options true --message-log "$vol_logs"/"$run_id"_sumo.messages.log --error-log "$vol_logs"/"$run_id"_sumo.messages.log
#time_sumo_end=$(date +%s)
#echo "Simulation took $(($time_sumo_end - $time_sumo_start)) seconds."

# simulate using automatic/periodic on-line routing at simulation time
# Option 	                                    default 	Description
#--device.rerouting.probability <FLOAT> 	    0 	        The probability for a vehicle to have a routing device
#--device.rerouting.explicit <STRING> 		                Assign a device to named vehicles
#--device.rerouting.deterministic 	            false 	    The devices are set deterministic using a fraction of 1000 (with the defined probability)
#--device.rerouting.period <STRING> 	        0       	The period with which the vehicle shall be rerouted
#--device.rerouting.pre-period <STRING> 	    60      	The rerouting period before insertion/depart
#--device.rerouting.adaptation-interval <INT> 	1 	        The interval for updating the edge weights.
#--device.rerouting.adaptation-weight <FLOAT> 	0.0 (disabled) 	The weight of prior edge weights for exponential averaging from [0, 1].
#--device.rerouting.adaptation-steps <INT> 	    180      	The number of adaptation steps for averaging (enable for values > 0).
#--device.rerouting.with-taz 	                false 	    Use traffic assignment zones (TAZ/districts) as routing end points
#--device.rerouting.init-with-loaded-weights 	false 	    Use option --weight-files for initializing the edge weights at simulation start 
echo "Start simulation using automatic/periodic on-line routing..."
time_sumo_start=$(date +%s)
"$sumo_path"/sumo --net-file "$file_network" --route-files "$file_trips" --device.rerouting.probability 0.5 --device.rerouting.period 120 --device.rerouting.adaptation-interval 10 --ignore-route-errors --fcd-output "$file_fcdtrace" --fcd-output.geo --print-options true --message-log "$vol_logs"/"$run_id"_sumo.messages.log --error-log "$vol_logs"/"$run_id"_sumo.messages.log
time_sumo_end=$(date +%s)
echo "Simulation took $(($time_sumo_end - $time_sumo_start)) seconds."

# simulation with visualization
#echo "Start interactive simulation with visualization on pre-routed trips"
#"$sumo_path"/sumo-gui --net-file "$file_network" --route-files "$file_routes" --fcd-output "file_fcdtrace" -C "$vol_results"/sumo_"$run_id".config --print-options true --message-log "$vol_logs"/"$run_id"_sumo.messages.log --error-log "$vol_logs"/"$run_id"_sumo.messages.log
# examples for simulation with GUI --- run from /data/SUMO-DATA :
#sumo-gui --net-file maps/etwaBochum.osm.net.xml --route-files results/trips.trips.xml --device.rerouting.probability 0.75 --device.rerouting.period 180 --device.rerouting.adaptation-interval 30 --ignore-route-errors --fcd-output results/trips.trace.fcd --fcd-output.geo --print-options true --message-log logs/sumo-gui.messages.log --error-log logs/sumo-gui.messages.log
#sumo-gui --net-file maps/etwaBochum.osm.net.xml --route-files results/trips.trips.xml --device.rerouting.probability 0.75 --device.rerouting.period 180 --device.rerouting.adaptation-interval 30 --ignore-route-errors --fcd-output results/trips.trace.fcd --fcd-output.geo --full-output results/sumo-gui.FullOutput.xml --netstate-dump.empty-edges false --print-options true --message-log logs/sumo-gui.messages.log --error-log logs/sumo-gui.messages.log

#export trips.fcd as gps data
echo "Convert trace data..."
time_conversion_start=$(date +%s)
"$sumo_tools_path"/traceExporter.py --fcd-input "$file_fcdtrace" --net-input "$file_network" --gpsdat-output "$file_result" -p "$export_samplerate" --orig-ids --base-date "$export_basedate" > "$vol_logs"/"$run_id"_traceExporter.log
time_conversion_end=$(date +%s)
echo "Conversion of trace data took $(($time_conversion_end - $time_conversion_start)) seconds."

time_script_end=$(date +%s)
echo "Total runtime of the script was $(($time_script_end - $time_script_start)) seconds."
