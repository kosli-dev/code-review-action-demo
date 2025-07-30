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

main()
{
    check_arguments "$@"

    echo; echo "*** Create a branch, update source and make a pull-request"
    git checkout -b ${BRANCH_NAME}-demo
    FE_VER=$(update_content_file src/frontend.txt)
    git add src
    git commit -m "${BRANCH_NAME} Updated SW frontend=${FE_VER}"
    FE_VER=$(update_content_file src/frontend.txt)
    git add src
    git commit -m "${BRANCH_NAME} Updated SW frontend=${FE_VER}"
    git push; wait_for_github_actions
    gh pr create --fill




#    echo; echo "*** Waiting for pull request to do required checks before merge"; wait_for_github_actions
#    gh pr merge --auto --squash --delete-branch; wait_for_github_actions
#    echo; echo "*** Wait for build on main to finish"; wait_for_github_actions
#    make report_all_envs > /dev/null; wait_for_github_actions
#    echo; echo "*** SW is now running in dev. Do a deployment from dev to staging"
#    make deploy_to_staging; wait_for_github_actions
#    make report_all_envs > /dev/null; wait_for_github_actions
#    echo; echo "*** Make a release candidate for SW now running in staging with Jira issue ${JIRA_KEY_1}"
#    make generate_jira_release; wait_for_github_actions
#
#    echo; echo "*** We assume the product owner found a bug and wanted a new version of the backend"
#
#    echo; echo "*** Create a branch, update backend app and make a pull-request **"
#    git checkout -b ${JIRA_KEY_2}-demo-2
#    BE_VER=$(update_content_file apps/backend/backend-content.txt)
#    git add apps/
#    git commit -m "${JIRA_KEY_2} Updated SW backend=${BE_VER}"
#    git push; wait_for_github_actions
#    gh pr create --fill
#    echo; echo "*** Waiting for pull request to do required checks before merge"; wait_for_github_actions
#    gh pr merge --auto --squash --delete-branch; wait_for_github_actions
#    echo; echo "*** Wait for build on main to finish"; wait_for_github_actions
#    make report_all_envs > /dev/null; wait_for_github_actions
#    echo; echo "*** Updated SW is now running in dev. Do a deployment from dev to staging"
#    make deploy_to_staging; wait_for_github_actions
#    make report_all_envs > /dev/null; wait_for_github_actions
#    echo; echo "*** Update the release candidate for SW now running in staging."
#    echo "*** This will add the second JIRA-KEY ($JIRA_KEY_2) to the Jira release"
#    make generate_jira_release; wait_for_github_actions
#    echo; echo "*** Check if current release candidate has been approved and can be released. This shall fail!"
#    make check_release_to_prod; wait_for_github_actions
#
#    echo; echo "*** Go to url:"
#    echo "https://kosli-team.atlassian.net/projects/OPS?selectedItem=com.atlassian.jira.jira-projects-plugin%3Arelease-page"
#    echo
#    echo "Press the version you see in the list. It should only be one that is UNRELEASED"
#    echo "On the right hand side press the + next to Approvers"
#    echo "Add your self as an approver"
#    echo "Change the approval from PENDING to APPROVED"
#    echo "After that press 'c' to continue"
#    while :; do
#      read -n 1 key
#      if [[ "$key" == "c" ]]; then
#        echo -e "\nContinuing..."
#        break
#      fi
#    done
#    echo; echo "*** Check if release has been approved"
#    make check_release_to_prod; wait_for_github_actions
#    make report_all_envs > /dev/null; wait_for_github_actions
#    make update_tags
#    echo; echo "*** You can now check kosli UX to see that correct SW is running and that attestations have been done"
}

main "$@"
