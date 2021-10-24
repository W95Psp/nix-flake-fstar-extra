#!/usr/bin/env bash

TEMP=$(mktemp -d '/tmp/find-fstar-versions-XXX')
FILES="$TEMP/repo"
DOTGIT="$TEMP/dotgit"
DB="$TEMP/db"
DB_JSON="db.json"
mkdir -p "$FILES"

clear () {
    echo "Exiting, cleaning '$TEMP'"
    rm -rf "$TEMP"
    exit
}
trap clear SIGINT EXIT

git clone --separate-git-dir "$DOTGIT" "https://github.com/FStarLang/fstar" "$FILES"

touch "$DB"

git --git-dir "$DOTGIT" log --pretty=format:'%H %ct' --first-parent master --after="2021-01-01" --before="today" |
    while read commit timestamp; do
	echo "[$commit]"
        grep -q "$commit" "$DB" && {
	    echo "  Already processed."
	    continue
	}
	git --work-tree="$FILES" --git-dir "$DOTGIT" checkout --force --quiet "$commit"
        lexer=$(grep -q sedlex "$FILES/INSTALL.md" 2>/dev/null && echo "sedlex" || echo "ulex")
	rm -f "$FILES/.git"
	hash=$(nix-hash --type "sha256" --base32 "$FILES")
	echo "  Done!"
	echo "$timestamp $commit $hash $lexer" >> "$DB"
    done

{
    jq -Rs 'split("\n") | map(select(length > 0) | split(" ") | {timestamp: .[0]|tonumber, commit: .[1], hash: .[2], lexer: .[3]})' <"$DB"
} > "$DB_JSON"

