#!/bin/sh
set -e

hail_xolatile () {
    echo -e "\033[33m--\033[0m\n"
}

# Python
python -m venv venv
. venv/bin/activate 
pip install -r requirements.txt
deactivate
hail_xolatile

# Perl
carton install
hail_xolatile

# Go
export GOPATH=$(realpath .)/gopath
go install github.com/DarthSim/hivemind@latest
hail_xolatile

# dummy-repositories/
dummy_root=dummy-repositories/anon
mkdir -p "$dummy_root"
for repository in slurp dictate vimdir; do
    destination="$dummy_root/$repository.git"
    if [ ! -d "$destination" ]; then
        git clone --bare "https://github.com/agvxov/$repository.git" "$destination"
    fi
done
