#!/bin/bash -e

#SBATCH -J collect
#SBATCH -A ACORG-SL2-CPU
#SBATCH -o slurm-%A.out
#SBATCH -p skylake
#SBATCH --time=00:30:00

srun -n 1 collect.sh
