#!/bin/bash

#1.Denoise DWI (MRtrix)

dwidenoise dwi_raw.nii.gz dwi_denoise.mif -noise noise.mif

#2. Unringing

mrdegibbs dwi_denoise.mif dwi_den_unr.mif  -axes 0,1

#3. Motion and Distortion correction

 # Extraction b0

dwiextract dwi_den_unr.mif --bzero | mrmath - mean mean_b0_AP.mif -axis 3
 
 # calculating b0 in reverse phase encoded direction

mrconvert b0_PA/ - | mrmath - mean mean_b0_PA.mif -axis 3

 # Concatenate 2 AP and PA images

mrcat mean_b0_AP.mif mean_b0_PA.mif -axis 3 b0_pair.mif


 # Preprocessing

 dwipreproc dwi_den_unr.mif dwi_den_unr_preproc.mif -pe_dir AP -rpe_pair -se_epi b0_pair.mif -eddy_options “--slm=linear”

#4.Bias field correction

# Purpose: Improve brain mask estimation


dwibiascorrect -fsl  dwi_den_unr_preproc.mif dwi_den_unr_preproc_unbiase 	d.mif -bias bias.mif


#5. Brain mask estimation


dwi2mask dwi_den_unr_preproc_unbiased.mif  mask_den_unr_preproc_unb.mif



#6. Fiber orientation distribution

dwi2response dhollander dwi_den_unr_preproc_unbiased.mif wm.txt gm.txt csf.txt -voxels voxels.mif


#7. Estimation of Fiber orientation distribution ( FOD )
# Purpose : In every voxel estimate the orientation of the distribution of voxels

dwi2fod msmt_csd dwi_den_unr_preproc_unbiased.mif -mask mask_den_unr_preproc_unb.mif wm.txt wmfod.mif gm.txt gmfod.mif csf.txt csffod.mif 

# Response function estimation


mrconvert -coord 3 0 wmfod.mif - | mrcat csffod.mif gmfod.mif - vf.mif mrview vf.mif -odf.load_sh wmfod.mif


#8. Intensity normalization


mtnormalise wmfod.mif wmfod_norm.mif gmfod.mif gmfod_norm.mif csffod.mif csffod_norm.mif -mask mask_den_unr_preproc_unb.mif 



#......... Creation of whole brain tractogram...........###

# 4.1 Preparing Anatomically Constrained Tractography (ACT)

# copy 5tt_nocoreg.mif into diffusion folder



dwiextract dwi_den_unr_preproc_unbiased.mif --bzero | mrmath - mean mean_b0_preprocessed.mif -axis 3

mrconvert mean_b0_preprocessed.mif mean_b0_preprocessed.nii.gz mrconvert 5tt_nocoreg.mif 5tt_nocoreg.nii.gz 

flirt -in mean_b0_preprocessed.nii.gz -ref 5tt_nocoreg.nii.gz -interp nearestneighbour -dof 6 -omat diff2struct_fsl.mat

transformconvert diff2struct_fsl.mat mean_b0_preprocessed.nii.gz 5tt_nocoreg.nii.gz flirt_import diff2struct_mrtrix.txt

mrtransform 5tt_nocoreg.mif  -linear diff2struct_mrtrix.txt -inverse 5tt_coreg.mif


#4.1.2 Preparing a mask of streamline seeding

5tt2gmwmi 5tt_coreg.mif gmwmSeed_coreg.mif

#4.2 Creating streamlines

tckgen -act 5tt_coreg.mif -backtrack -seed_gmwmi gmwm Seed_coreg.mif -select 10000000 wmfod_norm.mif tracks_10mio.tck

# Reducing 10Million to 20K

tckedit tracks_10mio.tck  -number 200k smallerTracks_200k.tck

# Reducing the streamlines to 1Million

tcksift -act 5tt_coreg.mif -term_number 1000000 tracks_10mio.tck wmfod_norm.mif sift_1mio.tck



#........ 5. Connectome construction.........#


#5.1 :Preparing an atlas for structural connectivity analysis



tck2connectome -symmetric -zero_diagonal -scale_invnodevol tracks_1mio.tck hcpmmp1_parcels_coreg.mif  hcpmmp1.csv  -out_assignment  assignments_hcpmmp1.csv





















 




