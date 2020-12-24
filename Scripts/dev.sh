#! /bin/bash

shopt -s nocasematch

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SOURCE_ROOT_DIR="$SCRIPT_DIR/.."

# Generate documentation.
docs()
{
	CMD=$1
	if [[ "$CMD" == "install" ]]; then
		FILTER=$2
	else
		FILTER=$1
	fi
	
	if [[ "$FILTER" == "pd" ]] || [[ "$FILTER" == "" ]]; then
		printf "Generate draft-bradley-dnssd-private-discovery...\n"
		mmark draft-bradley-dnssd-private-discovery.md > draft-bradley-dnssd-private-discovery.xml &&
		xml2rfc --v3 --html draft-bradley-dnssd-private-discovery.xml -o draft-bradley-dnssd-private-discovery.html &&
		xml2rfc --v3 --text draft-bradley-dnssd-private-discovery.xml -o draft-bradley-dnssd-private-discovery.txt
		if [[ $? -ne 0 ]]; then
			echo "### Generate draft-bradley-dnssd-private-discovery failed"
			exit 1
		fi
		rm draft-bradley-dnssd-private-discovery.xml
	fi
	printf "=== All Documentation Generated ===\n"
}

# Parse command.
case "$1" in
	docs)
		docs "${@:2}"
		;;
	-h|help|"")
		echo "Development script commands:"
		echo "    docs    Generate documentation."
		echo ""
		;;
	*)
		echo "Unknown command '$1'"
		exit 1
		;;
esac

if [[ $? -ne 0 ]]; then
	echo "==============================="
	echo -e "### $1 FAILED"
	echo "==============================="
	exit 1
fi
