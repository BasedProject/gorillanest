#!/bin/sh
set -e

hail_xolatile () {
    printf "\033[33m--\033[0m\n\n"
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
echo "THE DIRECTORY 'dummy-repositories/' WAS INITIALIZED FOR YOU, YOU MAY WANT TO RUN THE FOLLOWING AS A DEMO:"
echo "   rm -frfr repositories/"
echo "   cp -r dummy-repositories/ repositories/"
