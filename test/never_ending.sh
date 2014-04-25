#!/bin/bash
# the below will run forever
while true ; do
	`echo $$ > never_ending.out`
	sleep 1
done