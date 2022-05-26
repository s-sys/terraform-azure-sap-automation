#!/bin/bash

file=$1
base64=$(which base64)
gzip=$(which gzip)
col=80

${gzip} --best -c ${file} | ${base64} -b ${col}
