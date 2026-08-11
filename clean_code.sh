#!/bin/bash

cleanup_file() {
	local file="$1"
	# 使用 perl 一次性处理所有清理
	perl -i -pe '
		# 去除行注释
		s#//.*$##;

		# 去除块注释会在第二遍处理
	' "$file"

	# 处理块注释
	perl -i -0pe 's#/\*.*?\*/#\n#gs' "$file"

	# 去除多余空行
	perl -i -pe '
		$_ = "" if /^\s*$/;
	' "$file"

	# 再次清理多余空行
	perl -i -ne 'print if /\S/ or (!/\S/ and $prev !~ /^$/)' "$file" << 'END'
	{ $prev = $_; }
END

	# 确保文件以单个换行结束
	perl -i -pe 'chomp; $_ .= "\n"' "$file"
}

echo "Starting cleanup of all .s files..."
find . -name "*.s" -type f ! -path "*/.git/*" | while read file; do
	echo "Processing: $file"
	cleanup_file "$file"
done
echo "Cleanup completed!"
