# IMPORTANT: All (relative) paths in this file are relative to the scripts
# in 00-start, etc. This file is sourced by those scripts.

logDir=../logs

if [ ! -d $logDir ]
then
    echo "  Log directory '$logDir' does not exist." >&2
    exit 1
fi

log=$logDir/common.sh.stderr

root=/rds/project/djs200/rds-djs200-acorg/bt/root

if [ ! -d $root ]
then
    echo "  Root directory '$root' does not exist." >> $log
    exit 1
fi

activate=$root/share/virtualenvs/365/bin/activate

if [ ! -f $activate ]
then
    echo "  Virtualenv activation script '$activate' does not exist." >> $log
    exit 1
fi

. $activate

dataDir=../../../..
doneFile=../slurm-pipeline.done
runningFile=../slurm-pipeline.running
errorFile=../slurm-pipeline.error
sampleLogFile=$logDir/sample.log

genomeSpecies=vole

BWA_DB=$root/share/bwa-indices/$genomeSpecies

if [ ! -f $BWA_DB.bwt ]
then
    echo "  BWA database file '$BWA_DB.bwt' does not exist." >> $log
    logStepStop $log
    exit 1
fi

sequencingToSample=$dataDir/sequencing-to-sample

if [ ! -f $sequencingToSample ]
then
    echo "  Sequencing to sample file '$sequencingToSample' not found!" >> $log
    exit 1
fi

# A simple way to set defaults for our SP_* variables, without causing
# problems by using test when set -e is active (causing scripts to exit
# with status 1 and no explanation).
echo ${SP_SIMULATE:=0} ${SP_SKIP:=0} ${SP_FORCE:=0} >/dev/null

function stepName()
{
    # The step name is the basename of our parent directory.
    # E.g., 03-bwa-mem.
    echo $(basename $(/bin/pwd))
}

function sampleName()
{
    # The sample name is the basename of the directory name of our parent.
    # E.g., NEO999.
    echo $(basename $(dirname $(/bin/pwd)))
}

function tasksForSample()
{
    local sample=$(sampleName)

    # Emit a task for all sequencing files that correspond to this sample.
    # The task names are the FASTQ file names for this sample, minus the
    # .trim.fastq.gz suffix. The sequencing to sample file has lines that
    # contain the FASTQ file location followed by a space and then the
    # sample name (which is why we have a .* at the end of the sed - to
    # also remove the sample name).
    tasks=$(egrep " $sample\$" $sequencingToSample | cut -f1 -d' ')

    if [ -z "$tasks" ]
    then
        echo "  No matches for sample '$sample' found in $sequencingToSample!" >> $log
        exit 1
    fi

    echo $tasks
}

function taskToMappedFastq()
{
    local task=$1
    local log=$2
    local sample=$(sampleName)
    local dir="/rds/project/djs200/rds-djs200-acorg/bt/projects/eske/bronze/pipelines/initial/$sample/02-map"

    if [ ! -d $root ]
    then
        echo "  Mapped data directory '$dir' does not exist." >> $log
        exit 1
    fi

    echo "$dir/$task-unmapped.fastq.gz"
}

function logStepStart()
{
    # Pass a log file name.
    case $# in
        1) echo "$(stepName) (SLURM job $SLURM_JOB_ID) started at $(date) on $(hostname)." >> $1;;
        *) echo "logStepStart must be called with 2 arguments." >&2;;
    esac
}

function logStepStop()
{
    # Pass a log file name.
    case $# in
        1) echo "$(basename $(pwd)) (SLURM job $SLURM_JOB_ID) stopped at $(date)" >> $1; echo >> $1;;
        *) echo "logStepStop must be called with 2 arguments." >&2;;
    esac
}

function logTaskToSlurmOutput()
{
    local task=$1
    local log=$2

    # The following will appear in the slurm-*.out (because we don't
    # redirect it to $log). This is useful if there is an error that only
    # appears in the SLURM output, file because it tells us what sample log
    # file to go look at, to re-run, etc.
    echo "Task $task (SLURM job $SLURM_JOB_ID) started at $(date)"
    echo "Task log file is $log"
}

function checkFastq()
{
    local fastq=$1
    local log=$2

    set +e
    if [ -f $fastq ]
    then
        echo "  FASTQ file '$fastq' exists." >> $log
    else
        echo "  FASTQ file '$fastq' does not exist, according to test -f." >> $log

        if [ -L $fastq ]
        then
            dest=$(readlink $fastq)
            echo "  $fastq is a symlink to $dest." >> $log

            if [ ! -f $dest ]
            then
                echo "  Linked-to file '$dest' does not exist, according to test -f." >> $log
            fi

            echo "  Attempting to use zcat to read the destination file '$dest'." >> $log
            # zcat $dest | head >/dev/null
            zcat $dest | head >>$log 2>&1
            case $? in
                0) echo "    zcat read succeeded." >> $log;;
                *) echo "    zcat read failed." >> $log;;
            esac

            echo "  Attempting to use zcat to read the link '$fastq'." >> $log
            zcat $fastq | head >>$log 2>&1
            # zcat $fastq | head >/dev/null
            case $? in
                0) echo "    zcat read succeeded." >> $log;;
                *) echo "    zcat read failed." >> $log;;
            esac
        fi

        echo "  Sleeping to see if '$fastq' becomes available." >> $log
        sleep 3

        if [ ! -f $fastq ]
        then
            echo "  FASTQ file '$fastq' still does not exist, according to test -f." >> $log
            logStepStop $log
            exit 1
        fi
    fi
    set -e
}

function rmFileAndLink()
{
    for file in "$@"
    do
        if [ -L $file ]
        then
            rm -f $(readlink $file)
        fi
        rm -f $file
    done
}
