#!/usr/bin/env bash

trap "exit" SIGINT

if [ "$#" -eq 0 ]; then
    echo "Illegal number of parameters."
    echo "Usage:"
    echo "  $(printf %q "$BASH_SOURCE") Module.fst [min-commit] [max-commit]"
    exit 1
fi

MODULE=$1
DATE_RANGE_MIN=${2:-0}
DATE_RANGE_MAX=${3:-$(date +'%s')}

prepare () {
    readarray -t commits < <(
	nix eval --json "$CURRENTFLAKE#commits" |
	    jq -r ".[] | select(.timestamp >= $DATE_RANGE_MIN and .timestamp <= $DATE_RANGE_MAX) | .commit"
    )

    min=0
    max=$(( ${#commits[@]} - 1 ))

    init_min=$min
    init_max=$max    
    
    LOGS="logs"
    mkdir -p "$LOGS"
    
    spin_i=0
    spin[0]="-"
    spin[1]="\\"
    spin[2]="|"
    spin[3]="/"

    for i in $(seq $init_min $init_max); do
        results[$i]=""
    done
}


declare -gA results
declare -gA spin

log () {
    kill_pretty_status
    echo "$1"
    dummy_five_lines
}

dummy_five_lines () {
    printf " \n \n \n \n \n"
}
pretty_status () {
    printf "\e[5A\e[K"
    COLUMNS=$(tput cols)
    spin_i=$(( ($spin_i + 1) % 4 ))
    spin_symbol="${spin[$spin_i]}"
    printf "\e[3;30;44mStatus: \e[0m"
    case "${results[$current]}" in
	("build") printf "Building";;
	("test") printf "Testing F* program";;
	(*) printf ""${results[$current]}"" ;;
    esac
    printf " \e[90m[$min<->$max, cur=$current, commit=$commit]\e[0m\n"
    printf "\e[90m%-$(( $COLUMNS / 2 ))s%$(( $COLUMNS - $COLUMNS / 2 ))s" "$(date -d @$DATE_RANGE_MIN)" "$(date -d @$DATE_RANGE_MAX)"
    printf "\n\e[0m┌"
    for i in $(seq $init_min $init_max); do
        printf "─"
    done
    printf "┐\n│"
    for i in $(seq $init_min $init_max); do
	case "${results[$i]}" in
	    ("build") printf "\e[7;30;43m%s" "$spin_symbol";;
	    ("test") printf "\e[34m%s" "$spin_symbol";;
	    ("build-failure") printf "\e[91m█";;
	    ("success") printf "\e[32m▓";;
	    ("failure") printf "\e[91m▓";;
	    (*) printf " ";
	esac
	printf "\e[0m";
    done
    printf "\e[0m│\n└"
    for i in $(seq $init_min $init_max); do
        printf "─"
    done
    printf "┘\n"
}

update_pretty_status () {
    while [ "$min" -lt "$max" ]; do
	sleep 0.7
	pretty_status
    done
}

kill_pretty_status () {
    if [[ "$(jobs -rp)" == "" ]]; then
	:
    else
	kill $(jobs -rp)
	wait $(jobs -rp) 2>/dev/null
    fi
}

status () {
    echo ""
    echo "# Test $commit"
    echo "[min=$min; max=$max; current=$current; len=$len]"
}

build-current-fstar () {
    commit="${commits[$current]}"
    set_current_status "build"
    if nix build --quiet --no-link "$CURRENTFLAKE#fstar-bin-${commit}" 1>/dev/null 2>/dev/null; then
	return 0;
    else
	set_current_status "build-failure"
	return 1;
    fi
}

test-current-fstar () {
    if build-current-fstar; then
	set_current_status "test"
	if nix run "$CURRENTFLAKE#fstar-bin-${commit}" "$MODULE" 1>"$LOGS/$commit.stdout" 2>"$LOGS/$commit.stderr"; then
	    set_current_status "success"
	    # nix store delete "$CURRENTFLAKE#fstar-${commit}" 1>/dev/null 2>/dev/null
	    return 0
	else
	    set_current_status "failure"
	    # nix store delete "$CURRENTFLAKE#fstar-${commit}" 1>/dev/null 2>/dev/null
	    return 1
	fi
    else
	return 2
    fi
}

echo "" > status
set_current_status () {
    echo "$current $1" >> status
    results[$current]="$1"
    kill_pretty_status
    update_pretty_status &
}

step () {
    current=$(( ($min + $max)/2 ))
    len=$(( $max - $min + 1 ))

    { test-current-fstar; code="$?"; } || true

    case $code in
	0) min=$(( $current + 1 )) ;;
	1) max=$(( $current - 1 )) ;;
	2) min=$(( $current + 1 ))
    esac
}

prepare
current=0
dummy_five_lines
update_pretty_status &

current=$max; test-current-fstar
current=$min; test-current-fstar
max=$(( max - 1 ))
min=$(( min + 1 ))

while [ "$min" -lt "$max" ]; do
    step
done

