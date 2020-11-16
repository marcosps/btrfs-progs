#!/bin/bash
# Check if logical-resolve is resolving the paths correctly for different
# subvolume tree configurations. This used to fails when a child subvolume was
# mounted without the parent subvolume being accessible.

source "$TEST_TOP/common"

setup_root_helper
prepare_test_dev

check_prereq btrfs
check_prereq mkfs.btrfs

check_logical_offset_filename()
{
	local filename
	local offset
	offset="$1"
	filename="$2"

	out=$($TOP/btrfs inspect-internal logical-resolve "$offset" "$TEST_MNT")
	if [ ! $filename = $out ]; then
		_fail "logical-resolve failed. Expected $filename but returned $out"
	fi
}

run_check_mkfs_test_dev
run_check_mount_test_dev

# create top subvolume called '@'
run_check $SUDO_HELPER "$TOP/btrfs" subvolume create "$TEST_MNT/@"

# create a file in eacch subvolume of @, and each file will have 2 EXTENT_DATA item
run_check $SUDO_HELPER "$TOP/btrfs" subvolume create "$TEST_MNT/@/vol1"
vol1id=$($SUDO_HELPER "$TOP/btrfs" inspect-internal rootid "$TEST_MNT/@/vol1")
run_check $SUDO_HELPER dd if=/dev/zero bs=1M count=150 of="$TEST_MNT/@/vol1/file1"

run_check $SUDO_HELPER "$TOP/btrfs" subvolume create "$TEST_MNT/@/vol1/subvol1"
subvol1id=$($SUDO_HELPER "$TOP/btrfs" inspect-internal rootid "$TEST_MNT/@/vol1/subvol1")
run_check $SUDO_HELPER dd if=/dev/zero bs=1M count=150 of="$TEST_MNT/@/vol1/subvol1/file2"

"$TOP/btrfs" filesystem sync "$TEST_MNT"

run_check_umount_test_dev

$SUDO_HELPER mount -o subvol=/@/vol1 $TEST_DEV "$TEST_MNT"
for offset in $("$TOP/btrfs" inspect-internal dump-tree -t "$vol1id" \
		"$TEST_DEV" | awk '/disk byte/ { print $5 }'); do
	check_logical_offset_filename "$offset" "$TEST_MNT/file1"
done

run_check_umount_test_dev

$SUDO_HELPER mount -o subvol=/@/vol1/subvol1 $TEST_DEV "$TEST_MNT"
for offset in $("$TOP/btrfs" inspect-internal dump-tree -t "$subvol1id" \
		"$TEST_DEV" | awk '/disk byte/ { print $5 }'); do
	check_logical_offset_filename "$offset" "$TEST_MNT/file2"
done

run_check_umount_test_dev
