#!/bin/bash -e

# We cannot initially unconditionally write to a log file because the log
# directory may not exist. So write initial errors to stderr.

# Remove and recreate the top-level logging directory.
ourLogDir=../logs
rm -fr $ourLogDir
mkdir $ourLogDir || {
    # SLURM will catch this output and put it into slurm-N.out where N is
    # our job id.
    echo "$0: Could not create log directory '$ourLogDir'!" >&2
    exit 1
}

. ../common.sh

# Make sure the logDir variable in ../common.sh agrees with what we just did.
if [ ! "$logDir" = $ourLogDir ]
then
    # SLURM will catch this output and put it into slurm-N.out where N is
    # out job id.
    echo "$0: common.sh logDir variable has unexpected value '$logDir' (should be $ourLogDir)!" >&2
    exit 1
fi

# From here on we can log errors in the regular way.

log=$sampleLogFile
logStepStart $log

# Remove the marker files that indicate when a job is fully complete or
# that there has been an error and touch the file that shows we're running.
rm -f $doneFile $errorFile
touch $runningFile

echo "  Removing all old slurm-*.out files." >> $log
rm -f ../0*/slurm-*.out

tasks=$(tasksForSample)

for task in $tasks
do
    fastq=$(taskToMappedFastq $task $log)
    echo "  Task $task will use FASTQ $fastq" >> $log
    checkFastq $fastq $log
done

for task in $tasks
do
    # Emit task names (without job ids as this step does not start any
    # SLURM jobs).
    echo "TASK: $task"
done

logStepStop $log
