# This script search the content among all github projects, and put the result in `searchResults`.

# check my rate limit
# curl \
#   -H "Accept: application/vnd.github.v3+json" \
#   -H "Authorization: Token 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" \
#   https://api.github.com/rate_limit

file_contains_string(){
    if grep -q "$2" "$1"; then
        true
    else 
        false
    fi
}

resultDir=searchResults/javaRepoWithPom
[ ! -d $resultDir ] && mkdir -p $resultDir
token="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"

for i in {1..10}; do
    while [ ! -f $resultDir/$i.json ] || file_contains_string $resultDir/$i.json "exceeded a secondary rate limit" || [ `cat "$resultDir/$i.json" | grep \"score\": | wc -l` -lt 95 ]; do
        echo searching for the $i page
        curl -D $resultDir/header.log "https://api.github.com/search/repositories?q=language:java&sort=stars&per_page=100&page=$i" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: Token $token" > $resultDir/$i.json 2> /dev/null
        echo -n "sleeping...  "
        for (( j=60; j>0; j--)); do
            sleep 1
            if [ $j -le 8 ];then
                printf "\b$j"
            else
                printf "\b\b$j"
            fi
        done
        printf "\n"
    done
    if file_contains_string $resultDir/$i.json "API rate limit exceeded"; then
        echo "[ERROR] API rate limit exceeded !!!"
        exit 1
    fi
done

