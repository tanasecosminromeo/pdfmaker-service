#!/usr/bin/env bash
MY_VAR=$(grep $1 .env | xargs)
echo ${MY_VAR#*=}