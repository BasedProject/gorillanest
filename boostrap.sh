#!/bin/sh

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
