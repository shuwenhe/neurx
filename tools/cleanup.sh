#!/bin/bash

BASEDIR="${1:-.}"

cleanup_file() {
	local file="$1"
	local temp_file="${file}.tmp"

	{
		# 第一遍：去除注释
		sed -e ':a' -e '$!{N;ba' -e '}' -e 's/\/\*[^*]*\*\+\([^/*][^*]*\*\+\)*\///g' "$file" |
		sed 's#//.*$##g' |

		# 第二遍：去除多余空行
		{
			blank_count=0
			while IFS= read -r line; do
				if [[ -z "$(echo "$line" | sed 's/^[[:space:]]*$//')" ]]; then
					((blank_count++))
					if (( blank_count <= 1 )); then
						echo ""
					fi
				else
					blank_count=0
					echo "$line"
				fi
			done
		} |

		# 第三遍：确保 func/struct 之间有空行
		{
			prev_line=""
			while IFS= read -r line; do
				trimmed="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

				if [[ -n "$prev_line" ]]; then
					prev_trimmed="$(echo "$prev_line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

					if [[ "$prev_trimmed" =~ ^(func|struct) ]] && [[ "$prev_trimmed" =~ \{$ ]]; then
						if [[ "$trimmed" =~ ^(func|struct) ]] && [[ "$trimmed" != "" ]]; then
							# 检查前面是否已经有空行
							if [[ -n "$prev_line" ]]; then
								echo ""
							fi
						fi
					fi
				fi

				echo "$line"
				prev_line="$line"
			done
		}
	} > "$temp_file"

	# 删除末尾空白并保留单个换行符
	sed -i -e :a -e '/^\s*$/d;N;ba' "$temp_file"
	echo "" >> "$temp_file"

	mv "$temp_file" "$file"
}

find "$BASEDIR" -type f -name "*.s" ! -path "*/.git/*" | while read -r file; do
	echo "Cleaning: $file"
	cleanup_file "$file"
done

echo "Code cleanup completed successfully!"
