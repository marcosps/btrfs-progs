#include <inttypes.h>
#include <stdlib.h>
#include <ext2fs/ext2_fs.h>
#include <ext2fs/ext2fs.h>

static int __ext2_add_one_block(ext2_filsys fs, char *bitmap,
				unsigned long group_nr)
{
	unsigned long offset;
	unsigned i;

	offset = fs->super->s_first_data_block;
	offset /= EXT2FS_CLUSTER_RATIO(fs);
	offset += group_nr * EXT2_CLUSTERS_PER_GROUP(fs->super);
	for (i = 0; i < EXT2_CLUSTERS_PER_GROUP(fs->super); i++) {
		if ((i + offset) >= ext2fs_blocks_count(fs->super))
			break;

		if (!ext2fs_test_bit(i, bitmap)) {
			fprintf(stderr, "%s test bit failed for i == %u, offset: %lu\n", __func__, i, offset);
			return -1;
		}
	}
	return 0;
}

int main (int argc, char**argv)
{
	errcode_t ret;
	ext2_filsys ext2_fs;
	ext2_ino_t ino;
	uint32_t ro_feature;
	int open_flag = EXT2_FLAG_SOFTSUPP_FEATURES | EXT2_FLAG_64BITS;
	blk_t blk_itr;
	/*struct cache_tree *used_tree = &cctx->used_space;*/
	char *block_bitmap = NULL;
	unsigned long i;
	int block_nbytes;

	ret = ext2fs_open(argv[1], open_flag, 0, 0, unix_io_manager, &ext2_fs);
	if (ret) {
		if (ret != EXT2_ET_BAD_MAGIC)
			fprintf(stderr, "ext2fs_open: %s\n", error_message(ret));
		return -1;
	}
	/*
	 * We need to know exactly the used space, some RO compat flags like
	 * BIGALLOC will affect how used space is present.
	 * So we need manuall check any unsupported RO compat flags
	 */
	ro_feature = ext2_fs->super->s_feature_ro_compat;
	if (ro_feature & ~EXT2_LIB_FEATURE_RO_COMPAT_SUPP) {
		fprintf(stderr,
"unsupported RO features detected: %x, abort convert to avoid possible corruption",
		      ro_feature & ~EXT2_LIB_FEATURE_COMPAT_SUPP);
		return 1;
	}
	ret = ext2fs_read_inode_bitmap(ext2_fs);
	if (ret) {
		fprintf(stderr, "ext2fs_read_inode_bitmap: %s\n",
			error_message(ret));
		return 1;
	}
	ret = ext2fs_read_block_bitmap(ext2_fs);
	if (ret) {
		fprintf(stderr, "ext2fs_read_block_bitmap: %s\n",
			error_message(ret));
		return 1;
	}
	/*
	 * search each block group for a free inode. this set up
	 * uninit block/inode bitmaps appropriately.
	 */
	ino = 1;
	while (ino <= ext2_fs->super->s_inodes_count) {
		ext2_ino_t foo;
		ext2fs_new_inode(ext2_fs, ino, 0, NULL, &foo);
		ino += EXT2_INODES_PER_GROUP(ext2_fs->super);
	}

	if (!(ext2_fs->super->s_feature_incompat &
	      EXT2_FEATURE_INCOMPAT_FILETYPE)) {
		fprintf(stderr, "filetype feature is missing");
		return 1;
	}

	blk_itr = EXT2FS_B2C(ext2_fs, ext2_fs->super->s_first_data_block);
	block_nbytes = EXT2_CLUSTERS_PER_GROUP(ext2_fs->super) / 8;
	if (!block_nbytes) {
		fprintf(stderr, "EXT2_CLUSTERS_PER_GROUP too small: %llu",
			(unsigned long long)(EXT2_CLUSTERS_PER_GROUP(ext2_fs->super)));
		return -EINVAL;
	}

	block_bitmap = malloc(block_nbytes);
	if (!block_bitmap)
		return -ENOMEM;

	for (i = 0; i < ext2_fs->group_desc_count; i++) {
		ret = ext2fs_get_block_bitmap_range2(ext2_fs->block_map, blk_itr,
						block_nbytes * 8, block_bitmap);
		if (ret) {
			fprintf(stderr, "fail to get bitmap from ext2, %s",
				error_message(ret));
			ret = -EINVAL;
			break;
		}
		ret = __ext2_add_one_block(ext2_fs, block_bitmap, i);
		if (ret < 0) {
			errno = -ret;
			fprintf(stderr, "fail to build used space tree, %m");
			break;
		}
		blk_itr += EXT2_CLUSTERS_PER_GROUP(ext2_fs->super);
	}

	free(block_bitmap);
}
