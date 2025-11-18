#!/bin/zsh

set -eo pipefail

orig=gmp-6.3.0

if ! [ -e $orig ]; then
	echo >&2 "error: $orig not found"
fi

if [ $# -lt 1 ]; then
	echo >&2 "error: please specify target"
	exit 2
fi
target="$1"
shift

gmp_target=$target
extra_configure=()
case $target in
	aarch64-macos-none) gmp_target=aarch64-apple-darwin25.1.0 ;;
	x86_64-macos-none) gmp_target=x86_64-apple-darwin25.1.0 ;;
	x86_64-windows-gnu)
		extra_configure+=--disable-assembly ;;
esac

make_args=()
for arg in $*; do
	case $arg in
		-make,*) make_args+=${arg#-make,};;
	esac
done


export ZIG_CC_BUILD=$PWD/.cache/build-$target
export ZIG_CC_TARGET=$PWD/.cache/target-$target

mkdir -p $PWD/.cache
mkdir -p $ZIG_CC_TARGET

if ! [ -e $ZIG_CC_BUILD ]; then
	cp -r $orig $ZIG_CC_BUILD
fi

export PATH=$PWD:$PATH

pushd $ZIG_CC_BUILD

export ZIG_CC_COPY=

if ! [ -e configure-done-stamp ]; then 
	./configure \
		--prefix=$PWD/build \
		--enable-shared=no \
		$extra_configure \
		--host=$gmp_target \
		CC="zig-cc.sh -target $target"
	touch configure-done-stamp
else
	echo skipping configure
fi

export ZIG_CC_COPY=on

if ! [ -e make-done-stamp ]; then
	make $make_args
	touch make-done-stamp
else 
	echo skipping make
fi

export ZIG_CC_COPY=

popd


typeset -A hash_orig
echo -n hashing files...
for file in $orig/**/*.[csh]; do
	hash_orig[$(sha256sum <$file)]=$file
done
echo " done."

echo -n copying generated headers...
for header in $ZIG_CC_BUILD/**/*.h; do 
	relative=${header#$ZIG_CC_BUILD/}

	if ! [ -e $orig/$relative ]; then
		dest=$target/$relative
		mkdir -p ${dest%/*}
		cp -v $header $dest
	fi
done
echo " done."


gen_zon() {
	echo ".{"
	for args in $ZIG_CC_TARGET/**/*.args; do
		file=${args%.args}
		orig=$hash_orig[$(sha256sum <$file)]

		if [ -z "$orig" ]; then
			src=$target/${file#$ZIG_CC_TARGET/}
			mkdir -p ${src%/*}
			cp $file $src
		else 
			src=$orig
		fi
		flags=($(<$args))

		echo -n "    .{ .file = \"$src\", .flags = .{"

		if ! [ ${src##*.} = s ]; then
			echo -n " \"$flags[1]"\"
			for i in {2..$#flags}; do 
				echo -n "," \"$flags[$i]\"
			done
			echo -n " "
		fi
		echo "} },"
	done
	echo "}"
}

echo -n "generating $target.zon"
gen_zon >$target.zon
echo " done."
