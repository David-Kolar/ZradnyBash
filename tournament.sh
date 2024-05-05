#!/bin/bash

set -ueo pipefail

temp_dir="$( mktemp -d )"

tournament_name="My tournament"

get_team_name_from_dir() {
    echo "$1" | cut -d "-" -f 2
}

copy_files_to_temp() {
    cd tasks
    for task in *; do
        if [ -d "$task" ]; then            
            cd $task
            echo "$task" >> "${temp_dir}/task_names"
            for team in *.gz; do
                team_name="team-$( basename $team ".log.gz")"
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
    for team in $temp_dir/team-*; do
        team_name="$( get_team_name_from_dir $team )"
        points=0
        echo $team
        while read task; do
            echo $task
            failed=0
            passed=0
            if [ -f "${team}/${task}.log" ]; then
                passed="$(cat "${team}/${task}.log" | cut -d " " -f 1 | (grep -F "pass" || echo "") | wc -w)"
                failed="$(cat "${team}/${task}.log" | cut -d " " -f 1 | (grep -F "fail" || echo "") | wc -w)"
                points=$((points+passed))
                
            else
                echo "Log not available." > "${team}/${task}.log"
            fi
            echo "${task} ${passed} ${failed} [Complete log](${task}.log)" >> "${team}/team_results"
        done < "${temp_dir}/task_names"
        echo "${points} ${team_name}" >> "${temp_dir}/tournament_results"
    done    
}

create_table_with_tournament_results() {
    cat "${temp_dir}/tournament_results" | sort -r -n -k 1 > "${temp_dir}/sorted_results"
    echo "# ${tournament_name}" > "${temp_dir}/index.md"
    echo >> "${temp_dir}/index.md"
    poradi=1;
    while read points team_name; do
        echo " ${poradi}. ${team_name} (${points} points)" >> "${temp_dir}/index.md"
        poradi=$(( poradi + 1 ))
    done < "${temp_dir}/sorted_results";
}

create_tables_for_individual_teams() {
    
}
 
copy_files_to_temp
process_team_logs
create_table_with_tournament_results
tree $temp_dir
cp $temp_dir/index.md index.md
rm -fr $temp_dir
