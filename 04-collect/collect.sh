#!/bin/bash -e

. ../common.sh

# The log file is the top-level sample log file, seeing as this step is a
# 'collect' step that is only run once.
log=$sampleLogFile
out=$(sampleName)-$genomeSpecies.fastq

logStepStart $log
logTaskToSlurmOutput collect $log

function skip()
{
    # We're being skipped. Make an empty output file, if one doesn't
    # already exist. There's nothing much else we can do and there's no
    # later steps to worry about.
    [ -f $out ] || touch $out
}

function collect()
{
    echo "  FASTQ collection started at `date`" >> $log
    rmFileAndLink $out

    tasks=$(tasksForSample)

    fastq=
    for task in $tasks
    do
        echo "    Task $task fastq:" >> $log
        for i in 01-bwa-aln 02-bwa-aln-l 03-bwa-mem
        do
            f=../$i/$task-$genomeSpecies.fastq.gz
            echo "      $f" >> $log
            fastq="$fastq $f"
        done
    done

    zcat $fastq | filter-fasta.py --quiet --removeDuplicatesById --fastq > $out
    echo "  FASTQ collection stopped at `date`" >> $log
}


if [ $SP_SIMULATE = "1" ]
then
    echo "  This is a simulation." >> $log
else
    echo "  This is not a simulation." >> $log
    if [ $SP_SKIP = "1" ]
    then
        echo "  $(stepName) is being skipped on this run." >> $log
        skip
    elif [ -f $out ]
    then
        if [ $SP_FORCE = "1" ]
        then
            echo "  Pre-existing output file $out exists, but --force was used. Overwriting." >> $log
            collect
        else
            echo "  Will not overwrite pre-existing output file $out. Use --force to make me." >> $log
        fi
    else
        echo "  Pre-existing output file $out does not exist." >> $log
        collect
    fi
fi

logStepStop $log
