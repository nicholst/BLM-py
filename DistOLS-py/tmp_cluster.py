import glob
import nibabel as nib
import os
import distOLS_main
import numpy as np

def main():

    # Read in the list of NIFTI's needed for this OLS.
    analydir = '/well/nichols/users/kfh142/data';
    os.chdir(analydir);
    Y_files = glob.glob("IMAGEN/spmstatsintra/*/SessionB/EPI_short_MID/swea/con_0010.nii")

    # Design matrix and number of parameters.
    X = np.ones([1815, 1])

    #distOLS_main.main(Y_files, X)
    print(repr(Y_files[1:20]))


if __name__ == "__main__":
    main()