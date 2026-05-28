#!/bin/bash
MSG=${1:-"update"}
git add -A
git commit -m "$MSG"
git push
