#!/bin/bash

set -ueo pipefail

# Create a temporary directory
temp_dir="$( mktemp -d )"

# Define output directory for tournament results
output_dir="out"

# Define the name of the tournament
tournament_name="My tournament"

# Define sizes of table columns

width_column_1=20
width_column_2=8 
width_column_3=8
width_column_4=38 

load_config_rc_file() {
    if [ -f "tasks/config.rc" ]; then
        source "tasks/config.rc"
        tournament_name=$title
        output_dir=$name
    fi
}

process_parameters() {
    eval set -- "$( getopt -o "o:t:" -- "$@" )"
    while [ $# -gt 0 ]; do
        case "$1" in
            -o)
                output_dir="$2"
                shift
                ;;
            -t)
                tournament_name="$2"
                ;;
            --)
                shift
                break
                ;;
        esac
        shift
done
    
}

get_team_name_from_dir() {
    echo "$1" | cut -d "-" -f 2
}

copy_files_to_temp() {
    # Unpack and copy log files for each team to a temporary directory
    cd tasks
    for task in *; do
        if [ -d "$task" ]; then          
            cd "$task"
            echo "$task" >> "${temp_dir}/task_names"
            for team in *.gz; do
                team_name="team-$( basename "$team" ".log.gz")"
                path="${temp_dir}/${team_name}"
                mkdir -p "$path"
                cp "${team}" "${path}/${task}.log.gz"
                gunzip "${path}/${task}.log.gz"
            done
            cd ..
        fi
    done
    cd ..                         
}

process_team_logs() {
    for team in "${temp_dir}"/team-*; do
        team_name="$( get_team_name_from_dir "$team" )"
        points=0
        while read task; do
            failed=0
            passed=0
            if [ -f "${team}/${task}.log" ]; then
                passed="$( <"${team}/${task}.log" cut -d " " -f 1 | (grep -F "pass" || echo "") | wc -w)"
                failed="$( <"${team}/${task}.log" cut -d " " -f 1 | (grep -F "fail" || echo "") | wc -w)"
                points=$((points+passed))
                
            else
                # In case log file of some task is not available 
                echo "Log not available." > "${team}/${task}.log"
            fi
            echo "${task} ${passed} ${failed} [Complete log](${task}.log)." >> "${team}/team_results"
        done < "${temp_dir}/task_names"
        echo "${points} ${team_name}" >> "${temp_dir}/tournament_results"
    done    
}

create_table_with_tournament_results() {
    <"${temp_dir}/tournament_results" sort -r -n -k 1 > "${temp_dir}/sorted_results"
    echo "# ${tournament_name}" > "${temp_dir}/index.md"
    echo >> "${temp_dir}/index.md"
    poradi=1;
    while read points team_name; do
        echo " ${poradi}. ${team_name} (${points} points)" >> "${temp_dir}/index.md"
        poradi=$(( poradi + 1 ))
    done < "${temp_dir}/sorted_results";
}

repeat_characters() {
    # $1 -> number of characters; $2 -> character
    counter=0;
    while ! [ $counter == "$1" ]; do
        echo -n "$2"
        counter=$(( counter + 1))
    done;
}

create_table_row() {
    # 1-4 -> text in columns 1-4; 5 -> character used as space; 6 -> character used as column separator
    # Store length of all 4 columns in 4 coresponding variables
    characters_column1="$( echo -n "$1" | wc -c )"
    characters_column2="$( echo -n "$2" | wc -c )"
    characters_column3="$( echo -n "$3" | wc -c )"
    characters_column4="$( echo -n "$4" | wc -c )"
    echo -n "${6}${1}$( repeat_characters $(( width_column_1 - characters_column1)) "${5}" )"
    echo -n "${6}$( repeat_characters $(( width_column_2 - characters_column2 )) "${5}" )${2}"
    echo -n "${6}$( repeat_characters $(( width_column_3 - characters_column3 )) "${5}" )${3}"
    echo "${6}${4}$( repeat_characters $(( width_column_4 - characters_column4)) "${5}" )${6}"
}
create_table_for_each_team() {
    # Loop over each team, generate corresponding table and save it as file index.md in directory of that team
    for team in "$temp_dir"/team-*; do
        team_name="$( get_team_name_from_dir "$team" )"
        echo "# Team ${team_name}" >> "${team}/index.md"
        echo >> "${team}/index.md"
        create_table_row "" "" "" "" "-" "+" >> "${team}/index.md";
        create_table_row " Task " " Passed " " Failed " " Links" ' ' "|" >> "${team}/index.md"
        create_table_row "" "" "" "" "-" "+" >> "${team}/index.md";
        while read task passed failed links; do
            create_table_row " ${task}" " ${passed} " " ${failed} " " ${links}" ' ' "|" >> "${team}/index.md"
        done < "${team}/team_results"
        create_table_row "" "" "" "" "-" "+" >> "${team}/index.md"
        # Delete file team_results which is no longer needed
        rm "${team}/team_results"
    done
}

export_results() {
    mkdir -p "${output_dir}"
    cp -r "${temp_dir}"/team-* "${temp_dir}/index.md" "${output_dir}"
}

# Execute functions to run this script
load_config_rc_file
process_parameters "$@"
copy_files_to_temp
process_team_logs
create_table_with_tournament_results
create_table_for_each_team
export_results
# Delete all temporary files
rm -fr "$temp_dir"
