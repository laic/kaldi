#!/bin/bash

## Callhome data prep

# To be run from one directory above this script.

#if [ $# -ne 1 ]; then
 # echo "Usage: $0 <ch-dir>"
 # echo "e.g.: $0 /export/corpora/LDC/LDC2007S10"
 # echo "See comments in the script for more details"
 # exit 1
#fi

#sdir=$1
sdir=/group/project/toyota_slp/data
[ ! -d $sdir/callhome-sph ] \
  && echo Expecting directory $sdir/callhome-sph to be present && exit 1;
[ ! -d $sdir/callhome-trans ] \
  && echo Expecting directory $tdir/callhome-trans present && exit 1;

. ./path.sh

dir=data/local/callhome 
mkdir -p $dir

rtroot=$sdir
tdir=$sdir/callhome-trans-clean
sdir=$sdir/callhome-sph 

## Sph filelist
find $sdir -iname '*.sph' | sort > $dir/sph.flist
sed -e 's?.*/??' -e 's?.sph??' $dir/sph.flist | paste - $dir/sph.flist \
  > $dir/sph.scp

## sph2pipe location
sph2pipe=$KALDI_ROOT/tools/sph2pipe_v2.5/sph2pipe
[ ! -x $sph2pipe ] \
  && echo "Could not execute the sph2pipe program at $sph2pipe" && exit 1;

##  to get wav files, one channel per speakers
echo "* Make wav.scp"
awk -v sph2pipe=$sph2pipe '{
  printf("%s-A %s -f wav -p -c 1 %s |\n", $1, sph2pipe, $2);
  printf("%s-B %s -f wav -p -c 2 %s |\n", $1, sph2pipe, $2);
}' < $dir/sph.scp | sort > $dir/wav.scp || exit 1;
#side A - channel 1, side B - channel 2


# Get segments file...
# segments file format is: utt-id side-id start-time end-time, e.g.:
# sw02001-A_000098-001156 sw02001-A 0.98 11.56
echo "* get segments"
#grep -v ';;' $pem \
cat $tdir/*.txt | grep -v ';;' | grep -v '^#' | grep -v inter_segment_gap \
  | awk '{
           print $1,$2,$3,$4;}' \
  | sort -u > $dir/segments

echo "* get text"
cat $tdir/*.txt | grep -v ';;' | grep -v '^#' \
  | awk '{
           uttid=$1;
	   $1="";
	   $2="";
	   $3="";
	   $4="";
	   #gsub(/[!,.?;:]/, "", $0);
           print uttid,tolower($0);}' \
  | sort > $dir/text #.all

  #> $dir/text #.all
# create an utt2spk file that assumes each conversation side is
# a separate speaker.
echo "* get utt2spk spk2utt" 
awk '{print $1,$2;}' $dir/segments > $dir/utt2spk
utils/utt2spk_to_spk2utt.pl $dir/utt2spk > $dir/spk2utt

awk '{print $1}' $dir/wav.scp \
  | perl -ane '$_ =~ m:^(\S+)-([AB])$: || die "bad label $_";
               print "$1-$2 $1 $2\n"; ' \
  > $dir/reco2file_and_channel || exit 1;


echo "* copy to data/callhome"
dest=data/callhome
mkdir -p $dest
for x in wav.scp segments text utt2spk spk2utt reco2file_and_channel; do
  cp $dir/$x $dest/$x
done

echo Data preparation and formatting completed for CallHome 
echo "(but not MFCC extraction)"
