FROM curlimages/curl:7.68.0

LABEL "com.github.actions.name"="Post CI/CD Slack messages"
LABEL "com.github.actions.description"="Post Slack messages from DotCMS bot to notify CI/CD job execution statuses"
LABEL "com.github.actions.icon"="hash"
LABEL "com.github.actions.color"="gray-dark"

LABEL version="1.0.0"
LABEL repository="http://github.com/dotcms/slack-messg-action"
LABEL homepage="http://github.com/dotcms/slack-messg-action"
LABEL maintainer="Victor Alfaro <victor.alfaro@dotcms.com>"

COPY entrypoint.sh /entrypoint.sh
USER 0
RUN apk update --no-cache && \
    apk upgrade --no-cache && \
    apk add --update --no-cache bash python3 python3-dev git
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
