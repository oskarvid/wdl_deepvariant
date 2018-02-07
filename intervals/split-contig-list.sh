#!/bin/bash
#$1 = number of lists
#$2 = bed-file
#$3 = outputname
#$4 = output folder name

usage() { echo "Usage: $0 \
[-i <input bed file>] \
[-l <desired bed files>] \
[-o <output name>] \
[-d <output directory>] \
" 1>&2; exit 1; }

#---define arguments to take---#
while getopts ':i:l:o:d:' flag; do
  case "${flag}" in
    i)
		i=${OPTARG}
		;;
    l)
		l=${OPTARG}
		;;
    o)
		o=${OPTARG}
		;;
    d)
		d=${OPTARG}
		;;
    *)
		error "Unexpected option ${flag}" 
		;;
  esac
done

shift $((OPTIND-1))

#---check if all arguments were given---#
if [ -z "${i}" ] || [ -z "${l}" ] || [ -z "${o}" ] || [ -z "${d}" ]; then
    usage
fi

SHARDS=${l}
LENGTH=$(grep -c ^ ${i})
SPLITS=$(($LENGTH/$SHARDS))
awk 'NR%'$SPLITS'==1{x="'${o}'"++i;}{print > x}' ${i}
rename 's/$/.bed/' ${o}*
mkdir ${d}
mv ${o}* ${d}