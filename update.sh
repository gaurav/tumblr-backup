#!/bin/bash

git reset --hard
git pull origin master
perl download_as_json.pl tumblr.ggvaidya.com
git add .
git commit -a -v -m "Updated to latest"
git push origin master
