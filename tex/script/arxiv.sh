#!/bin/bash

set -e
shopt -s globstar

for binderpath in binder*; do
    echo "binderpath ${binderpath}"
    find "${binderpath}" -type f ! \( -name "*.pdf" -o -name "*.tex" -o -name "*.bib" -o -name "*.csv" \) -exec rm -f {} +
done

find . -type f -name '*.jpg' -exec rm -f {} +
find . -type f -name '__init__.py' -exec rm -f {} +
find . -type d -name dishtiny -exec rm -rf {} +
find . -type d -name conduit -exec rm -rf {} +
find . -type d -name docs -exec rm -rf {} +
find . -type d -empty -delete
find . -type l -delete
find -type f -name ".*" -delete; rm -f *~


rm -f arxiv.tar.gz
git checkout bibl.bib
make cleaner
make
make clean
mv bibl.bib main.bib
cp bu1.bbl main.bbl
rm -f main.out main.blg draft.tex
tar -czvf arxiv.tar.gz *
