#!/bin/bash -e

#SBATCH -J bwa-mem
#SBATCH -A ACORG-SL2-CPU
#SBATCH -o slurm-%A.out
#SBATCH -p skylake
#SBATCH --time=01:00:00

task=$1

srun -n 1 bwa-mem.sh $task
