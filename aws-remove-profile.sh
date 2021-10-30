#!/bin/bash

sed -i '' "/\[profile\ ${1}\]/,\$d" ~/.aws/config
