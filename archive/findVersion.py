import sys


if __name__ == '__main__':
    targetPom = sys.argv[1]
    libId = sys.argv[2].strip()  # junit:junit
    inTarget1=False
    inTarget2=False
    found=False
    version=""
    groupId=libId.split(":")[0]
    artifactId=libId.split(":")[1]
    with open(targetPom) as pom:
        for line in pom:
            if ("<groupId>"+ groupId +"</groupId>") in line:
                inTarget1=True
            if inTarget1 and ("<artifactId>"+ groupId +"</artifactId>") in line:
                inTarget2=True
            if inTarget1 and inTarget2 and "</version>" in line:
                ridx = line.rindex("</version>")
                lidx = line.index("<version>") + 9
                version=line[lidx : ridx]
                found=True
                inTarget1=False
                inTarget2=False
                break
            if "</dependency>" in line:
                inTarget1=False
                inTarget2=False
    print(version)