set -f line (rg ' (TODO|XXX): ')

for i in $line
	set -l file (echo $i | cut -d: -f1)
	set -l type (echo $i | cut -d: -f2)
	set -l text (echo $i | cut -d: -f3-)

	if test $type = "TODO"
		set_color yellow
	else if test $type = "XXX"
		set_color red
	else
		set_color cyan
	end

	# echo -n "$text"
	# set_color normal
	# echo -e "\t\t$file"
	string pad "$text" "$file"
end
