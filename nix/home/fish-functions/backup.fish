function backup
  for
  file in $argv
set -l target "$file.backup-$(date +'%Y.%m.%d-%H.%M.%S')"

while test -f "$target"
set -l target "$file.backup-$(date +'%Y.%m.%d-%H.%M.%S')"
sleep 1
end

cp -aRv "$file" "$target"
end
end
