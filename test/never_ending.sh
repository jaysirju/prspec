#!/bin/bash
# the below will run for 90 seconds
index=0
while [ $index -lt 90 ] ; do
	`echo $$ > never_ending.out`
	(( index=$index+1 ))
	sleep 1
done