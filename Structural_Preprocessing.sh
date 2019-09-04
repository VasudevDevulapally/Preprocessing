#!/bin/bash

#1. Brain -Extraction skull stripped

bet T1w.nii.gz T1w_skulled.nii.gz -R

#2.Derive tissue-segmented image (generate 5TT data) (MRtrix)


5ttgen fsl T1w.nii.gz 5tt_nocoreg.mif





