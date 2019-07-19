#!/bin/bash
# This script builds an index file that is crawlable by the frontend.
# It lets the frontend know the state of the repository.

print_file() {
    x="$1"
    [ "${x:0:2}" == "./" ] && x="${x:2}" # remove leading "./" if needed
    url="https://raw.githubusercontent.com/webfpga/verilog/master/examples/$x"
    echo "file $x $url"
}

traverse() {
    root="$1"

    for x in "$root"/*; do
        if [ -d "$x" ]; then
            traverse "$x"
            echo
        elif [ -f "$x" ]; then
            print_file "$x"
        fi
    done
}

cd examples
traverse .
exit

for example_path in v; do
    echo file $filename $url
done
