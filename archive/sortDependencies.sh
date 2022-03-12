file_contains_string(){
    if grep -q "$2" "$1"; then
        true
    else 
        false
    fi
}

python3 parseDependency.py > searchResults/javaRepo/dependencyUsage

echo -n > searchResults/javaRepo/tmp

while read -r line; do
    dependencyId=${line% *}
    if file_contains_string searchResults/javaRepo/tmp "$dependencyId ";then
        continue
    fi
    clientNum=`grep "^$dependencyId " searchResults/javaRepo/dependencyUsage | wc -l`
    echo $dependencyId $clientNum >> searchResults/javaRepo/tmp
done < searchResults/javaRepo/dependencyUsage

cat searchResults/javaRepo/tmp | sort -nr -k 2 | uniq > searchResults/javaRepo/dependencyRank
rm searchResults/javaRepo/tmp