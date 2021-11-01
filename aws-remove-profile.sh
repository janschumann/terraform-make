#!/bin/bash

sed -i '' "/\[profile\ ${1}\]/,\$d" ~/.aws/config
sed -i '' "/\[${1}\]/,\$d" ~/.aws/credentials
