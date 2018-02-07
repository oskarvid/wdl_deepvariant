#!/bin/bash
if [ $# -lt 2 ]; then
  echo "Usage: $0 file1.vcf file2.vcf"
  echo -e "Outputs a list of shared positions and a list of unique positions per file. \nAs well as a short summary of the number of positions per file in the terminal window."
  exit 1
fi

awk '{print $2}' $1 | sed -e 's/[^0-9]*//g' -e '/^\s*$/d' | sort > $1_positions
awk '{print $2}' $2 | sed -e 's/[^0-9]*//g' -e '/^\s*$/d' | sort > $2_positions

comm -12 $1_positions $2_positions > shared_positions #this creates a list of al shared positions

comm -3 shared_positions $1_positions > $1_unique_positions #this creates a list of positions unique to the first file.
comm -3 shared_positions $2_positions > $2_unique_positions #this does the same but for the second file

output1=$(grep -c ^ $1_positions)
output2=$(grep -c ^ $1_unique_positions)
fbname=$(basename "$1")
echo "$fbname has $output1 positions and $output2 unique positions."
echo "$fbname has $output1 positions and $output2 unique positions." >> compare-positions-summary

output3=$(grep -c ^ $2_positions)
output4=$(grep -c ^ $2_unique_positions)
fbname=$(basename "$2")
echo "$fbname has $output3 positions and $output4 unique positions."
echo "$fbname has $output3 positions and $output4 unique positions." >> compare-positions-summary

#echo "File 1 has $output3"
#echo "File 2 has $output4"
output5=$(grep -c ^ shared_positions)
echo "They have $output5 shared positions."
echo "They have $output5 shared positions." >> compare-positions-summary
