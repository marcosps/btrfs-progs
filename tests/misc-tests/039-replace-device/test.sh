#!/bin/bash
#
# test the different arguments accepted by "btrfs replace"

source "$TEST_TOP/common"

check_prereq mkfs.btrfs
check_prereq btrfs

setup_root_helper

setup_loopdevs 2
prepare_loopdevs
dev1=${loopdevs[1]}
dev2=${loopdevs[2]}

# resize only works with disk size bigger than the replaced disk
run_check_stdout truncate -s3g `pwd`/img3
dev3=`run_check_stdout $SUDO_HELPER losetup --find --show $(pwd)/img3`

test()
{
	local srcdev
	local final_size
	local resize_arg
	srcdev="$1"
	final_size="$2"
	resize_arg="$3"
	args="-B -f"

	if [ -n "$resize_arg" ]; then
		args="$args --autoresize"
	fi

	run_check $SUDO_HELPER "$TOP/mkfs.btrfs" -f "$dev1" "$dev2"
	TEST_DEV="$dev1"

	run_check_mount_test_dev
	run_check_stdout $SUDO_HELPER "$TOP/btrfs" replace start $args "$srcdev" "$dev3" "$TEST_MNT"
	run_check_stdout $SUDO_HELPER "$TOP/btrfs" filesystem usage "$TEST_MNT" | head -2 | \
			grep -q "$final_size\\.00GiB"
	[ $? -eq 1 ] && _fail "Device size don't match. Expected size: $final_size\\.00GiB"
	run_check_umount_test_dev
}

# test replace using devid and path, and also test the final fs size when
# --autoresize is passed, executing the replace + resize in just one command.
test 2 4
test 2 5 true
test "$dev2" 4
test "$dev2" 5 true

run_check $SUDO_HELPER losetup -d "$dev3"
rm `pwd`/img3

cleanup_loopdevs
