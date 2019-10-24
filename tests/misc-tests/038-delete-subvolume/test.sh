#!/bin/bash
# test btrfs subvolume delete --subvolid <volid> <path>

source "$TEST_TOP/common"

check_prereq mkfs.btrfs
check_prereq btrfs

setup_root_helper
prepare_test_dev

run_check_mkfs_test_dev
run_check_mount_test_dev

run_check $SUDO_HELPER "$TOP/btrfs" subvolume create "$TEST_MNT"/mysubvol1
run_check $SUDO_HELPER "$TOP/btrfs" subvolume create "$TEST_MNT"/mysubvol2
run_check $SUDO_HELPER "$TOP/btrfs" subvolume create "$TEST_MNT"/mysubvol3

# subvolid expected failures
run_mustfail "subvolume delete --subvolid expects an integer" \
	$SUDO_HELPER "$TOP/btrfs" subvolume delete --subvolid aaa "$TEST_MNT"

run_mustfail "subvolume delete --subvolid with invalid unexisting subvolume" \
	$SUDO_HELPER "$TOP/btrfs" subvolume delete --subvolid 999 "$TEST_MNT"

run_mustfail "subvolume delete --subvolid expects only one extra argument: the mountpoint" \
	$SUDO_HELPER "$TOP/btrfs" subvolume delete --subvolid 256 "$TEST_MNT" "$TEST_MNT"

# delete the recently created subvol using the subvolid
run_check $SUDO_HELPER "$TOP/btrfs" subvolume delete --subvolid 256 "$TEST_MNT"

run_check_umount_test_dev

run_check_mount_test_dev -o subvol=mysubvol2
# when mounted the subvolume mysubvol3, mysubvol2 is not reachable by the
# current mount point, but "subvolume delete --subvolid " should be able to
# delete it
run_check $SUDO_HELPER "$TOP/btrfs" subvolume delete --subvolid 258 "$TEST_MNT"

run_check_umount_test_dev
