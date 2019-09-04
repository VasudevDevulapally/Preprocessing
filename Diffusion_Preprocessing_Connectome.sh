#!/bin/bash

#!/bin/bash

# Path for Mrtrix and FSL

FSLDIR=/BioInformatics/soft/fsl_installed
. ${FSLDIR}/etc/fslconf/fsl.sh
PATH=${FSLDIR}/bin:${PATH}
export FSLDIR PATH

#MrTrix path
cd /BioInformatics/soft/mrtrix3 
./set_path ~/.bash_profile
export PATH="$(pwd)/bin:$PATH"

SUBJECTS_DIR=/BioInformatics/Bmax_neuro/data/imaging_data/biomax/Example/KON11


#1.Denoise DWI (MRtrix)


dwidenoise $SUBJECTS_DIR/$i.nii.gz $SUBJECTS_DIR/dwi_denoise.mif

#2. Unringing

mrdegibbs -axes 0,1 $SUBJECTS_DIR/dwi_denoise.mif $SUBJECTS_DIR/dwi_den_unr.mif

#3. Motion and Distortion correction

 # Extraction b0

dwiextract $SUBJECTS_DIR/dwi_den_unr.mif - -bzero -fslgrad $SUBJECTS_DIR/bvecs $SUBJECTS_DIR/bvals | mrmath - mean $SUBJECTS_DIR/mean_b0_AP.mif -axis 3
 
 # calculating b0 in reverse phase encoded direction

mrconvert $SUBJECTS_DIR/dwi_den_unr.mif - | mrmath - mean $SUBJECTS_DIR/mean_b0_PA.mif  -axis 3

#mrconvert b0_PA/ - | mrmath - mean mean_b0_PA.mif -axis 3

 # Concatenate 2 AP and PA images

mrcat $SUBJECTS_DIR/mean_b0_AP.mif $SUBJECTS_DIR/mean_b0_PA.mif -axis 3 $SUBJECTS_DIR/b0_pair.mif


 # Preprocessing

 dwipreproc $SUBJECTS_DIR/dwi_den_unr.mif $SUBJECTS_DIR/dwi_den_unr_preproc.mif -pe_dir AP -rpe_pair -se_epi $SUBJECTS_DIR/b0_pair.mif -fslgrad $SUBJECTS_DIR/bvecs $SUBJECTS_DIR/bvals -eddy_options " --slm=linear "


#4.Bias field correction

# Purpose: Improve brain mask estimation


dwibiascorrect -fsl -fslgrad $SUBJECTS_DIR/bvecs $SUBJECTS_DIR/bvals $SUBJECTS_DIR/dwi_den_unr_preproc.mif $SUBJECTS_DIR/dwi_den_unr_preproc_unbiased.mif
#5. Brain mask estimation


dwi2mask $SUBJECTS_DIR/dwi_den_unr_preproc_unbiased.mif  $SUBJECTS_DIR/mask_den_unr_preproc_unb.mif



#6. Fiber orientation distribution

dwi2response dhollander $SUBJECTS_DIR/dwi_den_unr_preproc_unbiased.mif $SUBJECTS_DIR/wm.txt $SUBJECTS_DIR/gm.txt $SUBJECTS_DIR/csf.txt	


#7. Estimation of Fiber orientation distribution ( FOD )
# Purpose : In every voxel estimate the orientation of the distribution of voxels

dwi2fod msmt_csd $SUBJECTS_DIR/dwi_den_unr_preproc_unbiased.mif -mask $SUBJECTS_DIR/mask_den_unr_preproc_unb.mif $SUBJECTS_DIR/wm.txt $SUBJECTS_DIR/wmfod.mif $SUBJECTS_DIR/gm.txt $SUBJECTS_DIR/gmfod.mif $SUBJECTS_DIR/csf.txt $SUBJECTS_DIR/csffod.mif 

# Response function estimation


mrconvert -coord 3 0 $SUBJECTS_DIR/wmfod.mif - | mrcat $SUBJECTS_DIR/csffod.mif $SUBJECTS_DIR/gmfod.mif - $SUBJECTS_DIR/vf.mif


#8. Intensity normalization


mtnormalise $SUBJECTS_DIR/wmfod.mif $SUBJECTS_DIR/wmfod_norm.mif $SUBJECTS_DIR/csffod.mif $SUBJECTS_DIR/csffod_norm.mif -mask $SUBJECTS_DIR/mask_den_unr_preproc_unb.mif


#......... Creation of whole brain tractogram...........###

# 4.1 Preparing Anatomically Constrained Tractography (ACT)

# copy 5tt_nocoreg.mif into diffusion folder



dwiextract $SUBJECTS_DIR/dwi_den_unr_preproc_unbiased.mif - -bzero | mrmath - mean $SUBJECTS_DIR/mean_b0_preprocessed.mif -axis 3

mrconvert $SUBJECTS_DIR/mean_b0_preprocessed.mif $SUBJECTS_DIR/mean_b0_preprocessed.nii.gz 

mrconvert $SUBJECTS_DIR/5tt_nocoreg.mif $SUBJECTS_DIR/5tt_nocoreg.nii.gz 

flirt -in $SUBJECTS_DIR/5tt_nocoreg.nii.gz -ref $SUBJECTS_DIR/mean_b0_preprocessed.nii.gz -interp nearestneighbour -dof 6 -omat $SUBJECTS_DIR/diff2struct_fsl.mat

transformconvert $SUBJECTS_DIR/diff2struct_fsl.mat $SUBJECTS_DIR/mean_b0_preprocessed.nii.gz $SUBJECTS_DIR/5tt_nocoreg.nii.gz flirt_import $SUBJECTS_DIR/diff2struct_mrtrix.txt

mrtransform $SUBJECTS_DIR/5tt_nocoreg.mif  -linear $SUBJECTS_DIR/diff2struct_mrtrix.txt -inverse $SUBJECTS_DIR/5tt_coreg.mif

#flirt -in 5tt_nocoreg.nii.gz -ref mean_b0_preprocessed.nii.gz -interp nearestneighbour -dof 6 -omat T1walignDWI_fsl.mat
#transformconvert T1walignDWI_fsl.mat mean_b0_preprocessed.nii.gz 5tt_nocoreg.nii.gz flirt_import diff2struct_mrtrix.txt


#4.1.2 Preparing a mask of streamline seeding

5tt2gmwmi $SUBJECTS_DIR/5tt_coreg.mif $SUBJECTS_DIR/gmwmSeed_coreg.mif

#4.2 Creating streamlines

tckgen -act $SUBJECTS_DIR/5tt_coreg.mif -backtrack -seed_gmwmi $SUBJECTS_DIR/gmwmSeed_coreg.mif -select 10000000 $SUBJECTS_DIR/wmfod_norm.mif $SUBJECTS_DIR/tracks_10mio.tck

# Reducing 10Million to 20K

#tckedit tracks_10mio.tck  -number 200k smallerTracks_200k.tck

# Reducing the streamlines to 1Million

tcksift -act $SUBJECTS_DIR/5tt_coreg.mif -term_number 1000000 $SUBJECTS_DIR/tracks_10mio.tck $SUBJECTS_DIR/wmfod_norm.mif $SUBJECTS_DIR/sift_1mio.tck



#........ 5. Connectome construction.........#


#5.1 :Preparing an atlas for structural connectivity analysis

tck2connectome -symmetric -zero_diagonal -scale_invnodevol $SUBJECTS_DIR/sift_1mio.tck $SUBJECTS_DIR/hcpmmp1_parcels_coreg.mif  $SUBJECTS_DIR/hcpmmp1.csv  -out_assignment  $SUBJECTS_DIR/assignments_hcpmmp1.csv

done


