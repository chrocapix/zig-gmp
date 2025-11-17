#!/bin/zsh

set -e

if ! [ -z "$ZIG_CC_COPY" ]; then

	args=()
	i=1
	while (( i <= $# )) do

		case $*[$i] in
			-target) ((i+=1));;
			-c) ;;
			-o) ((i+=1)) ;;

			-I) ((i+=1)) ;;
			-I*) ;;

			-O*) ;;
			-fomit-frame-pointer) ;;

			-march=*) ;;
			-mtune=*) ;;
			-mcpu=*) ;;


			*.[cs]) src=$*[$i];;

			*) args+=$*[$i] ;;
		esac


		((i+=1))
	done

	src=$PWD/$src

	relative=${src#$ZIG_CC_BUILD}
	relative=${relative##/}

	target=$ZIG_CC_TARGET/$relative
	target_dir=${target%/*}

	mkdir -p $target_dir
	cp $src $target
	echo $args >$target.args

fi

exec zig cc $*
