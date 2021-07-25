progsinstallation() {
    # Get the progsfile and delete the header.
    [ -f "$progsfile" ] && cat "$progsfile" | sed '/^#/d' > /tmp/progs.csv

    total=$(wc -l < /tmp/progs.csv)

    # Use , as the delimeter.
    while IFS=, read -r tag program comment; do
        # Indication of how many programs we have installed so far.
        n=$((n+1))

        # Remove the "" from the comment.
        comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"

        case "$(echo $tag | head -c 1)" in
            "U") echo "urlinstall $tag $program $comment" ;;
            "A") echo "aurinstall $program $comment" ;;
            *) echo "maininstall $program $comment" ;;
        esac
    done < /tmp/progs.csv
}



progsfile="progs.csv"
progsinstallation
