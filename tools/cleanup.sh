#!/bin/bash

BASEDIR="${1:-.}"

cleanup_file() {
	local file="$1"
	local temp_file="${file}.tmp"

	{

		sed -e ':a' -e '$!{N;ba' -e '}' -e 's/\/\*[^*]*\*\+\([^/*][^*]*\*\+\)*\///g' "$file" |
		sed 's#//.*$##g' |

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

		{
			prev_line=""
			while IFS= read -r line; do
				trimmed="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

				if [[ -n "$prev_line" ]]; then
					prev_trimmed="$(echo "$prev_line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

					if [[ "$prev_trimmed" =~ ^(func|struct) ]] && [[ "$prev_trimmed" =~ \{$ ]]; then
						if [[ "$trimmed" =~ ^(func|struct) ]] && [[ "$trimmed" != "" ]]; then

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

	sed -i -e :a -e '/^\s*$/d;N;ba' "$temp_file"
	echo "" >> "$temp_file"

	mv "$temp_file" "$file"
}

find "$BASEDIR" -type f -name "*.s" ! -path "*/.git/*" | while read -r file; do
	echo "Cleaning: $file"
	cleanup_file "$file"
done

echo "Code cleanup completed successfully!"
