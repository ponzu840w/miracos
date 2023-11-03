 awk 'BEGIN{FS=","} /^\.BYTE/{printf($1","$2/2"\n")}' | grep "\.5" -n

