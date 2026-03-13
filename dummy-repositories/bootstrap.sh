#!/bin/sh

mkdir -p anon
cd anon

git clone --bare https://github.com/agvxov/cursed_c
git clone --bare https://github.com/agvxov/dictate
git clone --bare https://github.com/agvxov/chadsay

mkdir test.git
cd test.git
git init --bare
cd ..
