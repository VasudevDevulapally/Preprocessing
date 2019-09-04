#!/bin/bash

 # Preparing a parcellation image for structural connectivity analysis


# 1. Convert the raw T1.mif image to nifti -format, which is necessary for subsequent analyses
mrconvert T1_raw.mif T1_raw.nii.gz

# 2. Since the HCP-MMP1 -atlas is a FreeSurfer -based atlas, you have to preprocess the T1 image in FreeSurfer. This will take several hours to complete. 

recon -all –s subject –i T1_raw .nii.gz – all

# 3. Map the annotation files of the HCP MMP 1.0 atlas from fsaverage to you subject. Remember to do that for both hemispheres: 

mri_surf2surf --srcsubject fsaverage --trgsubject subject -- hemi lh --sval -annot $SUBJECTS_DIR/fsaverage/label/lh.glasser.annot --tval $SUBJECTS_DIR/snake/label/lh.HCP-MMP1.annot

mri_surf2surf --srcsubject fsaverage --trgsubject subject --hemi rh --sval -annot $SUBJECTS_DIR/fsaverage/label/rh.glasser.annot --tval $SUBJECTS_DIR/snake/label/rh.HCP-MMP1.annot


# 4. Map the HCP MMP 1.0 annotations onto the volumetric image and add (FreeSurfer -specific) subcortical segmentation. Convert the resulting file to .mif format (use datatype uint32, which is liked best by MRtrix).

mri_aparc2aseg --old -ribbon --s subject --annot HCP-MMP1  --o HCP-MMP1.mgz mrconvert –datatype uint32 HCP-MMP1.mgz HCP-MMP1.mif

# 5. Replace the random integers of the HCP-MMP1.mif file with integers that start at 1 and increase by 1.

labelconvert HCP-MMP1.mif ../Supplementary_Files/HCP-MMP1_original.txt ../Supplementary_Files/HCP-MMP1_ordered.txt HCP-MMP1_parcels_nocoreg.mif

# 6. Register the ordered atlas -based volumetric parcellation to diffusion space.

mrtransform HCP-MMP1_parcels_nocoreg.mif –linear diff2struct_mrtrix.txt –inverse –datatype uint32 HCP-MMP1_parcels_coreg.mif
