#!/bin/bash -e

. ../common.sh

log=$logDir/sbatch.log
out=$(sampleName)-hbv.fastq

echo "$(basename $(pwd)) sbatch.sh running at $(date)" >> $log
echo "  Dependencies are $SP_DEPENDENCY_ARG" >> $log

if [ "$SP_FORCE" = "0" -a -f $out ]
then
    # The output file already exists and we're not using --force, so
    # there's no need to do anything. Just pass along our task name to the
    # next pipeline step.
    echo "  Ouput file $out already exists and SP_FORCE is 0. Nothing to do." >> $log
    echo "TASK: collect"
else
    jobid=$(sbatch -n 1 $SP_NICE_ARG $SP_DEPENDENCY_ARG submit.sh "$@" | cut -f4 -d' ')
    echo "TASK: collect $jobid"

    echo "  Job id is $jobid" >> $log
fi

echo >> $log
