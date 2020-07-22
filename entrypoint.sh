#!/bin/bash

CICD_CHANNEL="ci-cd"
CICD_CHANNEL_ID=CMEKXV0MP
DOT_CICD_PATH=./dotcicd
TEST_RESULTS="test-results"
GITHUB="github.com"
GITHACK="raw.githack.com"
GITHUB_TEST_RESULTS_PATH="dotCMS/${TEST_RESULTS}"
export GITHUB_TEST_RESULTS_HOST_PATH="${GITHUB}/${GITHUB_TEST_RESULTS_PATH}"
export GITHUB_TEST_RESULTS_URL="https://${GITHUB_TEST_RESULTS_HOST_PATH}"
export GITHACK_TEST_RESULTS_URL="https://${GITHACK}/${GITHUB_TEST_RESULTS_PATH}"
export GITHUB_TEST_RESULTS_REPO="${GITHUB_TEST_RESULTS_URL}.git"
export GITHUB_TEST_RESULTS_BROWSE_URL="${GITHACK_TEST_RESULTS_URL}/${branch}/projects/${DOT_CICD_TARGET}"
export GITHUB_TEST_RESULTS_REMOTE="https://${GITHUB_USER_TOKEN}@${GITHUB_TEST_RESULTS_HOST_PATH}"

githubUser=${1}
branch=${2}
hash=${GITHUB_SHA::8}
runId=${GITHUB_RUN_ID}

function resolveChannel {
  local gUser=${1}
  local gBranch=${2}

  if [[ "${gBranch}" == "master" ]]; then
    echo ${CICD_CHANNEL_ID}
    return
  fi

  if [[ -z "${gUser}" ]]; then
    echo ${CICD_CHANNEL_ID}
    return
  fi

  # resolve user email from github user id
  local foundEmail=$(curl -u ${GITHUB_USER}:${GITHUB_USER_TOKEN} \
    --request GET \
    -s \
    https://api.github.com/users/${gUser} | \
    grep "\"email\":" | \
    sed "s/\"email\"://g" | \
    tr -d '",[:space:]')
  if [[ -z "${foundEmail}" || "${foundEmail}" == "null" ]]; then
    echo ${CICD_CHANNEL_ID}
    return
  fi

  local foundUserId=$(curl --request GET \
    --header "Authorization: Bearer ${SLACK_BOT_TOKEN}" \
    -s \
    "https://slack.com/api/users.lookupByEmail?email=${foundEmail}" | \
    python3 -m json.tool | \
    grep "\"id\":" | \
    sed "s/\"id\"://g" | \
    tr -d '",[:space:]')
  if [[ -z "${foundUserId}" || "${foundUserId}" == "null" ]]; then
    echo ${CICD_CHANNEL_ID}
    return
  fi

  echo ${foundUserId}
}

function gitConfig {
  git config --global user.email "${GITHUB_USER}@dotcms.com"
  git config --global user.name "${GITHUB_USER}"
}

function resolveMessage {
  local gBranch=${1}
  
  git clone ${GITHUB_TEST_RESULTS_REPO} ${TEST_RESULTS_PATH}
  cd ${TEST_RESULTS}
  
  git fetch --all
  git checkout -b ${branch} --track origin/${branch}
  if [[ $? != 0 ]]; then
    echo "Could not checkout ${branch}, aborting..."
    return
  fi

  git branch
  git pull origin ${branch}
  
  if [[ ! -d ./projects/core/${hash} ]]; then
    echo "Directory ./projects/core/${hash} does not exist"
    exit 1
  fi

  cd projects/core/${hash}
  local overall=SUCCESS
  overallEmoji=":thumbsup_all: "
  local message=""
  for f in $(find . -name job_results.source); do
    source ${f}
    if [[ "${TEST_TYPE_RESULT}" == "FAIL" && "${overall}" == "SUCCESS" ]]; then
      overall=FAIL
      overallEmoji=":fire: "
    fi
    if [[ "${TEST_TYPE_RESULT}" == "SUCCESS" ]]; then
      resultLabel="run *SUCCESSFULLY*"
      emoji=":sunny: "
    else
      resultLabel="*FAILED*"
      emoji=":thunder_cloud_and_rain: "
    fi

    if [[ -n "${DATABASE_TYPE}" ]]; then
      databaseTypeLabel=" (${DATABASE_TYPE^^})"
    else
      databaseTypeLabel=
    fi
  
    message="${message}\n*${emoji}${TEST_TYPE}*${databaseTypeLabel} tests has ${resultLabel}: <${BRANCH_TEST_RESULT_URL}|Details>"
  done

  message="${overallEmoji}PR <https://github.com/dotCMS/${DOT_CICD_TARGET}/pull/${PULL_REQUEST}|${PULL_REQUEST}> at run <https://github.com/dotCMS/${DOT_CICD_TARGET}/actions/runs/${runId}|${runId}> has status: *${overall}*\n${message}"
  echo -e "${message}" > ./message.txt
}

if [[ -z "${SLACK_BOT_TOKEN}" ]]; then
  echo "Set the SLACK_BOT_TOKEN secret."
  exit 1
fi

echo "githubUser: ${githubUser}"
echo "branch: ${branch}"
echo "hash: ${hash}"
channel=$(resolveChannel ${githubUser} ${branch})
resolveMessage ${branch}
message=$(cat ./message.txt)

echo "channel: ${channel}"
echo "message: ${message}"

curl -X POST \
  -H "Content-type: application/json" \
  -H "Authorization: Bearer ${SLACK_BOT_TOKEN}" \
  -d "{ \"channel\": \"${channel}\", \"text\": \"${message}\" }" \
  -s \
  https://slack.com/api/chat.postMessage
