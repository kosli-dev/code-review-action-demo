#!/usr/bin/env bash
set -Eeu

SCRIPT_NAME=demo-code-review.sh
ROOT_DIR=$(dirname $(readlink -f $0))/..
BRANCH_NAME=""

function print_help
{
    cat <<EOF
Usage: $SCRIPT_NAME <options> [BRANCH_NAME]

Script that will makes a branch with commits and pull-request,
and does the correct reporting of the code review attestations

Options are:
  -h          Print this help menu
EOF
}

function check_arguments
{
    while getopts "h" opt; do
        case $opt in
            h)
                print_help
                exit 1
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
        esac
    done

    # Remove options from command line
    shift $((OPTIND-1))

    if [ $# -eq 0 ]; then
        echo "Missing BRANCH_NAME"
    fi
    BRANCH_NAME=$1; shift
}

function wait_for_github_actions
{
    sleep 10
    echo -n "Waiting for GitHub Actions to complete "

    while true; do
        result=$(gh run list --json status)
        # Check if there are any workflows that are not completed
        if echo "$result" | jq -e '.[] | select(.status != "completed")' > /dev/null; then
            echo -n "."
            sleep 2
        else
            break
        fi
    done
    echo
}


function update_content_file
{
    local file=$1; shift
    # Increment the value after counter= in the file
    sed -i -E 's/(counter=)([0-9]+)/echo "\1$((\2+1))"/e' ${file}
    grep "counter=" ${file} | sed "s/counter=//"
}

function wait_for_pr_approval
{
    echo
    echo "*** Approve the PR in github ***"
    echo "After that press 'c' to continue"
    while :; do
      read -n 1 key
      if [[ "$key" == "c" ]]; then
        echo -e "\nContinuing..."
        break
      fi
    done
}

function increment_version {
    local current_tag="$1"
    local last_digit=$(echo "$current_tag" | sed -E 's/.*([0-9]+)$/\1/')
    local incremented=$((last_digit + 1))
    echo "$current_tag" | sed -E "s/[0-9]+$/$incremented/"
}

main()
{
    check_arguments "$@"

    echo; echo "*** Create a branch, update source and make a squash pull-request"
    git checkout -b ${BRANCH_NAME}-demo-1
    FE_VER=$(update_content_file src/frontend.txt)
    git add src
    git commit -m "${BRANCH_NAME} Updated SW frontend=${FE_VER}"
    FE_VER=$(update_content_file src/frontend.txt)
    git add src
    git commit -m "${BRANCH_NAME} Updated SW frontend=${FE_VER}"
    git push; wait_for_github_actions
    gh pr create --fill

    wait_for_pr_approval
    gh pr merge --auto --squash --delete-branch --subject "${BRANCH_NAME} Updated SW frontend=${FE_VER}"
    wait_for_github_actions

    echo; echo "*** Create a branch, update source and make a merge pull-request"
    git checkout -b ${BRANCH_NAME}-demo-2
    FE_VER=$(update_content_file src/frontend.txt)
    git add src
    git commit -m "${BRANCH_NAME} Updated SW frontend=${FE_VER}"
    FE_VER=$(update_content_file src/frontend.txt)
    git add src
    git commit -m "${BRANCH_NAME} Updated SW frontend=${FE_VER}"
    git push; wait_for_github_actions
    gh pr create --fill

    wait_for_pr_approval
    gh pr merge --auto --merge --delete-branch; wait_for_github_actions

    echo; echo "*** Create new version tag and push ***"
    CURRENT_TAG=$(git describe --tags --abbrev=0)
    NEXT_TAG=$(increment_version ${CURRENT_TAG})
    git tag -a ${NEXT_TAG} -m "Version ${NEXT_TAG}"
    git push origin ${NEXT_TAG}
    wait_for_github_actions

    echo; echo "*** Release has now been created and reported to kosli ***"
}

main "$@"
